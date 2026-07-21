#!/usr/bin/env bash
# Cut clips from Ontogenez BehaviorData/1_Raw videos into 2_Combined/.
# Driven by "Ontogenez - Main.csv". One row = one output clip.
#
# Output name: DEV_<Mouse_id>_<Trial>.mp4 (matches the 15 hand-filled Example cells).
# Cut method: ffmpeg with -ss before -i (accurate seek with re-encode in modern builds).
# Encoder: libx264 CRF 18 veryfast, no audio (for DLC downstream).
#
# Usage:
#   bash tools/cut_ontogenez_clips.sh pilot        # 5 clips: 2 first-order, 2 second-order, 1 other
#   bash tools/cut_ontogenez_clips.sh all          # all 582
#   bash tools/cut_ontogenez_clips.sh dryrun       # print plan only

set -uo pipefail

CSV="/c/Users/User/YandexDisk/_Projects/Ontogenez/BehaviorData/Ontogenez - Main.csv"
RAW="/c/Users/User/YandexDisk/_Projects/Ontogenez/BehaviorData/1_Raw"
OUT="/c/Users/User/YandexDisk/_Projects/Ontogenez/BehaviorData/2_Combined"
FFMPEG="/c/ffmpeg/bin/ffmpeg.exe"
FFPROBE="/c/ffmpeg/bin/ffprobe.exe"
LOG="/c/Users/User/PycharmProjects/sphynx/tools/cut_ontogenez_clips.log"

MODE="${1:-pilot}"

[[ -x "$FFMPEG" ]]  || { echo "ffmpeg not found at $FFMPEG"  >&2; exit 1; }
[[ -x "$FFPROBE" ]] || { echo "ffprobe not found at $FFPROBE" >&2; exit 1; }
[[ -f "$CSV" ]]     || { echo "CSV not found at $CSV"        >&2; exit 1; }

mkdir -p "$OUT"
: > "$LOG"

log()  { echo "$@" | tee -a "$LOG"; }
logE() { echo "$@" | tee -a "$LOG" >&2; }

# Zero-pad the numeric part of a mouse id to 2 digits: A9 -> A09, C1 -> C01.
# Idempotent (A09 stays A09); leaves ids without a trailing number untouched.
pad_mouse() {
    local m="$1"
    if [[ "$m" =~ ^([A-Za-z]+)0*([0-9]+)$ ]]; then
        printf '%s%02d' "${BASH_REMATCH[1]}" "$((10#${BASH_REMATCH[2]}))"
    else
        printf '%s' "$m"
    fi
}

# --- fps cache per source -------------------------------------------------
declare -A FPS_CACHE
probe_fps() {
    local src="$1"
    if [[ -z "${FPS_CACHE[$src]:-}" ]]; then
        local rfr num den
        rfr=$("$FFPROBE" -v error -select_streams v:0 \
              -show_entries stream=r_frame_rate -of csv=p=0 "$src")
        num="${rfr%/*}"; den="${rfr#*/}"
        FPS_CACHE[$src]=$(awk -v n="$num" -v d="$den" 'BEGIN{printf "%.10f", n/d}')
    fi
    printf '%s' "${FPS_CACHE[$src]}"
}

# --- build job list from CSV ---------------------------------------------
# Columns: Name_expert,Folder,Name_video,Mouse_id,Trial,Time_start,End_start,Data,Target_place,Example,Format
declare -a JOBS
declare -A SEEN_OUT
missing_src=0
dup_name=0

while IFS=, read -r expert folder vid mouse trial fstart fend date_ target example fmt || [[ -n "$expert" ]]; do
    # strip CR (Windows line endings)
    fmt="${fmt%$'\r'}"
    [[ "$expert" == "Name_expert" ]] && continue
    [[ -z "$folder" || -z "$vid" || -z "$mouse" || -z "$trial" || -z "$fstart" || -z "$fend" ]] && continue
    mouse="$(pad_mouse "$mouse")"
    src="$RAW/$folder/$vid"
    if [[ ! -f "$src" ]]; then
        logE "MISSING src: $src (mouse=$mouse trial=$trial)"
        missing_src=$((missing_src+1))
        continue
    fi
    out_name="DEV_${mouse}_${trial}.mp4"
    if [[ -n "${SEEN_OUT[$out_name]:-}" ]]; then
        logE "DUP out name: $out_name (already produced from ${SEEN_OUT[$out_name]}; skipping new src=$src)"
        dup_name=$((dup_name+1))
        continue
    fi
    SEEN_OUT[$out_name]="$src"
    JOBS+=("$src|$fstart|$fend|$OUT/$out_name|$folder")
done < "$CSV"

TOTAL=${#JOBS[@]}
log "CSV scan: jobs=$TOTAL  missing_src=$missing_src  dup_name=$dup_name"

# --- pilot selection ------------------------------------------------------
if [[ "$MODE" == "pilot" ]]; then
    declare -A CAP=( ["first order"]=2 ["second order"]=2 ["other"]=1 )
    declare -A CNT
    declare -a SEL
    for j in "${JOBS[@]}"; do
        f="${j##*|}"
        cap=${CAP[$f]:-0}
        c=${CNT[$f]:-0}
        if [[ $c -lt $cap ]]; then
            SEL+=("$j")
            CNT[$f]=$((c+1))
        fi
    done
    JOBS=("${SEL[@]}")
    log "Pilot mode: selected ${#JOBS[@]} clips"
fi

# --- dryrun: print plan ---------------------------------------------------
if [[ "$MODE" == "dryrun" ]]; then
    for j in "${JOBS[@]}"; do
        IFS='|' read -r src fs fe out folder <<<"$j"
        echo "[$folder] $(basename "$src")  f${fs}-${fe}  ->  $(basename "$out")"
    done
    log "Dryrun: ${#JOBS[@]} jobs planned"
    exit 0
fi

# --- execute --------------------------------------------------------------
ok=0; fail=0; skipped=0
i=0
N=${#JOBS[@]}
t0=$(date +%s)
for j in "${JOBS[@]}"; do
    i=$((i+1))
    IFS='|' read -r src fs fe out folder <<<"$j"

    if [[ -f "$out" ]]; then
        log "[$i/$N] SKIP exists $(basename "$out")"
        skipped=$((skipped+1))
        continue
    fi

    fps=$(probe_fps "$src")
    # CSV frame indices are 1-based. Hybrid cut:
    #   -ss start_s (accurate seek to start) -i src
    #   -vf select=between(n,0,count-1)      (precise frame count after seek)
    # First frame of output == frame fs of src (PSNR inf verified on pilot).
    start_s=$(awk -v a="$fs" -v f="$fps" 'BEGIN{printf "%.6f", (a-1)/f}')
    count=$((fe - fs + 1))
    last_n=$((count - 1))

    log "[$i/$N] $(basename "$src") f${fs}-${fe} -> $(basename "$out") (fps=$fps t0=${start_s}s n=${count})"

    if "$FFMPEG" -hide_banner -loglevel error -y \
            -ss "$start_s" -i "$src" \
            -vf "select='between(n,0,${last_n})',setpts=PTS-STARTPTS" -fps_mode passthrough \
            -an -c:v libx264 -crf 18 -preset veryfast \
            -movflags +faststart \
            "$out" 2>>"$LOG"; then
        ok=$((ok+1))
    else
        logE "  FAIL: $(basename "$out")"
        rm -f "$out"
        fail=$((fail+1))
    fi
done

t1=$(date +%s)
log "----------------------------------------"
log "Done. ok=$ok  fail=$fail  skipped=$skipped  elapsed=$((t1-t0))s"
log "Log: $LOG"

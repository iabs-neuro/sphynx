#!/usr/bin/env bash
# Clone cohort-level presets to per-session presets, named after 2_Combined clips.
# Source: 4_Preset/_originals/<cohort>_Preset.mat
# Target: 4_Preset/DEV_<mouse>_<trial>_Preset.mat
#
# Rows with source D*/F*/G*.mp4 (second order) are skipped — no cohort preset exists yet.
# Rows with empty mouse / trial are skipped.

set -uo pipefail

CSV="/c/Users/User/YandexDisk/_Projects/Ontogenez/BehaviorData/Ontogenez - Main.csv"
PRESET="/c/Users/User/YandexDisk/_Projects/Ontogenez/BehaviorData/4_Preset"
ORIG="$PRESET/_originals"
LOG="/c/Users/User/PycharmProjects/sphynx/tools/clone_ontogenez_presets.log"

[[ -d "$ORIG" ]] || { echo "missing $ORIG" >&2; exit 1; }
[[ -f "$CSV" ]]  || { echo "missing $CSV"  >&2; exit 1; }

: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

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

ok=0; missing_orig=0; skipped_secondorder=0; skipped_empty=0; already=0

# `|| [[ -n "$expert" ]]` to catch final line without trailing newline (see memory note).
while IFS=, read -r expert folder vid mouse trial fstart fend date_ target example fmt \
      || [[ -n "$expert" ]]; do
    fmt="${fmt%$'\r'}"
    [[ "$expert" == "Name_expert" ]] && continue
    [[ -z "$mouse" || -z "$trial" ]] && { skipped_empty=$((skipped_empty+1)); continue; }
    mouse="$(pad_mouse "$mouse")"

    # cohort base = filename without extension
    cohort="${vid%.*}"
    src="$ORIG/${cohort}_Preset.mat"
    dst="$PRESET/DEV_${mouse}_${trial}_Preset.mat"

    if [[ ! -f "$src" ]]; then
        skipped_secondorder=$((skipped_secondorder+1))
        continue
    fi

    if [[ -f "$dst" ]]; then
        already=$((already+1))
        continue
    fi

    if cp "$src" "$dst"; then
        ok=$((ok+1))
    else
        log "FAIL cp $src -> $dst"
    fi
done < "$CSV"

log "Done. cloned=$ok  already=$already  skipped_secondorder=$skipped_secondorder  skipped_empty=$skipped_empty"
log "4_Preset top-level files: $(ls "$PRESET"/*.mat 2>/dev/null | wc -l)"

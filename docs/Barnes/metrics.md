# Barnes-maze metrics -- sphynx reference

Reference for the Barnes-maze-specific code paths in sphynx: the default
act library, the per-hole zone naming convention, how per-act minimum
duration is enforced, the session-level metrics produced after analysis,
and where each of these maps onto the classic Barnes literature.

All file paths are relative to the repo root
(`C:\Users\User\PycharmProjects\sphynx\`). All numeric defaults below
were read directly from the source files cited beside them.

## Table of contents

1. Apparatus and conventions
2. Zone naming (`_real` / `_realout` / `_out`)
3. Default Barnes act library (64 acts)
4. Session metrics (`barnesSessionMetrics`)
5. How per-act `minDurationSec` is applied
6. Literature alignment summary
7. What sphynx does NOT compute

---

## 1. Apparatus and conventions

The default geometry assumes the canonical Sunyer et al. 2007 Barnes
apparatus:

- Circular platform, ~92 cm diameter.
- 20 holes around the perimeter (the rewarded `target` plus 19 escape
  holes `object1..object19`).
- Each hole ~5 cm in diameter, centre-to-centre spacing ~7.5 cm.

Sphynx itself does NOT enforce these numbers -- they are listed here
only as the reference geometry the defaults were tuned against. The
only structural assumption in code is that the rewarded hole plus the
escape holes form a single evenly-spaced ring of `NumObjects + 1`
holes (see `+sphynx/+pipeline/barnesSessionMetrics.m:18-22`).

Terminology used throughout sphynx:

- `target` -- the rewarded hole (the escape).
- `objectN` / `holeN` -- one of the N escape (non-rewarded) holes;
  `object1` is one slot away from the target, `objectN` is the
  farthest from the target along the ring.
- Hole-ring angular step =
  `360 / (NumObjects + 1)` degrees
  (`+sphynx/+pipeline/barnesSessionMetrics.m:80`).
- `NumObjects` defaults to **19** everywhere
  (`+sphynx/+acts/actsLibraryBarnesDefaults.m:50`,
  `+sphynx/+pipeline/barnesSessionMetrics.m:62`).
  That matches the `Demo/BARNES_v2` preset.

The hole-ring step at the default `NumObjects = 19` is therefore
`360 / 20 = 18` degrees per slot.

---

## 2. Zone naming (`_real`, `_realout`, `_out`)

Built by `+sphynx/+preset/buildObjectZones.m` and consumed by
`CreatePresetApp` plus every Barnes act. For every object polygon
(rewarded `target`, each escape `objectN`, and `platform`) the preset
emits three masks (`+sphynx/+preset/buildObjectZones.m:49-62`):

| Zone suffix     | Mask                                                          | Use                                                         |
| --------------- | ------------------------------------------------------------- | ----------------------------------------------------------- |
| `<obj>_real`    | The user-drawn polygon itself (~5 cm diameter, ~8x8 px frame) | "mouse fully inside hole" tests, strict membership          |
| `<obj>_realout` | `_real` dilated by `ZoneWidthCm`                              | The "investigation zone" -- nose within ~2.5 cm of the hole |
| `<obj>_out`     | `_realout AND NOT _real`                                      | The surrounding halo ring only; composite acts use this     |

The halo radius is the `ZoneWidthCm` name-value parameter of
`buildObjectZones`, default **2.5 cm**
(`+sphynx/+preset/buildObjectZones.m:35`). The dilation is computed
in pixels via the distance transform
(`+sphynx/+preset/buildObjectZones.m:57-60`):

```
d = bwdist(objMask);
inflated = d <= widthPxl;
```

When two or more objects exist, `objectall_real / objectall_realout /
objectall_out` are emitted as the OR-union of all per-object masks
(`+sphynx/+preset/buildObjectZones.m:65-79`). The Barnes default
library does NOT use the `objectall_*` zones -- it builds `nose_at_any_hole`
explicitly so the target can be excluded; see Section 3.

### Mapping to ANY-maze terminology

| ANY-maze term      | sphynx zone     | Meaning                                                                       |
| ------------------ | --------------- | ----------------------------------------------------------------------------- |
| "Standard zone"    | `<obj>_real`    | Head/body fully on top of the hole                                            |
| "Investigation zone" | `<obj>_realout` | Head within a configurable distance (default 2.5 cm)                          |

Note: ANY-maze's investigation zone also gates on head orientation
toward the hole. sphynx does NOT gate on orientation -- distance only.
There is no head-direction vector in the default DLC schema.

---

## 3. Default Barnes act library (64 acts)

Built by `+sphynx/+acts/actsLibraryBarnesDefaults.m`. The library
returns 64 acts for the default `NumObjects = 19`:

| Indices  | Family                | Body part(s)                              | Zone(s)               | `minDurationSec` | Captures                                  |
| -------- | --------------------- | ----------------------------------------- | --------------------- | ---------------- | ----------------------------------------- |
| 1        | `nose_at_target`      | `nose`                                    | `target_realout`      | 0.25 (default)   | Nose-poke at the rewarded hole            |
| 2..20    | `nose_at_hole1..19`   | `nose`                                    | `objectN_realout`     | 0.25 (default)   | Nose-poke at escape hole N                |
| 21       | `body_at_target`      | `bodycenter`                              | `target_realout`      | 0.25 (default)   | Body within the target halo               |
| 22..40   | `body_at_hole1..19`   | `bodycenter`                              | `objectN_realout`     | 0.25 (default)   | Body within the escape halo for hole N    |
| 41       | `nose_at_platform`    | `nose`                                    | `platform_realout`    | 0.25 (default)   | Nose near the start platform              |
| 42       | `body_at_platform`    | `bodycenter`                              | `platform_realout`    | 0.25 (default)   | Body near the start platform              |
| 43       | `mouse_inside_target` | `bodycenter` + `tailbase` + `headcenter`  | `target_real`         | **2.0**          | Mouse genuinely curled inside the goal    |
| 44..62   | `mouse_inside_hole1..19` | `bodycenter` + `tailbase` + `headcenter` | `objectN_real`        | **2.0**          | Mouse curled inside escape hole N         |
| 63       | `mouse_inside_platform` | `bodycenter` + `tailbase` + `headcenter` | `platform_real`       | **2.0**          | Mouse seated on the start platform        |
| 64       | `nose_at_any_hole`    | `nose`                                    | OR(`object1_realout` .. `objectN_realout`) | 0.25 (default) | Nose-poke at ANY escape hole; target excluded; platform excluded |

Source references:
`+sphynx/+acts/actsLibraryBarnesDefaults.m:30-41` (layout summary),
`:57-65` (nose family),
`:67-76` (body family),
`:79-84` (platform family),
`:87-92` (`mouse_inside_*` builders),
`:94-101` (`nose_at_any_hole`),
`:104-116` (`makeAllInZoneAct` -- specialKind + 2.0 s minimum).

Default `minDurationSec` for nose/body simple acts comes from
`sphynx.acts.emptyAct`'s schema default of **0.25 s** and is applied
post-dispatch in `+sphynx/+acts/applyAct.m:51-67`. The
`mouse_inside_*` builder overrides it to **2.0 s** explicitly in
`actsLibraryBarnesDefaults.m:115`.

### Why nose acts use `_realout`, not `_real`

R23 reverted nose detection from the strict `_real` polygon back to
the inflated `_realout` halo
(`+sphynx/+acts/actsLibraryBarnesDefaults.m:10-16`). On real
SuperAnimal DLC video the strict hole polygon is roughly 8x8 px on a
typical Barnes top-view frame, while the per-frame DLC nose jitter is
on the order of 10 px. The intersection of a noisy 10 px point cloud
with an 8 px target is, in practice, near-zero hits -- the strict-zone
nose-poke detector did not fire on real data even when the animal
clearly poked the hole. The 2.5 cm halo (`_realout`) gives the noise
margin needed to recover the literature's nose-poke definition.

### Why `mouse_inside_*` uses `_real` AND `minDurationSec = 2.0`

`mouse_inside_*` is meant to capture the animal having genuinely
entered and settled inside the hole (e.g. the target escape, or
perseverative settling at a wrong hole). Two safeguards are stacked:

1. **Strict polygon** (`_real`, no halo) so the hit cannot be triggered
   by a hovering body or a nose flicker over the rim.
2. **All three parts inside simultaneously**
   (`bodycenter` + `tailbase` + `headcenter`) via the special
   `allInZone` evaluator
   (`+sphynx/+acts/applyAct.m:163-182`). This needs the whole animal
   inside the polygon, not a leaning posture.
3. **2.0 s sustained run** via `minDurationSec = 2.0`. One- or
   two-frame coincidences where all three parts happen to land in the
   strict polygon during a high-speed flyby are dropped as noise
   (`+sphynx/+acts/actsLibraryBarnesDefaults.m:111-115`).

The composition is "strict polygon AND whole animal AND sustained" --
deliberately conservative so the act means what its name implies.

---

## 4. Session metrics (`barnesSessionMetrics`)

`+sphynx/+pipeline/barnesSessionMetrics.m` consumes a
`result` struct produced by `sphynx.pipeline.analyzeSession` and
returns a flat struct of session-level Barnes metrics. The function
expects the canonical default-library names (`nose_at_target`,
`nose_at_holeN`, `body_at_target`, `body_at_holeN`, ...). The empty
metrics struct (default values when the session is missing or
contained no relevant acts) is built in
`+sphynx/+pipeline/barnesSessionMetrics.m:167-177`.

| Field                      | Computation                                                                                                                              | Classic literature equivalent                              | Notes                                                                                                                                       |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `TotalNoseHoleVisits`      | Sum of `ActNumber` (episode count) over `nose_at_hole1..N`; target excluded (`:86-97`)                                                   | "Total errors" in Pitts, Sunyer, Illouz                    | Counts ALL non-target nose-pokes including post-target perseveration                                                                        |
| `PrimaryErrors`            | Count of `nose_at_holeN` episodes whose start time is STRICTLY before the first `nose_at_target` episode start (`:144-160`)              | "Primary errors" / classical memory metric                 | Equals `TargetHoleVisitOrder - 1`. Returned only when `nose_at_target` fired and frame rate is known (otherwise stays `NaN` from `:170`)    |
| `TotalBodyHoleVisits`      | Same as `TotalNoseHoleVisits` but over `body_at_holeN` (`:93-96`)                                                                        | Broader "near-hole presence" signal                        | Useful when nose tracking is unreliable; counts pass-overs as well as inspections                                                           |
| `NumCheckedHoles`          | Number of distinct `objectN` holes whose `nose_at_holeN` had at least one episode (`ActNumber >= 1`) (`:103-111`)                        | "Number of holes explored"                                 | A hole is "checked" if the nose entered its halo at least once during the whole session                                                     |
| `FirstCheckedHoleNumber`   | The N of the `nose_at_holeN` with the smallest `FirstStartSec`; ties broken by lowest N (`:118-126`)                                     | "First hole visited"                                       | `NaN` if no escape hole was ever checked                                                                                                    |
| `FirstCheckedHoleErrorDeg` | Angular distance from `FirstCheckedHoleNumber` to the target along the ring; **shorter way around** (`:126`, `holeAngle` `:191-199`)     | "Search-error angle" / "first-error angle"                 | 0 deg = first hole IS the target; 180 deg = exactly opposite                                                                                |
| `MeanCheckedHoleErrorDeg`  | Mean of `holeAngle(N)` over the set of holes for which `NumberOfActs >= 1` (`:128-129`)                                                  | Mean spatial-error angle                                   | Rounded to 2 decimals; `NaN` if no hole was checked                                                                                         |
| `TargetHoleVisitOrder`     | `1 + (# nose_at_holeN episodes that started before first nose_at_target)` (`:159`)                                                       | Position of target in visit sequence                       | `1` means the target was the very first hole the nose touched; `NaN` if the target was never reached or frame rate is unknown               |

### Implementation details worth knowing

- **Episode counting.** `TotalNoseHoleVisits` and
  `TotalBodyHoleVisits` use the per-act `ActNumber` field, which is
  already the post-refine episode count produced by `applyAct`'s
  bridge-then-drop step. So a single sustained nose-poke that is
  briefly broken by a sub-`maxGapSec` glitch counts as one visit, not
  two.
- **`PrimaryErrors` requires frame rate.** The comparison is done in
  seconds: per-hole episode-start frames are converted via
  `(runStart - 1) / frameRate`
  (`+sphynx/+pipeline/barnesSessionMetrics.m:155-157`). If
  `result.Options.FrameRate` is missing or non-positive,
  `TargetHoleVisitOrder` and `PrimaryErrors` stay at their default
  `NaN`.
- **`runStarts`** (`:201-209`) recomputes episode start frames from
  `ActArrayRefine` rather than reading `FirstStartSec`, because the
  metric needs per-episode timestamps and not just the first one. The
  whole post-refine logical mask is walked once per hole.
- **Angle convention.** `holeAngle(N)` returns
  `min(N*step, 360 - N*step)` so the result is the shorter ring
  distance (`:191-199`). The metric is therefore direction-agnostic;
  it does NOT distinguish "object3 clockwise" from "object3
  counter-clockwise". For an undirected memory error this is correct;
  for search-strategy classification (which sphynx does not do) you
  would need the signed value.

---

## 5. How per-act `minDurationSec` is applied

Applied uniformly to every act in `+sphynx/+acts/applyAct.m:51-67`,
**after** the per-type dispatch (simple / complex / special):

```matlab
if isfield(act, 'minDurationSec')
    durSec = max(0, act.minDurationSec);
else
    durSec = 0.25;                                  % legacy backfill
end
...
minRunFrames    = round(durSec * ctx.frameRate);
maxBridgeFrames = round(gapSec  * ctx.frameRate);
if minRunFrames > 0 || maxBridgeFrames > 0
    bool = sphynx.acts.refineActArray(bool, minRunFrames, maxBridgeFrames);
end
```

Key points:

- The duration is converted to frames via the session's `frameRate`,
  then `refineActArray` does "bridge short gaps, then drop short
  runs" in that order so that fragment + tiny-glitch + fragment
  consolidates into one event instead of being erased
  (`+sphynx/+acts/applyAct.m:38-42`).
- Acts loaded from libraries saved before the `minDurationSec` field
  existed are backfilled to **0.25 s**, matching what new acts get
  from `sphynx.acts.emptyAct` (`+sphynx/+acts/applyAct.m:45-55`).
  Set `minDurationSec = 0` explicitly on a custom act to opt out.
- The pre-rename field name `minGapSec` is still accepted as a fallback
  for `maxGapSec` (`+sphynx/+acts/applyAct.m:56-62`).
- Because the refine step is applied after dispatch, it works
  uniformly for **simple** acts (`nose_at_*`, `body_at_*`), **complex**
  acts (composed via `intersect`/`union`/`exclude`/`sequence`), and
  **special** acts (`freezing`, `rears`, `allInZone`). In particular,
  `mouse_inside_*` -- a special act with `specialKind = 'allInZone'`,
  built in `+sphynx/+acts/actsLibraryBarnesDefaults.m:104-116`, evaluated
  in `+sphynx/+acts/applyAct.m:163-182` -- is included; its
  `minDurationSec = 2.0` is the value of `durSec` used in the refine
  step above.

---

## 6. Literature alignment summary

| Classic metric                                         | sphynx field                                                | Reference                                                              |
| ------------------------------------------------------ | ----------------------------------------------------------- | ---------------------------------------------------------------------- |
| Apparatus geometry (92 cm, 20 holes, 5 cm diam, 7.5 cm spacing) | Default `NumObjects = 19` plus a 2.5 cm `ZoneWidthCm` halo  | Sunyer et al. 2007                                                     |
| Primary errors (wrong-hole pokes before reaching goal) | `PrimaryErrors`                                             | Pitts 2023 (PMC10205663), Sunyer et al. 2007                           |
| Total errors (all wrong-hole pokes, incl. after goal)  | `TotalNoseHoleVisits`                                       | Pitts 2023, Sunyer et al. 2007, Illouz et al. 2016 (Oxford Bioinformatics) |
| First hole visited / first-search angle                | `FirstCheckedHoleNumber` + `FirstCheckedHoleErrorDeg`       | Illouz et al. 2016                                                     |
| Hole-exploration breadth                               | `NumCheckedHoles`, `MeanCheckedHoleErrorDeg`                | Illouz et al. 2016                                                     |
| Time to first reach target                             | First episode start of `nose_at_target` (read directly from `result.Acts`) | Sunyer et al. 2007                                                     |
| Investigation zone vs. standard zone                   | `<obj>_realout` vs `<obj>_real`                             | ANY-maze setup guide                                                   |
| Halo radius = 5% of arena radius                       | `ZoneWidthCm = 2.5` on a 92 cm platform (radius 46 cm) -- 5.4% | Rtrack `goal.vicinity = 5%`                                            |

References (full):

- Sunyer, B., Patil, S., Hoeger, H. and Lubec, G. (2007). Barnes maze,
  a useful task to assess spatial reference memory in the mice. Nature
  Protocols.
- Illouz, T., Madar, R., Clague, C., Griffioen, K. J., Louzoun, Y.,
  Okun, E. (2016). Unbiased classification of spatial strategies in
  the Barnes maze. Bioinformatics (Oxford).
- Pitts, M. W. (2023). Barnes maze procedure for spatial learning and
  memory in mice. PMC10205663.
- ANY-maze software setup guide for the Barnes maze.
- Rtrack package, `goal.vicinity` convention.

---

## 7. What sphynx does NOT compute

Honest list, so downstream work can be planned without rediscovering
these gaps:

- **Search-strategy classification** (direct / spatial / serial /
  random as in Illouz 2016). Sphynx logs hole-visit timing and
  identities but does not run the path-geometry classifier required to
  label each trial's strategy. Implementable on top of the existing
  per-hole episode start frames plus the smoothed body-centre track.
- **Probe-trial quadrant analysis** (time in target quadrant vs.
  others). Sphynx is session-agnostic and does not partition the arena
  into quadrants. Quadrant time can be derived post-hoc from spatial
  acts (e.g. composite zones in `CreatePresetApp`) but is not in the
  default library.
- **Heading angle / orientation tests** (e.g. nose-to-target vector,
  approach angle). The default DLC schema does not provide a stable
  nose-direction vector, and no act in
  `+sphynx/+acts/actsLibraryBarnesDefaults.m` consumes orientation.
  The ANY-maze "investigation zone" includes an orientation check that
  sphynx's `_realout` halo does NOT replicate -- our halo is a pure
  distance gate.
- **Latency to first reach the goal as its own metric.** First-target
  time is available as `Acts(nose_at_target).FirstStartSec` from
  `analyzeSession`, but `barnesSessionMetrics` does not pull it into
  its returned struct. Add downstream if a single-field convenience is
  needed.
- **Path-length / search distance.** Not in
  `barnesSessionMetrics`. The smoothed track and frame rate make this
  cheap to add (cumulative `sqrt(dX^2 + dY^2) / pixelsPerCm`).

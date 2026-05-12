# Project subsystem — design (in progress)

Branch: `Sphynx-GUI-dev`. Status: brainstorming phase, sections 1-5 approved, 6-8 + final doc + writing-plans handoff TBD.

## Context (carried over from brainstorm)

**Strategic frame the user picked:**
- Horizon: «закрыть гэпы под текущую статью» (later corrected to «готовим рабочий полноценный пайплайн», not single-paper).
- Biggest current pain: **проектный стек / связка вкладок**. Каждая вкладка просит свои пути руками, нет Project tab, нет per-experiment defaults, метадата не аккумулируется.
- Scope chosen: all four facets — paths + folder skeleton, experiment type + defaults, mouse list + metadata, accumulating log + validation.
- UI shape: **новая вкладка Project (самая первая)**, Tab 0.
- Rollout strategy: **биг-бенг** — все вкладки подписываются (CreatePreset размораживается).
- Storage: **JSON manifest в корне** (`<Root>/sphynx_project.json`), `jsonencode/jsondecode`. R2020a supports it.
- Architectural pattern: **reactive state container with listeners** (handle class + `Changed` event + `addlistener` in each tab).

---

## Section 1 — Project state model + JSON schema  [APPROVED]

`+sphynx/+app/ProjectState.m` (handle class) хранит всё что летит между вкладками:

```
Root            char    project root absolute path
Description     char    free-text
ExperimentType  char    'Novelty_OF' | 'Complex_Context' | 'Bowls_OF'
                         | 'Freezing_Track' | 'Barnes' | 'Custom'
NamePattern     char    regex with named tokens (default per exp type)
Folders         struct  .rawVideo .video .dlc .preset .behavior .plots
                         (relative paths under Root, allow absolute override)
                         NOTE: 2_Combined renamed -> 2_Video per user request.
Defaults        struct  per-experiment-type config: .objectsNumber
                         .arenaGeometry .wallWidthCm .middleWidthCm
                         .frameRate .actsLibrary .expectedSessions ...
Mice            table   columns: mouse, included(bool), group, line, sex,
                         drug, ... + any ID_* the user adds
Log             struct array  .ts .tab .action .session .status .message
                         (append-only)
```

Serialisation in `<Root>/sphynx_project.json`. cell-arrays -> JSON arrays; tables -> array of records.

Sample JSON:
```json
{
  "schema": 1,
  "description": "WNOF 2026",
  "experimentType": "Novelty_OF",
  "namePattern": "^(?<exp>[^_]+)_(?<mouse>[^_]+)_(?<session>.+)$",
  "folders": {"rawVideo":"1_RawVideo","video":"2_Video","dlc":"3_DLC",
              "preset":"4_Preset","behavior":"5_Behavior","plots":"6_Plots"},
  "defaults": {"objectsNumber":4,"arenaGeometry":"Polygon",
               "wallWidthCm":7,"frameRate":30,"actsLibrary":"novelty_of_default"},
  "mice": [{"mouse":"WNOF_A01","included":true,"group":"ctrl","sex":"M"}, ...],
  "log":  [{"ts":"2026-05-12T10:30:00","tab":"Analyze",
            "action":"run","session":"WNOF_A01_1D","status":"OK"}, ...]
}
```

Key idea: **Mice — pandas-like таблица** с произвольными ID_* столбцами. Когда юзер добавил колонку sex в проект, она течёт в Make Output Table → Plot Data автоматически.

Versioning via `schema` field for future breaking changes.

---

## Section 2 — Project tab UI  [APPROVED]

`+sphynx/+app/ProjectTabController.m`. New Tab 0. Left column narrow (controls), right column wide (mouse table + activity log).

**Left column (380 px):**

```
[ Create ] [ Load ] [ Save ] [ Save As ]    <- top button row

Project name:   [ ____________________ ]      <- editable; default = basename of Root
Root path:      [ ____________________ ] [Pick]

Description:    [ multi-line text area, 3 rows ]

Experiment:     [ Novelty_OF        v ]       <- dropdown; triggers defaults reload
NamePattern:    [ ^(?<exp>...)$    ] [Reset]

Folders:                                       <- auto-filled on Pick Root
  RawVideo:     [ 1_RawVideo        ]
  Video:        [ 2_Video           ]
  DLC:          [ 3_DLC             ]
  Preset:       [ 4_Preset          ]
  Behavior:     [ 5_Behavior        ]
  Plots:        [ 6_Plots           ]

Defaults (from experiment type):               <- read-only label list with [Edit] btn
  objects=4, arena=Polygon, wallWidth=7 cm,
  fps=30, acts=novelty_of_default

[ Scan mice ]  [ Validate ]                    <- bottom action row
```

**Right column (1x):**

```
+--- Mice ----------------------------------+
| mouse       | included | group | line | sex | drug |  <- uitable, editable
| WNOF_A01    |   [x]    | ctrl  | BL6  | M   |      |
| ...                                                  |
+ [+ column] [+ row] [- row]                            |
+------------------------------------------+

+--- Activity log (read-only) --------------+
| 2026-05-12 10:30 Analyze   WNOF_A01_1D OK |
| 2026-05-12 10:31 Analyze   WNOF_A02_1D FAIL: rear threshold |
+------------------------------------------+
```

**Behaviour:**
- *Create*: folder picker → if empty, scaffold 5_Behavior / 4_Preset / ... skeleton and write sphynx_project.json with `Custom` defaults.
- *Load*: folder picker. If sphynx_project.json present — read; else offer "Initialize as project here?".
- *Save / Save As*: write JSON to Root.
- *Scan mice*: walks `<Root>/<Folders.behavior>/`, parses session names via NamePattern, adds unique mice (existing rows preserved).
- *Validate*: folder existence, mouse-has-session match, NamePattern parses; results -> activity log.
- ExperimentType dropdown change reloads Defaults with confirm "Reset defaults to <exp> presets?".
- Mice table: `+ column` adds arbitrary ID_* column via prompt. `included` checkbox filters which mice flow to Batch / Make Output.

---

## Section 3 — Per-experiment defaults registry  [APPROVED]

`+sphynx/+experiments/` package. One file per experiment type + registry.

```
+sphynx/+experiments/
  Novelty_OF.m
  Complex_Context.m
  Bowls_OF.m
  Freezing_Track.m
  Barnes.m
  Custom.m
  registry.m
  get.m
```

Each file returns a defaults struct:
```matlab
function d = Novelty_OF()
    d.experimentType   = 'Novelty_OF';
    d.label            = 'Novelty Open Field';
    d.namePattern      = '^(?<exp>[^_]+)_(?<mouse>[^_]+)_(?<session>.+)$';
    d.arenaGeometry    = 'Polygon';
    d.objectsNumber    = 4;
    d.wallWidthCm      = 7;
    d.middleWidthCm    = 3;
    d.frameRate        = 30;
    d.expectedSessions = {'1D','2D','3D','4D'};
    d.actsLibrary      = 'novelty_of_default';
    d.zoneStrategy     = 'corners-walls-center-objects';
    d.bodyparts        = {'nose','leftear','rightear','headcenter', ...
                          'leftforelimb','righforelimb','leftbody','rightbody', ...
                          'lefthindlimb','righthindlimb','tailbase','bodycenter'};
end
```

Loader: `d = sphynx.experiments.get(name)` ; list: `names = sphynx.experiments.registry()`.

**Custom.m** — empty template; user fills via Project tab Edit defaults.

**Adding new experiment type = one new file + one entry in `registry.m`.** Nothing else.

---

## Section 4 — Listener / propagation flow  [APPROVED]

`ProjectState extends handle` with one event `Changed`. Each tab subscribes in constructor, unsubscribes in delete().

```matlab
classdef ProjectState < handle
    properties
        Root, Description, ExperimentType, NamePattern
        Folders, Defaults, Mice, Log
    end
    events
        Changed
    end
    methods
        function setField(obj, name, value)
            obj.(name) = value;
            notify(obj, 'Changed');
        end
        function update(obj, fields)
            fn = fieldnames(fields);
            for k = 1:numel(fn); obj.(fn{k}) = fields.(fn{k}); end
            notify(obj, 'Changed');
        end
        function appendLog(obj, entry)
            obj.Log(end+1) = entry;
            notify(obj, 'Changed');
        end
        function loadFromFile(obj, path)
            % jsondecode -> populate fields -> notify once
        end
        function saveToFile(obj, path)
            % jsonencode -> write
        end
    end
end
```

CreatePresetApp owns one instance, passes to every controller. Each controller in constructor:
```matlab
obj.Project = parentApp.Project;
obj.ProjectListener = addlistener(obj.Project, 'Changed', ...
    @(~,~) obj.onProjectChanged());
obj.onProjectChanged();   % apply current state once
```

And in `delete`:
```matlab
function delete(obj)
    if isvalid(obj.ProjectListener); delete(obj.ProjectListener); end
end
```

**Notify strategy:** one event for any change. Listener must be **idempotent**.

**Batched updates** via `update(struct(...))` to avoid cascade.

**Loop guard:** flag `obj.UpdatingFromListener` so a tab editing its own UI doesn't re-trigger notify.

**Logging:** each tab at key milestones calls
```matlab
Project.appendLog(struct('ts', datestr(now,'yyyy-mm-ddTHH:MM:SS'), ...
    'tab','Analyze', 'action','run', 'session','WNOF_A01_1D', 'status','OK'));
```
Goes both into Activity Log in Project tab and into JSON on Save.

**Edge cases:**
- No project loaded: empty ProjectState. Tabs work as today with loader strips as fallback.
- User changes Root mid-session: tabs auto-refresh; user inputs preserved (listener fills defaults only).
- Heavy ops (Scan mice, Validate): one notify at the end, not per-add.

---

## Section 5 — Per-tab integration  [APPROVED]

What each tab does in `onProjectChanged()`. All idempotent.

**Project (tab 0)** — source only, not subscriber.

**CreatePreset (tab 1)**
- Pre-fill ObjectsNumberField, WallWidthCmField, MiddleWidthCmField, FrameRateField, ArenaGeometryDropDown from `Project.Defaults`.
- Don't override fields user edited (flag `obj.UserEditedFields.<name>=true` after ValueChangedFcn).
- On Save Preset: appendLog `action='preset_saved'`.

**Preprocess Tracking (tab 2)**
- Picker default dir = `Project.Root/Project.Folders.dlc`.
- Bodyparts hint from `Project.Defaults.bodyparts`.
- On done: appendLog `action='preprocess_done', file=<csv>`.

**Define Acts (tab 3)**
- If `Project.Defaults.actsLibrary` set and no library loaded yet: auto-load.
- On Save library: appendLog `action='library_saved', name=<lib>`.

**Analyze Session (tab 4)**
- Pickers default to `Project.Folders.{dlc,video,preset,behavior}`.
- On Run: appendLog `action='analyze', session=<name>, status=<OK|FAIL>`.

**Batch Analysis (tab 5)**
- Default BatchDir = `Project.Folders.behavior`, OutDir = `Project.Folders.plots`.
- Filter mice by `Project.Mice.included == true` (checkbox toggle).
- On Run: per-session log entries.

**Make Output Table (tab 6)**
- BatchDir = `Project.Folders.behavior`.
- Metadata auto-fills from `Project.Mice` (no external CSV needed; CSV button stays as override).
- NamePattern from `Project.NamePattern` (was hardcoded).
- SortBy auto-collects ID_* columns from `Project.Mice`, default `<first ID_*>,mouse`.
- On Build: appendLog `action='build_table', rows=N, cols=M`.

**Plot Data (tab 7)**
- On Load CSV: outer-join `Project.Mice` columns into the table by mouse.
- Factor dropdowns include `Project.Mice` columns.
- Save All outDir = `Project.Folders.plots/<metric>/`.

**Preprocess Video (tab 8, WIP)** — not touched in big-bang; subscribe stub only.

**Synthetic Data (tab 9, WIP)** — same.

**Key invariant:** no tab writes to its UI in `onProjectChanged` if user input already exists; only fills defaults.

---

## Section 6 — CreatePreset unfreezing scope  [TBD]

To be designed next session. Goals:

- Constructor takes Project, subscribes.
- `onProjectChanged()`: read `Project.Defaults.{objectsNumber, wallWidthCm, middleWidthCm, frameRate, arenaGeometry}` and update relevant UI widgets only if user hasn't edited them.
- On Save Preset: appendLog.
- Don't touch geometry / zone composition / drawing logic — that's frozen.

Open questions:
- How to detect "user already edited a field"? Per-field flag set on ValueChangedFcn? Compare current value to last-set-from-project value?
- Should ExperimentType drive zoneStrategy too (auto-add zones for Novelty_OF)?
- Library presets — should `actsLibrary` field auto-load the library when CreatePreset opens, or wait for Define Acts?

---

## Section 7 — Backward compat / migration  [TBD]

To be designed next session. Goals:

- App starts with no project → tabs work as today (loader strips fallback).
- Existing folders without `sphynx_project.json` → "Initialize as project" offers same flow as Create.
- Old presets / `_WorkSpace.mat` files should be openable without breaking.
- Schema versioning via `schema` field.

Open questions:
- What about already-converted H:\Dataset experiments (CC/FOF/NOF/RFC)? Auto-initialize a project there from existing 5_BehaviorMAT_new folder?
- If user opens an unsupported newer schema, hard fail or read-only mode?

---

## Section 8 — Testing approach  [TBD]

To be designed next session. Goals:

- `tests/unit/projectStateTest.m`: construct, setField, listener fires, batched update fires once, JSON round-trip preserves all fields.
- `tests/unit/experimentsRegistryTest.m`: each registry name returns a struct with required fields.
- `tests/integration/projectToTabsTest.m`: spin up CreatePresetApp with a temp project root, load a JSON, verify Analyze tab default paths reflect Project.Folders.

Open questions:
- Headless test of listener-driven UI updates — do uispinner ValueChangedFcn callbacks fire in headless mode?
- Do we need a project-fixture / golden file under `tests/fixtures/`?

---

# Resume instructions (for next session)

When user says "продолжаем дизайн Project subsystem":

1. Read this file end-to-end.
2. Resume with **Section 6 — CreatePreset unfreezing scope**. Present scope + answer open questions, get approval.
3. Then **Section 7 — Backward compat**, then **Section 8 — Testing**.
4. After all sections approved: run spec self-review pass (placeholders / contradictions / scope / ambiguity).
5. Ask user to review the written spec.
6. On approval: invoke `superpowers:writing-plans` skill to produce the implementation plan.

Total effort estimate (gut): C4 — full subsystem touches 7-9 tab controllers + CreatePreset unfreeze + new package + new tab + tests. Realistic: 5-8 calendar days of focused work.

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

## Section 6 — CreatePreset unfreezing scope  [APPROVED]

CreatePreset was frozen on 2026-05-02 (commit c7d8a89). Under Project subsystem we unfreeze **minimally**: subscribe + read-from-Project only. Geometry, zone composition, draw-callbacks, coordinate transforms, image loading, pxl2sm calibration logic — all stay frozen.

**Wiring:**
1. CreatePresetApp constructor creates `obj.Project = sphynx.app.ProjectState()` (the app is the root container and owner).
2. CreatePresetApp itself does NOT subscribe — it's the root. The Project tab + every other tab controller does.
3. CreatePreset as a tab (tab 1) receives the listener.

**Detection of "user already edited" — three-state value source:**

Per-field state machine `obj.FieldSource.<name> = 'default' | 'project' | 'user'`:
- At buildUI time: `FieldSource.objectsNumber = 'default'`.
- In `onProjectChanged()`: if `FieldSource.<name> ~= 'user'` → overwrite value from `Project.Defaults.<name>`, set `FieldSource.<name> = 'project'`.
- In ValueChangedFcn: if the change did NOT originate from listener (guard via `obj.UpdatingFromListener = true/false` wrapping listener writes) → set `FieldSource.<name> = 'user'`.

Testable: load project defaults → switch ExperimentType → defaults update; manually edit one field → switch ExperimentType again → that field stays user value, others update.

**Fields under Project control:**
- ObjectsNumberField (uispinner)
- WallWidthCmField (uispinner)
- MiddleWidthCmField (uispinner)
- FrameRateField (uispinner)
- ArenaGeometryDropDown (Circle / Square / Polygon)
- NumStripsField, StripDirectionDropDown — if present in Defaults
- ObjectZoneWidthCmField, DistanceYCmField, DistanceXCmField — if present in Defaults

**Fields NOT under Project (frozen):**
- All draw callbacks, zone composition, click handlers, coordinate transforms.
- Image loading, pxl2sm calibration mechanic — geometry-sensitive.

**Logging:**
- On every successful `savePreset` →
  `Project.appendLog(struct('tab','CreatePreset', 'action','preset_saved', 'session',<preset_basename>, 'status','OK'))`.

**Explicit non-goals for the big-bang (deferred):**
- ExperimentType → zoneStrategy auto-add of zones. Requires unfreezing geometry. Deferred to its own design pass.
- Loading actsLibrary inside CreatePreset. Library belongs to Define Acts. CreatePreset only knows the name for preset metadata.

**Estimated touch:** `+sphynx/+app/CreatePresetApp.m` +constructor accepting Project, +FieldSource state, +UpdatingFromListener guard, +listener subscribe/teardown, +`onProjectChanged()` method, +appendLog in savePreset. ~80-120 LoC delta. C2.

---

## Section 7 — Backward compat / migration  [APPROVED]

Goal: nothing existing breaks. Project subsystem is additive.

**Scenario A — App started without a project:**
- `obj.Project = sphynx.app.ProjectState()` is constructed empty (Root=''; Defaults=Custom; Mice empty table).
- All tab listeners receive an idempotent empty callback; their loader-strips remain as fallback.
- User works exactly as today. Project tab shows "No project loaded — Create or Load".

**Scenario B — Existing folder without sphynx_project.json:**
- Project tab → Load → folder picker → JSON not found.
- Dialog: "Initialize as project here? This will scaffold the folder skeleton (if missing) and write sphynx_project.json with Custom defaults." [Yes/No]
- Yes → create skeleton (if folders missing), write JSON, ProjectState.update.
- No → close dialog, Project tab stays empty.

**Scenario C — H:\Dataset experiments (CC/FOF/NOF/RFC already converted):**
- These are typical "existing folders". On Load: skeleton partly exists (e.g. `5_BehaviorMAT_new` instead of `5_Behavior`).
- Resolution: in the Initialize flow the user **sees** the default folder names BEFORE the JSON is written and can edit them (e.g. type `5_BehaviorMAT_new` in the Behavior field). This is the same Folders UI section from Section 2 pre-filled with defaults.
- After Initialize: Scan mice over `<Folders.behavior>` collects mice → `Project.Mice` is populated.

**Scenario D — User opens a newer JSON than this code knows (schema=2):**
- Read `schema` field. If higher than supported → modal: "Project file uses newer schema (vN). Open in read-only mode? Some fields may be ignored." [Yes/No].
- Yes → load recognised fields only; set `obj.ReadOnly = true`; Save button disabled.
- No → don't load.

**Scenario E — User opens schema=1 (current):**
- Load all fields. Missing fields (partial older save) → fill from experimentType's Defaults.

**Scenario F — Migration path for future changes:**
- `+sphynx/+app/migrateProject.m`: `S = migrateProject(S, fromSchema, toSchema)`. Chain of forward-migrations. v1 → v2 will go through this function. At schema=1 the function is a no-op.

**Old preset .mat / _WorkSpace.mat files** — not touched, format unchanged. Project tab read-only sees them via Scan mice / Validate, but does not modify them.

---

## Section 8 — Testing approach  [APPROVED]

New tests under `tests/unit/` and `tests/integration/`. No headless-UI smoke for the new tab (uigridlayout headless is limited — class-load smoke only).

**Unit — `tests/unit/projectStateTest.m`:**
- testConstructEmpty: default values OK.
- testSetFieldNotifies: setField('Root', '/tmp') fires notify exactly once (listener-call counter).
- testUpdateBatched: update with 3 fields fires notify exactly once.
- testAppendLogGrowsAndNotifies.
- testJsonRoundTripFull: populate all fields → saveToFile → loadFromFile into new ProjectState → field-by-field equal.
- testJsonRoundTripPartial: JSON without `mice` → load → `Mice` defaults to empty table.
- testSchemaForward: schema=99 → loadFromFile sets ReadOnly=true.

**Unit — `tests/unit/experimentsRegistryTest.m`:**
- testRegistryNonEmpty.
- testAllRegistryReturnsStruct: for every name, `sphynx.experiments.get(name)` returns a struct with required fields (`experimentType`, `namePattern`, `frameRate`, `actsLibrary`).
- testCustomIsBlank: `Custom()` has experimentType='Custom', other fields allowed empty.

**Unit — `tests/unit/projectTabControllerSmokeTest.m`:**
- Class-load only: `?sphynx.app.ProjectTabController` returns a metaclass (no syntax error). Skip UI construction in headless.

**Integration — `tests/integration/projectPropagationTest.m`:**
- Construct `sphynx.app.ProjectState` (no UI).
- Attach a stub-listener (anonymous fn incrementing a counter).
- setField → counter=1; update(3 fields) → counter=2; appendLog → counter=3.
- JSON round-trip preserves the Mice table with categorical / mixed columns.

**Integration — `tests/integration/createPresetAppWithProjectTest.m`:**
- Construct CreatePresetApp in the same headless mode the existing `createPresetAppSmokeTest` uses.
- Verify `app.Project` exists and is `sphynx.app.ProjectState`.
- Verify ProjectTabController exists and registered a listener.
- Emulate: `app.Project.update(struct('Defaults', myDefaults))` → check that CreatePreset tab fields updated (direct read of `app.CreatePresetTabController.<UIField>.Value`).
- Validates the listener loop without UI events.

**Fixtures — `tests/fixtures/`:**
- `project_v1_full.json` — typical project, ~5 mice with a couple of ID_* columns.
- `project_v1_partial.json` — minimal (only experimentType + Root).
- `project_v99_future.json` — wrong-schema for forward-compat test.

**Coverage delta:** ~10 new tests. Existing 187 must stay green.

---

## Clarifications added during self-review

- **`actsLibrary` resolution in Defaults** — the value is either (a) a built-in name registered in `+sphynx/+acts/libraries/` or `+sphynx/+experiments/<Name>.m` (e.g. `'novelty_of_default'`), or (b) an absolute path to a `.mat`. The loader tries (a) first, falls back to (b). This applies to both Project.Defaults and direct user input in Define Acts.
- **Project.Mice column convention** — reserved columns: `mouse` (string), `included` (bool). Any other column is metadata and flows downstream into Make Output Table / Plot Data automatically. Convention: name them as `ID_<thing>` (`ID_sex`, `ID_drug`) or just `<thing>` (`group`, `line`, `sex`). The `renameUserColumns` helper in `buildSuperTable` already strips `ID_` prefix.
- **"User edited" semantics in Section 6** — defined via `FieldSource` state machine, NOT by comparing current value to last-set value. State transitions: `default → project` on listener apply; `default | project → user` on UI ValueChangedFcn outside listener context.

---

# Implementation plan handoff

When the user approves this spec, the next skill to invoke is `superpowers:writing-plans` to produce the implementation plan. Plan should break work into ordered passes:

1. **Pass A — ProjectState + experiments registry + unit tests.** No UI yet. Tests prove handle-class semantics, JSON round-trip, registry shape. Safe to land independently.
2. **Pass B — ProjectTabController + integration tests.** New Tab 0 only. CreatePresetApp gets `obj.Project` member but other tabs still don't subscribe. Project tab functional end-to-end (Create/Load/Save, Scan, Validate).
3. **Pass C — Subscribe Analyze + Batch + Make Output + Plot Data.** The "consumer" tabs that benefit most from project defaults. Lower risk than CreatePreset.
4. **Pass D — Unfreeze CreatePreset + Define Acts + Preprocess Tracking.** The "producer" tabs. Higher care because CreatePreset has frozen geometry around the change.
5. **Pass E — WIP stubs for Preprocess Video + Synthetic Data, polish, full regression run.**

Total estimate: 5-8 calendar days of focused work (C4 scope).

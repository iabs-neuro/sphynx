# Preprocess Tracking GUI tab — design

**Date:** 2026-04-30
**Branch:** `sphynx-GUI`
**Status:** approved (sprint mode)

## Goal

Добавить вторую вкладку в `sphynx.app.CreatePresetApp`: «Preprocess Tracking»
для интерактивной настройки per-bodypart параметров препроцессинга DLC
координатных трейсов. Юзер использует вкладку для подбора порогов на одной
сессии; настройки сохраняются per-experiment и применяются батчем к остальным.

## Non-goals

- Полный батч-раннер (отдельный скрипт после спайки настроек).
- Замена `analyzeSession` — этот этап только подготавливает trace data.
- Автоматическая идентификация частей тела (это уже в `+sphynx/+bodyparts/`).

## Architecture

Tab как часть существующего `CreatePresetApp`. Левая колонка — scrollable
панели (Loading / Per-part settings / Outlier filter / Save). Правая —
большое preview окно: X+Y графики параллельно для одной части тела +
гистограмма likelihood + опционально встроенное видео-окно.

### Files (new)

```
+sphynx/+app/
  CreatePresetApp.m              # extended with new tab
  PreprocessTabController.m      # logic for the new tab (separate class)

+sphynx/+preprocess/
  hampelFilter.m                 # Hampel outlier detection
  velocityJumpFilter.m           # pre-interp velocity-gate on raw position
  kalmanFilter2D.m               # 2D constant-velocity Kalman
  autoThreshold.m                # 4 methods: otsu, knee, quantile, presets
  applyPerPartSettings.m         # orchestrator: clean → outlier → interp → smooth
  exportTracks.m                 # save Tracks.mat + per-session output

+sphynx/+io/
  readTracksSettings.m           # load per-experiment Tracks.mat
  writeTracksSettings.m          # write per-experiment Tracks.mat

tests/unit/
  test_hampelFilter.m
  test_velocityJumpFilter.m
  test_kalmanFilter2D.m
  test_autoThreshold.m
  test_applyPerPartSettings.m
tests/smoke/
  test_preprocessTab_smoke.m     # headless instantiation + minimal flow
```

### Files (modified)

- `+sphynx/+app/CreatePresetApp.m` — register new tab, wire to controller.
- `+sphynx/+pipeline/defaultConfig.m` — add `preprocess.perPart` defaults.
- `+sphynx/+pipeline/analyzeSession.m` — read `_Preprocessed.mat` if present
  (skip cleanBodyPart/interpolateGaps/smoothTrace), else fallback to current.
- `docs/CreatePresetApp/README.md` — section on Preprocess tab.
- `docs/CreatePresetApp/user_guide_*.md` — workflow.

## Data model

### Per-experiment file: `<root>/<experimentName>_PreprocessSettings.mat`

```
Settings.bodyparts(i).name                    : char
Settings.bodyparts(i).use                     : logical (process this part?)
Settings.bodyparts(i).likelihoodThreshold     : double  (0..1)
Settings.bodyparts(i).smoothWindowSec         : double  (sec)
Settings.bodyparts(i).interpolationMethod     : 'pchip' | 'linear' | 'spline' | 'makima'
Settings.bodyparts(i).smoothingMethod         : 'sgolay' | 'movmean' | 'movmedian' | 'gaussian'
Settings.bodyparts(i).smoothingPolyOrder      : int      (sgolay only)
Settings.bodyparts(i).notFoundThresholdPct    : double  (default 90)
Settings.bodyparts(i).autoThresholdMethod     : 'none' | 'otsu' | 'knee' | 'quantile' | 'preset'
Settings.bodyparts(i).autoThresholdParam      : double  (param for the chosen method)

Settings.outlier.velocityJump.enabled         : logical (default true)
Settings.outlier.velocityJump.maxVelocityCmS  : double  (default 50)
Settings.outlier.hampel.enabled               : logical (default false)
Settings.outlier.hampel.windowSize            : int     (default 7)
Settings.outlier.hampel.nSigma                : double  (default 3)
Settings.outlier.kalman.enabled               : logical (default false)
Settings.outlier.kalman.processNoise          : double  (default 1e-2)
Settings.outlier.kalman.measNoiseScale        : double  (default 1)

Settings.metadata.experimentName              : char
Settings.metadata.savedAt                     : datetime
Settings.metadata.dlcSchemaHash               : char (sha1 of bodyparts list)
```

### Per-session file: `<sessionDir>/<sessionName>_Preprocessed.mat`

```
BodyPartsTraces(i).BodyPartName                 : char
BodyPartsTraces(i).TraceOriginal.X / .Y         : Nx1 double
BodyPartsTraces(i).TraceLikelihood              : Nx1 double
BodyPartsTraces(i).TraceInterpolated.X / .Y     : Nx1 double
BodyPartsTraces(i).TraceSmoothed.X / .Y         : Nx1 double
BodyPartsTraces(i).Status                       : 'Good' | 'NotFound'
BodyPartsTraces(i).PercentNaN                   : double
BodyPartsTraces(i).PercentLowLikelihood         : double
BodyPartsTraces(i).PercentOutliersDetected      : double
BodyPartsTraces(i).AppliedSettings              : struct (snapshot of per-part)

ManualExclusionRegions(j).vertices              : Mx2 [x y]
ManualExclusionRegions(j).appliesTo             : 'all' | bodypart name

Source.dlcPath                                  : char
Source.videoPath                                : char
Source.presetPath                               : char
Source.settingsPath                             : char (path to PreprocessSettings.mat)

OutputPlots(i)                                  : char (path to .png) — optional
```

## UI layout

```
+----------------------------------------------------------------------+
| [Create Preset] [Preprocess Tracking] [Analyze Session]              |
+----------------------------------------------------------------------+
| 1. Loading                          | Preview                        |
|   Root                              |   X(t) trace (raw/interp/smth) |
|   DLC csv                           |                                |
|   Video                             |   Y(t) trace (raw/interp/smth) |
|   Preset                            |                                |
|   [Load all]                        |   Likelihood histogram         |
|                                     |                                |
| 2. Per-part settings                |  current bodypart: [< >] nose  |
|   uitable (rows = bodyparts):       |  current frame:    [---o-----] |
|   [x][name][thr][win][int][sm][nf]  +--------------------------------+
|   [...]                             |  Embedded video viewer         |
|   [Default this] [Default all]      |  (toggle: [Show video])        |
|   [Compute this] [Compute all]      |  ▶ play   ◀ ▶ frame ±1         |
|   [Auto thresholds ▾ method]        +--------------------------------+
|                                     |  Manual exclusion regions      |
| 3. Outlier filter                   |  [Add region] applies to: [▾]  |
|   [x] velocity-jump  max:[50] cm/s  |  • region 1 (nose)             |
|   [ ] Hampel  win:[7]  k:[3]        |  • region 2 (all)              |
|   [ ] Kalman  Q:[1e-2]              |  [Delete] [Clear]              |
|                                     +--------------------------------+
| 4. Save                             |  Log (last 500)                |
|   Output dir                        |                                |
|   [x] save plots per bodypart       |                                |
|   [Save preprocessed]               |                                |
+----------------------------------------------------------------------+
```

### Bodypart switching

Стрелочки `<` `>` под preview + dropdown с именем. Также кликабельная строка
в таблице переключает превью.

### Live recompute

`CellEditCallback` на uitable с debounce 300мс. После debounce —
`PreprocessTabController.recomputePart(i)` обновляет TraceInterpolated,
TraceSmoothed, гистограмму, статус.

## Algorithms

### velocityJumpFilter (pre-interp на сырой позиции)

```
dx = diff(X), dy = diff(Y)
vRaw = sqrt(dx^2 + dy^2) * fps / pxlPerCm
bad = vRaw > maxVelocityCmS
X(bad+1) = NaN, Y(bad+1) = NaN
```

Применяется ДО `interpolateGaps`. Дополняет существующий clip в
`computeVelocity` (который работает уже на сглаженной траектории).

### hampelFilter

```
[X_clean, idxOutlier_X] = hampel(X, win, nSigma)
[Y_clean, idxOutlier_Y] = hampel(Y, win, nSigma)
bad = idxOutlier_X | idxOutlier_Y
X(bad) = NaN, Y(bad) = NaN
```

Использует встроенный `hampel()` Signal Processing Toolbox.

### kalmanFilter2D (hand-rolled)

Constant-velocity 2D state: `[x, y, vx, vy]`.
Transition: `F = [I dt*I; 0 I]`. Measurement: `H = [I 0]`.
Process noise `Q` диагональ × `processNoise`.
Measurement noise `R = R0 / likelihood^2` (низкий likelihood → высокий шум →
фильтр меньше доверяет, гладит сильнее).
Стандартный predict/update цикл. Возвращает сглаженные `(x, y)`.

### autoThreshold (4 метода)

- **otsu**: `multithresh(likelihood, 1)` → один порог на гистограмме.
- **knee**: ищет точку максимальной кривизны на CDF likelihood (RANSAC к двум
  линиям + угол).
- **quantile**: `quantile(likelihood, param)`, param дефолт 0.05.
- **preset**: enum `aggressive=0.99 / moderate=0.95 / lax=0.6`.
- В UI: dropdown метода + поле «param» + кнопка «apply to selected/all».

## Edge cases

- DLC опечатки в именах (`righforelimb` без `t`) — в UI показываем как есть,
  не пытаемся «исправить». Алиасы для `pickSmoothWindow` уже есть, добавим
  для всех hardcoded списков.
- Все frames bad после фильтрации → Status='NotFound', не падаем.
- nFrames < smoothWin → smooth пропускается (уже обрабатывается в smoothTrace).
- Manual region вне frame bounds → клипуется к bounds.
- `likelihood` всё единицы (хорошо размечено) → Otsu падает; fallback на
  preset moderate.

## Testing

- Unit: каждый из 4 outlier/auto алгоритмов синтетическим input'ом.
- Integration: `applyPerPartSettings` end-to-end на одной части тела.
- Smoke: GUI tab instantiates без ошибок (без отображения окон) +
  имитация Compute one part.
- Regression: golden snapshot перед/после миграции analyzeSession чтобы убедиться
  что подключение `_Preprocessed.mat` даёт идентичный результат.

## Dependencies on missing toolboxes

- Curve Fitting: НЕ используется (sgolayfilt вместо smooth).
- Sensor Fusion: НЕ используется (Kalman написан с нуля).
- Computer Vision: НЕ используется (внешние видео через `VideoReader`).

## Open questions (resolved 2026-04-30)

- Q1 storage: per-experiment Settings + per-session Preprocessed (decided).
- Q2 save: settings + plots per part (decided).
- Q3 auto: реализовать все 4 метода (decided).
- Q4 outlier: все три, дефолты velocity-ON / Hampel-OFF / Kalman-OFF (decided).
- Q5 manual regions: per-region attached to bodypart via dropdown (decided).
- Q6 preview: одна часть, X+Y параллельно + likelihood histogram (decided).
- Q7 video: встроенное окно с slider (decided).
- Q8 compute: Compute this обновляет одну, Save проверяет «all up-to-date» (decided).
- Q9 NotFound: per-part в таблице (decided).
- Q10 order: спринтом, начинаем с Slice 1+2 (decided).

## Future / non-blocking

- **Batch runner** (отдельная задача) — применить `_PreprocessSettings.mat`
  ко всем сессиям эксперимента без открытия GUI.
- **Save raw для re-runs** — раз картинки уже включают raw, не критично.
- **Per-part live recompute timer** — debounce 300мс, можно поднять до
  500мс если будут тормоза.

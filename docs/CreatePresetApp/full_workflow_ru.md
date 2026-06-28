# sphynx -- Полный workflow GUI (рус.)

Окно `sphynx.app.CreatePresetApp` содержит 9 пронумерованных вкладок,
покрывающих весь pipeline поведенческого анализа:

```
1. Create Preset -> 2. Preprocess Tracking -> 3. Define Acts
  -> 4. Analyze Session -> 5. Batch Analysis -> 6. Make Output Table
  -> 7. Plot Data
Вспомогательные: 8. Preprocess Video, 9. Synthetic Data
```

Этот документ объясняет **логику** каждой вкладки и **порядок работы**
от начала до конца.

## Что нового с R20

- Пронумерованные вкладки (1..9) в заголовке.
- Вкладка 2: кнопки "Check another" + "Load preprocessed".
- Вкладка 3: Barnes-дефолт-библиотека теперь 64 акта
  (nose_at_<hole>, body_at_<hole>, пара platform,
  mouse_inside_<hole>, nose_at_any_hole); превью зоны обновляется
  при выборе; mouse_inside_* требует устойчивых 2 с.
- Вкладка 4: двухстрочный loader, listbox фильтра актов для
  этограммы, "Render main video" по умолчанию ON, новый стиль
  оверлеев видео (белый текст с чёрной обводкой, жёлтый квадрат
  счётчика).
- Вкладка 5: парование принимает legacy DLC csv И
  superanimal-topviewmouse csv; многозначные ID мыши / дня / трайла.
- Шапка статистики Вкладки 4 теперь содержит Barnes-метрики
  (TotalNoseHoleVisits, PrimaryErrors, TotalBodyHoleVisits,
  NumCheckedHoles, FirstCheckedHoleNumber, FirstCheckedHoleErrorDeg,
  MeanCheckedHoleErrorDeg, TargetHoleVisitOrder) -- полные
  определения в `docs/Barnes/metrics.md`.
- `sphynx_defaults.jsonc` (корень репо) -- единый файл дефолтов,
  разложен по вкладкам, авто-подгружается
  `sphynx.pipeline.defaultConfig`.

---

## 0. Запуск

```matlab
startup
sphynx.app.CreatePresetApp
```

Окно открывается во весь экран.

---

## 1. Create Preset *(пошаговая справка -- `user_guide_ru.md`;
заморозка снята 2026-06-03, правки в рамках Barnes-спеки разрешены)*

Для каждой видео-сессии собираешь *preset* — `.mat` файл с:
калибровкой пикселей в см, контуром арены, контурами объектов,
пространственными зонами (углы / стены / центр / окрестности
объектов / и т.д.).

**Выход:** `<videobase>_Preset.mat` рядом с видео.

---

## 2. Preprocess Tracking

DLC csv содержит сырые `(x, y, likelihood)` для каждой части тела на
каждом кадре. Pipeline предобработки:

```
likelihood → bounds → velocity-jump → Hampel → manual regions
  → interpolate → smooth (sgolay / movmean / movmedian / gaussian)
                  ИЛИ Kalman 2D (заменяет sgolay)
```

Per-part настройки (порог / окно / interp / smooth-метод) — таблица
справа. Outlier-фильтры (velocity-jump, Hampel) глобальные, в Block 2.
Manual exclusion regions рисуются на кадре пресета для мест где DLC
систематически ошибается (например, тень от кабеля воспринимается как
ухо).

**Выходы:**
- per-experiment `<root>/<expName>_PreprocessSettings.mat` -- настройки,
  переиспользуются для всех сессий эксперимента.
- per-session `<sessionDir>/<sessionName>_Preprocessed.mat` -- сами
  очищенные + сглаженные трейсы; читаются analyzeSession.

**Кнопки R24 (строка загрузки):**
- **Check another** -- оставить текущие per-part настройки и
  подгрузить другой DLC csv. Позволяет проверить несколько сессий с
  одинаковыми порогами перед сохранением.
- **Load preprocessed** -- подгрузить сохранённый
  `<exp>_PreprocessSettings.mat` и применить к текущему DLC. Удобно
  раскатать подобранный конфиг на все сессии того же эксперимента.

---

## 3. Define Acts

*Поведенческий акт* — это per-frame булев сигнал. Библиотека содержит
два типа:

**Простой акт** — true на кадре если:
  - выбранная часть тела находится в одной из выбранных зон
    (multi-select = OR; для AND/EXCLUDE используй complex акт);
    выбор `<any zone>` означает «без ограничения по зоне»,
  - **И** скорость этой части тела в `[speedMin, speedMax]`
    (`SpeedMax = Inf` означает «любая скорость сверху»).

**Комплексный акт** — комбинация N уже определённых актов через
логическую операцию:
  - `intersect` — оба A и B одновременно,
  - `union` — A или B,
  - `exclude` — A но не B,
  - `sequence` — A потом B в течение `seqDelaySec` секунд.

Также есть **special-акты**:
  - `freezing` — head + center velocity ниже порога одновременно,
  - `rears` — расстояние tailbase-paws ниже порога (см).

Библиотека загружается с дефолтами (rest / walk / locomotion /
freezing / rears) при открытии вкладки. Save/Load сохраняет/загружает
библиотеку в `.mat` для переиспользования.

**Barnes-дефолт-библиотека (кнопка "Load Barnes defaults"):** всего
64 акта --
  - 1 + 19 `nose_at_<hole>` (целевая + все нецелевые лунки),
  - 1 + 19 `body_at_<hole>`,
  - пара platform (`on_platform`, `off_platform`),
  - 1 + 19 + 1 `mouse_inside_<hole>` (target, каждая нецелевая, плюс
    `mouse_inside_any_hole`); это семейство требует устойчивых 2 с,
    задано per-act через `minDurationSec=2.0`,
  - `nose_at_any_hole`.

Выбор акта в списке библиотеки теперь обновляет превью зоны, чтобы
было видно, какая лунка / зона участвует.

**Выход:** `<expName>_acts_library.mat`.

---

## 4. Analyze Session

Прогон полного pipeline на **одной** сессии. UI:
- **Двухстрочная** строка загрузки (batch-style):
  - Строка 1: Root / Preset / Video / DLC / Out dir.
  - Строка 2: Preproc settings / Acts library.
- Override порогов rest / locomotion / freezing.
- Run -> таблица результатов с `Act / % / duration / count / mean
  dur, s` для каждого акта (built-in + library).
- Графики: траектория body-center (с **listbox фильтра актов слева
  от панели траектории** -- отбирает, какие акты рисовать), timeline
  актов (одна строка на акт), histogram скорости bodycenter.
- Чекбокс "Render main video" по умолчанию **ON**. На отрендеренном
  видео инфоблок прижат к верхнему левому углу: белый текст с
  чёрной обводкой 1 px, без подложки. Счётчик кадров -- жёлтый
  квадрат высотой 10% кадра в правом верхнем углу.

Шапка статистики сессии теперь содержит Barnes-метрики:
`TotalNoseHoleVisits`, `PrimaryErrors`, `TotalBodyHoleVisits`,
`NumCheckedHoles`, `FirstCheckedHoleNumber`,
`FirstCheckedHoleErrorDeg`, `MeanCheckedHoleErrorDeg`,
`TargetHoleVisitOrder` (см. `+sphynx/+pipeline/barnesSessionMetrics.m`).
Полные определения -- `docs/Barnes/metrics.md`.

Используй эту вкладку для проверки что библиотека + пороги дают
адекватный результат до запуска батча. Результаты сохраняются как
`<sessionDir>/<sessionName>_WorkSpace.mat` (читается Make Output
Table).

---

## 5. Batch Analysis

Прогон analyzeSession на наборе пар (DLC, Preset). UI:
- `+ Session` добавляет одну пару DLC + Preset в список.
- Один **Output dir** на всё (per-session подпапки автоматически).
- Один опциональный **Acts library** на весь батч.
- Чекбоксы: save plots / save per-session .mat / build aggregate
  tables.
- Run -> progress bar; tidy + wide tables справа.
- **Save tables to CSV** -> tidy + wide csv в output dir.

**Парование сессий (R24):** автопарователь DLC csv c пресетами
теперь принимает ОБА семейства имён csv:
- legacy DeepLabCut, напр. `WNOF_J01_1DDLC_resnet50_...csv`,
- superanimal-topviewmouse, напр.
  `NOF_H01_1D_superanimal_topviewmouse_..csv`.

Многозначные ID мыши / дня / трайла поддержаны (`m23`, `m183`,
`m5718`, `12d_3t`, ...).

Wide table здесь -- быстрый предпросмотр. Для контролируемого
экспорта с метаданными для Prism -- см. Make Output Table.

---

## 6. Make Output Table

Агрегирует per-session WorkSpace.mat файлы в широкую таблицу для
GraphPad Prism (и Excel). UI:
- **Batch dir** — папка из шага 5.
- **Metadata CSV** (опционально) — колонки
  `session_name, mouse, session, group, line`. Если отсутствует, mouse
  и session парсятся из имён файлов (`<exp>_<mouse>_<session>D`).
- **Metrics** — multi-select (ActPercent, ActDuration, ActNumber,
  ActMeanTime, …). Distance и Velocity per session добавляются всегда.
- **NaN policy** — keep (дефолт) или zero. Некоторые downstream-tools
  предпочитают нули вместо пустых ячеек.
- **Sort by** — главный ключ сортировки строк.
- **Build table** → wide и tidy в правом окне.
- **Save CSV** → `super_table.csv` (wide, для Prism) и
  `super_table_tidy.csv` (long format).

Wide format: одна строка на мышь, колонки = `mouse / group / line /
<act>_<metric>_<session> / distance_cm_<session> /
velocity_cm_per_s_<session>`.

---

## 7. Plot Data

Быстрые предварительные графики из wide CSV. UI:
- Browse + Load → numeric колонки автоматически в dropdown.
- **Plot column** — какую численную метрику строить.
- **Group by** — `group` / `line` / `<none>` (любая текстовая колонка).
- **Plot type** — bar (mean ± SEM), box, scatter.
- **Colormap** — parula / jet / hsv / cool / hot / plasma / viridis.
- **Error bars** — SEM / SD / none.
- **Overlay individual points** — точки с jitter поверх bar/box.
- Plot → рендер. Save PNG → экспорт.

Эта вкладка для быстрого осмотра — финальные графики делаются в Prism
или Python.

---

## 8. Preprocess Video *(вспомогательная)*

Обёртка над legacy скриптами в папке `/Preprocess`. UI:
- **Browse** папку с видео → таблица файлов с FPS / frames /
  resolution / duration.
- **Fix FPS metadata** — правит метаданные in-place если видео было
  записано с неправильным FPS.

Полезно когда сырые видео с камеры имеют неправильные FPS-метаданные —
DLC и downstream-анализ будут считать неправильно.

---

## 9. Synthetic Data *(вспомогательная)*

Генерирует синтетические DLC csv + минимальный preset для тестирования
preprocessing / анализа без реального животного. Модели движения
(random walk / circular / Ornstein-Uhlenbeck), режимы выбросов (none
/ spikes / long_gap / poor_likelihood / mixed), модели likelihood
(bimodal_high_quality / bimodal_borderline / unimodal_high /
unimodal_low). Save в папку или Load synthetic кнопка в Preprocess
Tracking для прямой загрузки в работу.

---

## End-to-end пример: эксперимент WNOF

```
Project root: <root>/
  videos/   WNOF_J01_1D.mp4, WNOF_J01_2D.mp4, ... WNOF_J05_1D.mp4, ...
  dlc/      WNOF_J01_1DDLC_resnet152_....csv, ...
  presets/  WNOF_J01_1D_Preset.mat, ...
  metadata.csv  (session_name, mouse, session, group, line)
  preprocess/   <expName>_PreprocessSettings.mat
  acts/         WNOF_acts_library.mat
  out/          <-- output dir для батча
```

1. **Create Preset** для каждой сессии → `presets/`.
2. **Preprocess Tracking**: загрузить одну DLC + preset, подобрать
   per-part настройки, сохранить per-experiment `_PreprocessSettings.mat`.
3. **Define Acts**: собрать библиотеку под WNOF (визиты к объектам
   по одному и всем, время в углах и т.п.), сохранить в `acts/`.
4. **Analyze Session** на одной (DLC, preset, acts library) — проверить
   траекторию + проценты актов.
5. **Batch Analysis** для всех сессий с этой библиотекой →
   `out/<session>_WorkSpace.mat` для каждой.
6. **Make Output Table** с metadata.csv -> `out/super_table.csv`.
7. **Plot Data** из `super_table.csv` -- предварительные bar / box /
   scatter по группам. Финальные графики в Prism.

---

## Глобальные дефолты: `sphynx_defaults.jsonc`

Единый файл настроек в корне репо -- `sphynx_defaults.jsonc` --
авто-подгружается `sphynx.pipeline.defaultConfig`. Меняй там
дефолты по всему приложению (пороги likelihood по умолчанию, окна
сглаживания, дефолтные галочки графиков, число лунок Barnes,
дефолтные опции сохранения). Секции внутри файла организованы по
вкладкам: настройка, влияющая на Вкладку 4, лежит в блоке Вкладки 4.
Менять дефолты здесь безопаснее, чем править конструкторы в MATLAB.

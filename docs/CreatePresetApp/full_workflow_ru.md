# sphynx — Полный workflow GUI (рус.)

Окно `sphynx.app.CreatePresetApp` содержит 9 вкладок, покрывающих
весь pipeline поведенческого анализа:

```
Create Preset → Preprocess Tracking → Define Acts → Analyze Session
              → Batch Analysis → Make Output Table → Plot Data
Вспомогательные: Preprocess Video, Synthetic Data
```

Этот документ объясняет **логику** каждой вкладки и **порядок работы**
от начала до конца.

---

## 0. Запуск

```matlab
startup
sphynx.app.CreatePresetApp
```

Окно открывается во весь экран.

---

## 1. Create Preset *(заморожен — см. `README.md` и `user_guide_ru.md`
для полной справки)*

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
- per-experiment `<root>/<expName>_PreprocessSettings.mat` — настройки,
  переиспользуются для всех сессий эксперимента.
- per-session `<sessionDir>/<sessionName>_Preprocessed.mat` — сами
  очищенные + сглаженные трейсы; читаются analyzeSession.

---

## 3. Define Acts

*Поведенческий акт* — это per-frame булев сигнал. Библиотека содержит
два типа:

**Простой акт** — true на кадре если:
  - выбранная часть тела находится в выбранных зонах (с операцией
    `AND` / `OR` / `EXCLUDE` между зонами — например, «в углах, но
    не возле объектов»),
  - **И** скорость этой части тела в `[speedMin, speedMax]`.

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

**Выход:** `<expName>_acts_library.mat`.

---

## 4. Analyze Session

Прогон полного pipeline на **одной** сессии. UI:
- Browse DLC csv, preset .mat, output dir, опционально acts library.
- Override порогов rest / locomotion / freezing.
- Run → таблица результатов с `Act / % / duration / count / mean
  dur, s` для каждого акта (built-in + library).
- Графики: траектория body-center, timeline актов (одна строка на акт),
  histogram скорости bodycenter.

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
- Run → progress bar; tidy + wide tables справа.
- **Save tables to CSV** → tidy + wide csv в output dir.

Wide table здесь — быстрый предпросмотр. Для контролируемого экспорта
с метаданными для Prism — см. Make Output Table.

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
6. **Make Output Table** с metadata.csv → `out/super_table.csv`.
7. **Plot Data** из `super_table.csv` — предварительные bar / box /
   scatter по группам. Финальные графики в Prism.

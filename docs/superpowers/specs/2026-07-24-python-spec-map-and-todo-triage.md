# Python-переезд: карта спек + раскладка TODO

Дата: 2026-07-24
Ветка: `Sphynx-python`
Статус: согласовано с пользователем (карта спек, механизм ролей, экспорты отдельной спекой)

Назначение документа: единая точка, куда разложены все хвосты (TODO.md +
MATLAB-эровые спеки) по четырём Python-спекам. Живёт, пока идёт переезд;
по мере закрытия пунктов -- вычёркиваем.

---

## 1. Карта спек

| # | Спека | Файл | Охват |
|---|---|---|---|
| **S1** | Порт движка | `2026-07-21-sphynx-python-engine-design.md` | Механический порт с поведенческим паритетом: preprocess, bodyparts, angles, zones/preset-геометрия, встроенные акты, **слой Events (одиночные акты)**, generic `act x stat` метрики, pipeline/super-table, OF end-to-end. |
| **S2** | Парадигмы, акты и метрики (система) | `2026-07-2X-...` (новая) | **Рефактор, а не порт.** Роли зон, композитные зоны, семейства актов, роль-селекторы, реестр именованных метрик, иерархия парадигм (OF/EOF/NOR/Barnes/T-Y/New), валидация-как-данные. Barnes-метрики. |
| **S3** | Экспорты / feature extraction | `2026-07-2X-...` (новая) | kinematogram, spaceogram, features (per-frame продукты для ML/RL). Список каналов проектируется здесь. |
| **S4** | Qt-GUI (PySide6) | `2026-07-2X-...` (новая) | Вкладки, двухпанельный конструктор актов/метрик, поверхность варнингов, project-subsystem. Остатки Pass 2 из barnes-features. |

**Ключевой сдвиг охвата (по сравнению с первой редакцией S1):** Barnes-метрики и
механизм ролей/композитов/семейств **вынесены из S1 в S2**. Причина: их правильная
реализация -- это редизайн на слое Events + роли зон, а не построчный перенос
`barnesSessionMetrics.m`. S1 доводит до паритета общий путь (OF) и строит
фундамент (Events для одиночных актов, generic-метрики); S2 надстраивает
парадигменную систему.

Зависимости: **S1 -> S2 -> S4**; **S1 -> S3 -> S4**. S2 и S3 независимы между собой.

## 2. Статус MATLAB-эровых спек

| Спека | Статус | Куда переезжает |
|---|---|---|
| `2026-04-27-stage-c` | **исторический** -- породил `+sphynx`, выполнен | Требования -> S1. «Goal B: универсализация по экспериментам» -> S2. |
| `2026-04-30-preprocess-tab` | выполнен (GUI-вкладка) | UX-требования -> S4. Движковая часть (hampel/kalman/autothreshold/per-part) уже в `+sphynx`, портируется в S1. |
| `2026-05-19-presentation-video-mode` | выполнен | Рендер-стиль -> S3/S4 (видео-оверлеи). |
| `2026-06-03-barnes-features` | Pass 1 выполнен; Pass 2 -- GUI-фичи | Pass 2 GUI (S1-S11) -> S4. Barnes-метрики (out-of-scope в этой спеке) -> S2. Семантика `class` объекта -> S2 (роли зон). |

## 3. Раскладка TODO.md

Формат: пункт TODO -> целевая спека, либо **DEAD** (снимается сам при переезде),
либо **DONE** (уже закрыто).

### Умирают сами при переезде на Python (не переносим)
| Пункт TODO | Почему |
|---|---|
| 4-way duplication of defaults (`minDurationSec=0.25` x4 и т.д.) | Решается `Config` (единый источник, S1) |
| `bcIdx` silent-fallback-to-1 (4 сайта) | Решается `Session.part()` + политика §10 (S1) |
| `pxlPerCm=1` silent fallback (5 сайтов) | Решается политикой §10: варнинг + честный NaN (S1) |
| Typo `righforelimb` | Synonym-map переписывается в S1 |
| `implay` R2020a API, frame-scrubber в implay | Qt заменяет плеер (S4) |
| BatchAnalysisTab preproc-settings picker dead | GUI пересобирается в S4 |
| DefineActs Make-video bypasses Preproc Settings | GUI пересобирается в S4 |

### -> S1 (движок)
| Пункт | Заметка |
|---|---|
| R28: applyAct unguarded `ctx.frameRate` (NaN) | Политика §10 |
| R28: `detectSessionStartFrame` WindowFrames fps-implicit | Порт с фиксом (сек, не кадры) |
| R28: Kalman noise params dead when method != kalman | Порт с честным поведением |
| R28: Synonym map gaps (eyes, mid_back, tail2..5) | bodyparts |
| R28: Document `identifyParts` first-match rule | bodyparts |
| Batch: resume-on-error (одна сессия упала -> продолжить) | `run_batch` |
| Universal: audit `actStats` for missing fields | generic-метрики |
| Scattered `% TODO` (cleanBodyPart magic numbers, speedActs midPoint) | Разрешаются при порте модулей |
| Golden-guard (открытый из R31) | Snapshot-регрессия в S1 (§9) |

### -> S2 (парадигмы/акты/метрики)
| Пункт | Заметка |
|---|---|
| **Per-class-of-objects act constructor** | Ядро: семейства над `zone_class` |
| **Complex-acts redesign** (expression composition) | Модель актов; композитные акты через вычитание/объединение зон |
| Act post-filters (median window + min-duration) | Схема акта |
| Move FreezingMode/RearMode to Define Acts | Акты -- свойство библиотеки, не анализа |
| R28: **Barnes 19-hole default leaks** | Решается семействами+ролями, а не патчем `NumObjects` |
| Analyze: bucket exclusivity breaks per-act refine | Взаимодействие актов (совместный refine бакета) |
| Universal act-derived features (time-to-completion, time-to-first) | Именованные метрики над Events |
| `discrimination_index` -> `ratio_index(a,b)` между любыми двумя актами | Реестр метрик |
| Barnes maze metrics (8 обучение + 9 тест) | Именованные метрики над Events + геометрией |
| Metadata/experiment system, per-experiment defaults | Иерархия парадигм + метаданные |
| Barnes-features Pass 2 out-of-scope: скаффолд Barnes-метрик | Сюда же |

### -> S3 (экспорты/features)
| Пункт | Заметка |
|---|---|
| Per-session standard outputs (features, kinematogram, egocentric, etogram) | Прямо эта спека |
| Analyze: Egocentric trajectory + heading-angle trace | spaceogram |
| Make Output: export per-group summary stats (n, mean, sem) | Табличный экспорт |
| Make Output: outlier warning (MAD-порог) | Часть output-слоя (варнинг -- в S4) |
| Analyze: split bodyparts-trajectory plots (trajectory/timeseries) | Плоты-экспорты |

### -> S4 (Qt-GUI)
| Пункт | Заметка |
|---|---|
| Create Preset: download preset, zones on new video, dup-zone warnings, **object-copy xN** | + barnes-features S1-S11 (Pass 2) |
| Preprocess Tracking: layout, log-Y toggle, likelihood-vs-time plots | |
| DefineActs / MakeOutput / Analyze / Batch: все чисто-UI пункты | Min-run field, dropdowns, settings-load filter, etogram grouping, кастом-плоты, progress bar, column reorder, per-metric rounding | |
| Cross-cutting: numbered tabs, app-wide state, **Project subsystem** | |
| Cross-cutting: extract mice from batch dir, metadata accumulation | |
| Двухпанельный конструктор (акты слева / метрики справа) | Опирается на S2 |
| Поверхность варнингов парадигм и непройденных этапов (§10) | |

### Отложено -- вне текущих четырёх спек (свои будущие спеки)
| Пункт | Заметка |
|---|---|
| Plot Data (WIP) -- вся вкладка | Стат-тесты (RM-ANOVA и пр.) -- отдельная будущая спека |
| Preprocess Video (WIP) -- вся вкладка | Видео-препроцесс -- отдельная будущая спека |
| Synthetic Data (WIP) -- вся вкладка | Пользовательский генератор -- отдельная будущая спека |
| Tracker compat (SLEAP / Bonsai / Lightning Pose) | io-расширение, будущее (частично S1 `io`) |

### Открытые вопросы (проектируются позже, привязаны к спекам)
| Вопрос | Спека |
|---|---|
| Деградация актов по частям тела: что от какой берёт при пропаже; угол головы без части | S2 (модель актов, декларируемые части + fallback-цепочка) |
| Список каналов kinematogram / spaceogram / features | S3 |
| T/Y-maze метрики выбора/решения | S2 (после основной) |
| Центр арены: авто (центроид маски) + ручной сдвиг; `angle` зоны относительно него | S2 (роли/геометрия), UI-сдвиг -> S4 |

## 4. Что дальше

1. S1 (движок) -- финализировать ревью и уйти в writing-plans (M1 первым).
2. S2 (парадигмы) -- отдельный брейнсторм, вбирает раскладку выше.
3. S3, S4 -- по мере готовности зависимостей.

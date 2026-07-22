# Sphynx: порт движка на Python -- дизайн

Дата: 2026-07-21
Ветка-источник: `sphynx-GUI-R2025` (MATLAB, @14fc92c -- вычищенный движок + фиксы R31)
Ветка-цель: `Sphynx-python`
Статус: утверждён пользователем, готов к написанию плана реализации

---

## 1. Цель и контекст

Переписать research-код Sphynx с MATLAB (разрабатывался на R2020a) на Python.
Причина: на MATLAB GUI было проблематично обновлять, настраивать и расширять.

Из аудита R31 известно: движок структурно здоров, 8 найденных дефектов были
локальными, архитектурных проблем нет. Портируем работающую логику, а не спасаем
тонущий код.

**Эта спека покрывает только движок (headless).** Qt-GUI -- отдельная спека следом.

## 2. Принятые решения

| Вопрос | Решение |
|---|---|
| GUI-стек (для будущей спеки) | **PySide6 / Qt** -- как у DeepLabCut; силён в интерактивном канвасе (рисование зон на кадре, видео-оверлеи, скраббинг) |
| Порядок работ | **Движок вперёд**, GUI строится поверх доказанного ядра |
| Планка приёмки | **Поведенческий паритет**, не побитовая сверка с MATLAB (эталонных дампов на MATLAB нет, мост MATLAB<->Python не делаем) |
| Охват | Весь движок, **кроме**: генератора синтетики, стат-тестов (Plot), видео-препроцесса |
| Архитектурный подход | **C: зеркало структуры + точечные абстракции** |

### Подход C

Структуру пакетов зеркалим 1:1 с MATLAB (легко сверять и переносить), но вводим
ровно те абстракции, что бьют в цель «проще настраивать / обновлять / расширять»:
типизированный `Config`, реестр актов, объект `Session`. Остальное -- прямой перенос.

Отвергнуто: **A** (чистое 1:1) -- тащит MATLAB-измы, которые и были болью;
**B** (полная ре-архитектура на xarray/плагинах) -- избыточное проектирование
вперёд и высокий риск растекания при отсутствии эталонов для сверки.

## 3. Доменная модель (ядро спеки)

### 3.1 Проблема

Акты и метрики выглядели «перемешанными», особенно в парадигме Barnes.

Определения из предметной области:
- **Акт** -- повторяющийся поведенческий акт животного. Это **сигнал**: булев ряд
  длины N кадров. По нему считают статистику: количество, процент времени, среднее время.
- **Метрика** -- характеристика **на сессию**: скаляр (общая пройденная дистанция,
  количество неправильно проверенных лунок).

Это не конкурирующие понятия, а **разные уровни: сигнал и свёртка сигнала**.
«Метрика считается из статистики акта» -- нормально и ожидаемо.

Настоящая причина путаницы: **отсутствует промежуточный слой событий**. Из-за этого
Barnes-метрики лезут руками внутрь бинарных рядов (см. `barnesSessionMetrics.m`),
и логика выглядит спутанной.

### 3.2 Слои

```
0. Traces      x, y, velocity, angles                   per-frame float
1. Geometry    зоны с атрибутами:                        из Preset + Paradigm
               name, class, index, is_target, angle
2. Acts        булев ряд                                 per-frame bool
               - одиночные:  freezing, rear, rest
               - семейства:  nose_at_hole[k]  (параметризованы классом зон)
3. Events      упорядоченные эпизоды с метками            <-- недостающий слой
               [(start, end, duration, label=hole_7), ...]
4a. ActStats   generic-свёртки, АВТОМАТОМ для любого акта
               count, %time, mean/median duration, distance, velocity
4b. Metrics    именованные скаляры на сессию, ЯВНЫЕ зависимости
5. Output      строка = выбранные (акт x стат) + выбранные метрики
```

### 3.3 Слой Events

Из бинарного ряда любого акта механически выводится список эпизодов
`(start_frame, end_frame, duration)`. Для семейств актов эпизоды несут метку
элемента семейства и сливаются в один **упорядоченный по времени поток**.

Это разблокирует ровно те метрики, которые не выводятся из агрегатной статистики:

| Barnes-метрика | Что нужно |
|---|---|
| primary latency | время **первого** события целевой лунки |
| primary errors | число **разных нецелевых** лунок **до первого** попадания в целевую |
| ordinal index целевой лунки | **позиция** цели в упорядоченной последовательности проверок |
| angular distance первой лунки | **первое событие** + геометрия |
| search strategy | траектория + последовательность событий |

Ни одну из них нельзя получить из count / percent / mean duration.

### 3.4 Два вида метрик

1. **Автогенерируемые** -- декартово произведение `акт x стат`
   (freezing %time, rear count, ...). **Кода не требуют вообще**: появляются для
   любого акта автоматически. Это большинство метрик в Open Field.
2. **Именованные (bespoke)** -- то, что не сводится к одной generic-свёртке одного
   акта. Только они требуют функции в реестре с **явно объявленными зависимостями**:

```python
@register_metric("total_distance")                        # из Traces
@register_metric("discrimination_index",                  # NOR: из ДВУХ актов
                 requires_acts=["nose_novel", "nose_familiar"])
@register_metric("primary_errors", paradigm="barnes",     # из Events + геометрии
                 requires_events=["nose_at_hole"], requires_geometry=True)
```

### 3.5 Парадигмы

Парадигма -- **декларативный бандл**, а не набор `if` в коде:

| | Geometry (роли зон) | Acts | Bespoke-метрики |
|---|---|---|---|
| **OF** | center / walls / corners | speed-акты, freezing, rear, zone-акты | почти нет -- `total_distance` |
| **NOR** | object[k] + кольца подхода | `nose_at_object[k]` (семейство) | `discrimination_index` |
| **Barnes** | hole[k] + `is_target`, angle | `nose_at_hole[k]`, `mouse_inside_hole[k]` | latency, errors, angular, ordinal, strategy -- все из Events |

Barnes выбивается не по природе, а потому что он единственный, кому нужны
**последовательности событий**. Со слоем Events он встаёт в общий ряд.

### 3.6 Два довеска (утверждены)

- **Семейства актов**: акт параметризован *классом зон*, а не 19 копий руками.
  Это ровно `per-class-of-objects` конструктор из `docs/TODO.md`.
- **Атрибуты зон**: `is_target`, `index`, `angle`. Метрики читают роль зоны из
  геометрии, а не парсят имя строкой.

### 3.7 Что это даёт GUI (следующая спека)

Конструктор становится двухпанельным: слева **акты** (определить / параметризовать
семейством), справа **метрики** (галочки: какие `акт x стат` и какие именованные
метрики уходят в выходную таблицу). Выбор парадигмы пред-заполняет обе панели.

## 4. Структура пакета

```
src/sphynx/
  config.py       # Config-dataclasses + load/save
  util/           # геометрия (circle/ellipse/polygon fit, lines, mask), log, progress
  io/             # read_dlc, read_preset, save/load acts, tracks settings
  bodyparts/      # identify_parts, compute_center, relative_coords, resolve_part
  angles/         # head_direction, wrap, unwrap
  preprocess/     # clean, interpolate, smooth, velocity, kalman, hampel,
                  # autothreshold, per_part, arena_ring, detect_start
  zones/          # classify_circle, classify_square, partition_strips
  preset/         # build_zones_*, mask_from_border, pixels_per_cm,
                  # auto_detect_objects, grid_offsets, rotate
                  # (чистая геометрия; интерактивное рисование -> GUI-спека)
  acts/           # реестр, встроенные, семейства, apply, refine, eval, context
  events/         # акт -> упорядоченные эпизоды с метками
  metrics/        # act_stats (generic) + реестр именованных метрик
  paradigms/      # of.py, nor.py, barnes.py
  pipeline/       # analyze_session, run_batch, build_super_table, render, plots
  cli.py          # analyze one session / batch
tests/            # pytest-зеркало MATLAB-тестов
pyproject.toml
```

Стек: numpy / scipy / pandas, opencv-python (видео), matplotlib (плоты);
pytest + ruff; Python 3.11+. **MATLAB в рантайме не нужен.**

## 5. Модель данных

Типы даны по слоям из §3.2, чтобы модель данных и доменная модель не разъезжались.

**Слой 0 -- Traces**
- **`Session`** -- dataclass: `body_parts: list[str]`, `X, Y, likelihood: np.ndarray (PxN)`,
  `frame_rate`, `pixels_per_cm`, `width`, `height`, обработанные трассы
  (`velocity`, `angles`). Метод `part(name)` резолвит по алиасам. Заменяет
  параллельные `BPX / BPY / bodyPartsNames`. Побочный эффект: синтетический центр
  перестаёт быть спецслучаем (баг R31 #1/#3 не воспроизводится по построению).

**Слой 1 -- Geometry**
- **`Preset`** -- dataclass: `options`, `zones: list[Zone]`, `arena_and_objects`.
- **`Zone`** -- `name, type, mask, zone_class, index, is_target, angle`.
  Роль зоны читается из атрибутов, а не парсингом имени строкой.

**Слой 2 -- Acts**
- **`ActSpec`** -- декларативное определение. Может быть **шаблоном семейства**:
  поле `over_zone_class` (например `"hole"`) разворачивает спеку в конкретные акты
  по всем зонам этого класса.
- **`Act`** -- конкретный (уже развёрнутый) акт: `name, family, zone, index,
  category, params`. Для одиночных актов `family is None`.
- Результат -- `acts: dict[str, np.ndarray]` (булев ряд длины N на акт).

**Слой 3 -- Events**
- **`Event`** -- dataclass: `act: str`, `label: str | None` (элемент семейства,
  напр. `hole_7`), `index: int | None`, `start_frame`, `end_frame`, `duration_s`.
- **`EventStream`** -- упорядоченный по времени список `Event` для одного акта или
  для **слитого семейства**. Несёт запросные методы, ради которых слой и вводится:
  `first()`, `first_where(pred)`, `labels_before(event)`, `order_of(label)`,
  `unique_labels()`. Barnes-метрики выражаются через них, а не через ручной разбор
  бинарных рядов.

**Слой 4a -- ActStats** (generic, автоматом для каждого акта)
- **`ActStats`** -- dataclass: `count, percent, duration_s, mean_time, median_time,
  std_time, mad_time, distance_cm, mean_distance_cm, mean_velocity, max_velocity,
  min_velocity, first_start_s, first_end_s, last_start_s, last_end_s,
  first_duration_s, rest_duration_s`.

**Слой 4b -- Metrics**
- `metrics: dict[str, float | str]`. Тип значения не только `float`: часть метрик
  категориальные (например `search_strategy` -> `"spatial" | "serial" | "random"`).

**Слой 5 -- Output**
- **`SessionResult`** -- агрегат: `session, preset, acts, events, act_stats,
  metrics, config`; метод `to_row()` даёт строку выходной таблицы.
- Таблицы -- `pandas.DataFrame` для per-session output и super-table.

## 6. Config

`Config` -- дерево dataclass-ов (`paths / range / preprocess / acts / viz / io / verbose`).
**Дефолты живут в коде -- единый источник правды** (вместо разбросанных по MATLAB
`minDurationSec=0.25` в четырёх местах, см. TODO «4-way duplication of defaults»).
Опциональный override-файл в TOML (питонично, с комментариями); конвертируем
существующий `sphynx_defaults.jsonc`.

API: `Config.default()`, `Config.from_toml(path)`, `.to_toml(path)`.

## 7. Реестры: акты и метрики

### 7.1 Реестр актов

`@register_act("freezing")` регистрирует эвалюатор в словаре; встроенные
(speed / freezing / rear / zone / all_in_zone / complex) регистрируют себя сами.
Кастомные акты из сохранённой библиотеки -- data-driven, исполняются теми же
зарегистрированными эвалюаторами.

**Новый спец-акт = один файл + декоратор, без правки ядра** (заменяет
`switch specialKind` в `applyAct.m`).

### 7.2 Семейства актов

`ActSpec` с полем `over_zone_class` -- шаблон. Перед вычислением он
**разворачивается** в конкретные `Act` по всем зонам этого класса в текущем
пресете:

```python
ActSpec(name="nose_at_hole", over_zone_class="hole", body_part="nose", ...)
# -> Act(name="nose_at_hole[3]", family="nose_at_hole", zone="hole_3", index=3)
```

Развёрнутые акты дальше живут как обычные, а их события сливаются в один
`EventStream` семейства (метка = имя/индекс зоны). Это снимает 19 копий актов
руками в Barnes и реализует `per-class-of-objects` конструктор из `docs/TODO.md`.

### 7.3 Реестр метрик

`@register_metric(name, ...)` регистрирует функцию, **явно объявляющую
зависимости и применимость к парадигме**:

```python
@register_metric("total_distance")                        # из Traces
@register_metric("discrimination_index",                  # NOR: из ДВУХ актов
                 requires_acts=["nose_novel", "nose_familiar"])
@register_metric("primary_errors", paradigm="barnes",     # из Events + геометрии
                 requires_events=["nose_at_hole"], requires_geometry=True)
```

Объявленные зависимости дают: (1) понятный порядок вычисления, (2) внятную ошибку
«метрика X требует акт Y, которого нет в библиотеке» вместо тихого NaN,
(3) фильтрацию списка метрик под выбранную парадигму в GUI.

Метрики из §3.4-п.1 (`акт x стат`) **в реестре не регистрируются** -- они
порождаются автоматически для каждого акта.

## 8. Милстоуны (снизу вверх, по зависимостям)

| M | Содержимое |
|---|---|
| M1 | `config`, `util` (геометрия), `io` (read_dlc, read_preset) |
| M2 | `preprocess` (кроме `make_synthetic_dlc` -- вне охвата), `bodyparts`, `angles` |
| M3 | `zones` + `preset` (геометрия) |
| M4 | `acts` (реестр, встроенные, семейства) + `events` |
| M5 | `metrics` (generic + именованные) + `paradigms` (OF, NOR, Barnes) |
| M6 | `pipeline` (analyze_session, run_batch, super-table) + `cli` |
| M7 | рендер видео-оверлеев и session-плоты |

Милстоуны -- естественные границы реализации: план пишется и исполняется
по-милстоунно, а не одним монолитом на весь движок.

## 9. Тестирование

Планка -- поведенческий паритет, поэтому корректность обеспечивают независимые
тесты с известными ответами, а не сверка чисел с MATLAB.

- **pytest + TDD как в R31**: сначала падающий тест, потом минимальный фикс.
- 73 MATLAB-теста -- источник контрактов; портируем их смысл.
- Три уровня:
  - **unit** -- чистые функции, известные ответы;
  - **synthetic** -- сконструированные трассы с известной истиной (мышь прошла
    ровно X см, пересекла зону ровно N раз, замерла на ровно K кадров);
  - **integration** -- Demo `NOF_H01_1D` end-to-end.
- **Snapshot-регрессия внутри Python**: как только модуль доверенный, фиксируем его
  выход на Demo-данных. Это golden-guard, которого на MATLAB так и не завели
  (см. открытый пункт в `docs/TODO.md`); здесь он появляется сразу.

## 10. Обработка ошибок

Главная тема аудита R31 -- **тихие неверные ответы** (подстановка `pxlPerCm=1`,
`bcIdx=1`, обнуление акта при неразрешённой части тела).

Политика Python-версии:
- иерархия исключений `SphynxError`;
- **никаких молчаливых правдоподобных подстановок** -- либо явное исключение,
  либо явный `warning` + честный `NaN`, пробрасываемый дальше;
- логирование через stdlib `logging`.

**8 фиксов R31 переносим как поведение, а не как код** -- baseline корректности,
ниже которого опускаться нельзя. См. `docs/audit-r2025-engine-bugs.md`.

## 11. Вне охвата

- Qt-GUI (отдельная спека следом)
- **пользовательский генератор синтетических DLC-данных** (`makeSyntheticDLC` +
  вкладка Synthetic Data)
- стат-тесты / вкладка Plot (`+stats`: runTest, RM-ANOVA, detectFactors, pStars)
- видео-препроцесс (перекодирование / FPS-фикс)

Всё перечисленное остаётся доступным в MATLAB-ветке `sphynx-GUI-R2025`.

**Важное уточнение к §9.** Исключён именно *пользовательский* генератор как фича.
Небольшие **тестовые фикстуры**, конструирующие трассы с известной истиной (аналог
`+sphynx/+testing/makeWalkingDLC` и т.п.), в охвате -- без них невозможен
synthetic-уровень тестов. Живут в `tests/fixtures/`, не в публичном API пакета.

## 12. Критерии готовности

1. `analyze_session` проходит Demo `NOF_H01_1D` end-to-end и выдаёт per-session
   таблицу актов со статистикой.
2. `run_batch` + `build_super_table` собирают мульти-сессионную таблицу.
3. Все три парадигмы (OF, NOR, Barnes) заданы декларативно; Barnes-метрики
   считаются из слоя Events.
4. Тесты зелёные на всех трёх уровнях; snapshot-регрессия зафиксирована.
5. Ни одного молчаливого фолбэка в коде (проверяется ревью + тестами).

# S4f — Project tab Implementation Plan

**Goal:** Сделать проект первоклассной сущностью: папка с фиксированной раскладкой,
относительные пути внутри неё, единственный источник парадигмы, библиотеки и папок, и
своя вкладка первой в окне.

**Architecture:** Движок получает новый модуль путей (`sphynx/project/paths.py`) и
расширенную модель со схемой v2. GUI получает вкладку Project; `AppState` перестаёт
дублировать настройки проекта и проксирует их. Остальные вкладки берут стартовые папки из
проекта, продолжая работать без него.

**Tech Stack:** Python 3.14, PySide6, pytest / pytest-qt (headless, `QT_QPA_PLATFORM=offscreen`).

**Spec:** `docs/superpowers/specs/2026-08-02-S4f-project-tab-design.md`

**Исполнение:** в основном цикле, TDD, коммит на задачу. Полная сюита после каждой задачи.

## Global Constraints

- §10 проекта: никаких тихих подстановок. Невычислимое — ошибка `SphynxError`-семейства
  или видимое состояние строки, не молчаливый дефолт.
- Движок (`src/sphynx`) не импортирует Qt. Это проверяется отдельным subprocess-тестом.
- Подпапки: ровно `raw_videos`, `tracking`, `presets`, `behavior`, `temp`.
- Путь под корнем хранится относительным, вне корня — абсолютным. Признак «внешний» —
  сам путь (`isabs`), отдельного флага нет.
- Настоящие symlink не создаются (Windows: нужны админ/Developer Mode).
- `temp/` не читается ни Batch, ни Make Output и не чистится автоматически.
- Схема `project.json` версии 2; версия 1 читается, повышается в памяти, на диск сама не
  пишется — проект помечается несохранённым.
- Команда тестов: `QT_QPA_PLATFORM=offscreen PYTHONPATH=src python -m pytest -q`.

---

### Task 1: Пути проекта и раскладка папок

**Files:**
- Create: `src/sphynx/project/paths.py`
- Test: `tests/unit/test_project_paths.py`

**Interfaces (Produces):**

```python
LAYOUT = ("raw_videos", "tracking", "presets", "behavior", "temp")

def store_path(path, root) -> str          # относительный под корнем, иначе абсолютный
def resolve_path(stored, root) -> str      # всегда абсолютный
def is_external(stored) -> bool            # == os.path.isabs(stored)
def create_layout(root) -> dict            # {имя: "created"|"existed"}; идемпотентно
def import_file(source, root, subdir, copy: bool) -> str
    # copy=True  -> shutil.copy2 в <root>/<subdir>/, вернуть относительный путь
    # copy=False -> вернуть store_path(source, root) без копирования
    # отсутствующий source -> SphynxIOError
    # копирование поверх существующего файла с другим содержимым -> SphynxIOError
```

**Тесты:**
1. `store_path` под корнем даёт относительный путь без `..`; вне корня — абсолютный.
2. Круговой проход: `resolve_path(store_path(p, root), root)` == `p` для обоих случаев.
3. `is_external` совпадает с тем, что вернул `store_path`.
4. `create_layout` создаёт пять папок и помечает их `created`; повторный вызов — `existed`,
   ничего не удаляя.
5. `create_layout` на пути, где лежит файл с таким именем — `SphynxIOError` с именем.
6. `import_file(copy=True)` кладёт файл в нужную подпапку, возвращает относительный путь,
   исходник остаётся на месте.
7. `import_file(copy=False)` ничего не копирует и возвращает абсолютный путь для внешнего
   источника.
8. `import_file` с несуществующим источником — `SphynxIOError`.
9. `import_file(copy=True)`, когда в подпапке уже есть файл того же имени с **другим**
   содержимым — `SphynxIOError`, а не тихая перезапись чужих данных.
10. `import_file(copy=True)` на файл, уже лежащий внутри проекта — не копирует сам в себя,
    возвращает его относительный путь.

**Commit:** `feat(python): S4f -- project paths and folder layout`

---

### Task 2: Модель и схема v2

**Files:**
- Modify: `src/sphynx/project/model.py`, `src/sphynx/project/io.py`
- Test: `tests/unit/test_project_io.py` (дополнить), новый `tests/unit/test_project_schema_v2.py`

**Interfaces (Produces):**

```python
@dataclass
class Project:
    ...                       # существующие поля сохраняются
    root: str = ""
    raw_videos_dir: str = ""  # пусто == <root>/raw_videos
    tracking_dir: str = ""
    presets_dir: str = ""
    behavior_dir: str = ""
    temp_dir: str = ""
    preprocess_path: str = ""

@dataclass
class ProjectSession:
    ...
    video_path: str = ""

def folder(project, which: str) -> str    # абсолютный путь подпапки, с учётом переопределения
SCHEMA_VERSION = 2

@dataclass
class LoadedProject:
    project: Project
    upgraded_from: int | None   # 1, если файл был версии 1

def load_project(path) -> Project          # прежняя сигнатура сохраняется
def load_project_detailed(path) -> LoadedProject
```

`root` при чтении **всегда** берётся из расположения файла, а не из поля: переехавший
проект должен открываться. Поле `root` пишется для справки.

**Тесты:**
1. v2 круговой проход: сохранить и прочитать — все новые поля на месте.
2. `root` после чтения равен папке файла, даже если в поле записано другое.
3. Файл версии 1 читается; `upgraded_from == 1`; существующие абсолютные пути остаются
   абсолютными (то есть внешними).
4. Файл версии 1 не переписывается при чтении (mtime и содержимое не изменились).
5. Версия 3 — ошибка с названными версиями.
6. Неизвестное верхнеуровневое поле — ошибка (поведение S4c сохраняется).
7. `folder(project, "temp")` без переопределения — `<root>/temp`; с переопределением —
   заданный путь.
8. `folder` на неизвестное имя — `SphynxValueError` со списком известных.

**Commit:** `feat(python): S4f -- project schema v2, folders and video paths`

---

### Task 3: AppState — проект как источник истины

**Files:**
- Modify: `src/sphynx_gui/state.py`
- Test: `tests/gui/test_state.py` (дополнить)

**Interfaces (Produces):**

```python
class AppState(QObject):
    project_dirty_changed = Signal()

    # paradigm, out_dir, library_path теперь проксируют в self._project
    # dlc_path и preset_path остаются собственными: это выбор текущей сессии
    @property
    def project_dirty(self) -> bool
    def mark_project_dirty(self) -> None
    def clear_project_dirty(self) -> None
    def project_folder(self, which: str) -> str   # "" без проекта
```

**Тесты:**
1. Правка `state.paradigm` меняет `state.project.paradigm`.
2. Правка `state.paradigm` помечает проект несохранённым и шлёт сигнал.
3. Присвоение нового `Project` сбрасывает признак несохранённости.
4. Присвоение того же значения не помечает несохранённым и не шлёт сигнал.
5. `project_folder("temp")` без корня — пустая строка, не исключение: без проекта вкладки
   работают как раньше.
6. `dlc_path` и `preset_path` проект не трогают.

**Commit:** `feat(gui): S4f -- the project owns the paradigm, library and folders`

---

### Task 4: Вкладка Project

**Files:**
- Create: `src/sphynx_gui/project_tab.py`, `src/sphynx_gui/project_controller.py`
- Test: `tests/gui/test_project_tab.py`

**Interfaces (Produces):**

`ProjectTab(state)` с полями `name_box`, `root_label`, `new_button`, `open_button`,
`save_button`, `save_as_button`, `folders_table`, `paradigm_box`, `library_box`,
`library_new_button`, `add_video_button`, `add_tracking_button`, `warnings`,
`status_label`, `dirty_label`, `controller`.

`ProjectController(state, tab)`: `new_project(root)`, `open_project(path)`, `save()`,
`save_as(path)`, `set_paradigm(name)`, `set_library(path)`, `add_files(paths, kind, copy)`,
`refresh()`, `report()`.

`open_project` принимает и папку, и `project.json`.

**Тесты:**
1. `new_project` создаёт пять подпапок и `project.json`.
2. `new_project` в непустой папке, где уже есть `project.json` — отказ с текстом, а не
   перезапись.
3. `open_project` на папку находит `project.json` внутри.
4. `open_project` на папку без `project.json` — сообщение, состояние не меняется.
5. Открытие файла версии 1 помечает проект несохранённым и говорит об этом.
6. `add_files(copy=True)` кладёт файл в `tracking/` и добавляет сессию с относительным путём.
7. `add_files(copy=False)` оставляет файл на месте, сессия помечена внешней.
8. Таблица папок показывает пять строк и состояние каждой.
9. Смена парадигмы во вкладке помечает проект несохранённым.
10. `save` снимает признак несохранённости; `save` без корня — сообщение.
11. Панель варнингов показывает число сессий с неразрешимыми путями и число внешних.

**Commit:** `feat(gui): S4f -- Project tab`

---

### Task 5: Порядок вкладок и потребление проекта остальными

**Files:**
- Modify: `src/sphynx_gui/main_window.py`, `src/sphynx_gui/preset_tab.py`,
  `src/sphynx_gui/analyze_tab.py`, `src/sphynx_gui/batch_tab.py`,
  `src/sphynx_gui/output_tab.py`
- Test: `tests/gui/test_main_window.py` (дополнить), точечные дополнения в тестах вкладок

**Что делается:**
- Порядок вкладок: Project, Create Preset, Preprocess, Define Acts, Analyze Session,
  Batch Analysis, Make Output.
- Диалоги стартуют в папке проекта: Create Preset — видео из `raw_videos/`, сохранение
  пресета в `presets/`; Analyze — DLC из `tracking/`, пресет из `presets/`, запись в
  `temp/`; Batch — запись в `behavior/`; Make Output — в корень.
- Из Batch убираются кнопки New/Open/Save project.
- Без проекта поведение прежнее: стартовая папка пустая.

**Тесты:**
1. Порядок вкладок в окне ровно такой, как в спеке.
2. `Preprocess Tracking` — единственная заглушка.
3. С открытым проектом стартовая папка диалога видео равна `raw_videos/`.
4. С открытым проектом одиночный прогон Analyze пишет в `temp/`, а не в `behavior/`.
5. Без проекта стартовая папка пустая и ничего не падает.
6. В Batch нет кнопок работы с проектом.

**Commit:** `feat(gui): S4f -- Project first, tabs read the project's folders`

---

### Task 6: Интеграционный тест полного круга

**Files:**
- Create: `tests/integration/test_project_round_trip.py`

**Что проверяется** (скипается, если демо-данных нет):
1. Создать проект во временной папке.
2. Импортировать демо-DLC в `tracking/` копированием и демо-пресет в `presets/`.
3. Просканировать, назначить пресет правилом, прогнать пачку — результаты в `behavior/`.
4. Одиночный прогон той же сессии из Analyze — файлы в `temp/`, в `behavior/` ничего
   нового не появилось.
5. Сохранить проект, перечитать — все пути внутри относительные, ни одного внешнего.
6. Переименовать папку проекта целиком и открыть снова — проект открывается, пути
   разрешаются.

**Commit:** `test(python): S4f -- a project round-trips, moves and re-opens`

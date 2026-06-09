# Pass 2 manual verification (11 features S1-S11)

Все 11 фич на ветке `sphynx-GUI`, HEAD = round 11 (auto session-start detection).
239/239 fast тестов зелёные.

## iteration 11 (2026-06-09) — auto session-start detection

Анализ может теперь сам понимать, с какого кадра начинать. Логика:

- Считает per-frame «заполненность» = доля bodyparts с непустыми
  (не NaN, не отрицательными) x и y.
- Скользящее окно вперёд (30 кадров ~ 1 с при 30 fps).
- Первый кадр, где среднее окна >= 0.5 — точка старта.
- Snap'ает к следующему реально заполненному кадру (не падает на
  NaN-дыру).
- Если животное с первого кадра — возвращает 1.
- Если ни разу не появилось — fallback 1 + сообщение в логе.

### Где живёт
- `+sphynx/+preprocess/detectSessionStartFrame.m` — pure helper.
- `+sphynx/+pipeline/defaultConfig.m` — новый флаг
  `cfg.range.autoStart = true` (default ON).
- `+sphynx/+pipeline/analyzeSession.m` — при `autoStart && startFrame==1`
  пред-читает DLC, гоняет детектор, записывает результат обратно в
  `config.range.startFrame`, перечитывает с правильного смещения.

### Что увидишь в логах при анализе/batch
```
[Auto-start: detected session start at frame 44 (firstPop=14, populatedRatio=0.88)]
```
или (если животное в кадре с самого начала):
```
[Auto-start: keeping startFrame=1 (animal populated from frame 1)]
```

### Проверено на твоём файле
`Demo/BARNES/3_DLC/..._snapshot.csv` → детектор вернул кадр **44**
(первый populated frame 14 — короткий transient, стабильное
обнаружение с 44).

### Как выключить
Если хочешь выключить (например, запустить с manual `startFrame`),
выстави `cfg.range.autoStart = false` в config'е перед вызовом
`sphynx.pipeline.analyzeSession`. Или просто задай `startFrame > 1`
— manual override всегда побеждает (auto работает только когда
startFrame == 1).

### Что проверить
1. В Batch Analysis запусти batch с твоим BARNES preset + DLC. В логе
   должен быть `[Auto-start: detected ... frame 44 ...]`.
2. Открой результирующий `_Result.mat`. `config.range.startFrame`
   должен быть = 44 (не 1).
3. Видео-overlay уже учитывает `startFrame - 1` как frameOffset
   (legacy код в Define Acts / Batch / Analyze Tab) — синхронизация
   с видео должна остаться корректной.

## iteration 10 (2026-06-09) — circle strategy + multianimal DLC

## iteration 10 (2026-06-09) — circle strategy + multianimal DLC

### 1) Новый Strategy 'circle' (Barnes default)
В Block 5 добавлен **circle** — два zona: `wall` (кольцо у стены)
и `center` (всё остальное внутри арены).

Новые дефолты:
- Strategy = **circle**
- Wall = **15 cm**
- Obj zone = **3 cm**

Помещён в dropdown перед `circle-rings`. Использует bwdist на маске —
работает на эллипсе/круге/полигоне.

### 2) Multianimal DLC support (auto-pick most populated)
`sphynx.io.readDLC` теперь поддерживает оба формата:
- **single-animal** (3 header rows) — как было.
- **multi-animal** (4 header rows с `individuals` строкой) — авто.

Логика multianimal pick:
1. Парсит individuals + bodyparts + coords строки.
2. Кандидаты — индивиды с >1 bodypart (исключает `single` — обычно
   1 маркер вроде miniscope LED).
3. Для каждого кандидата считает заполнённые пары (x,y) — где
   "заполнено" = не NaN И не отрицательно (DLC superanimal пишет
   `-1.0` как sentinel для "no detection").
4. Берёт самого заполнённого. Лог:
   `[readDLC] multi-animal: N individuals found {...}; selected "X" (P body parts)`.
5. Сохраняет в `out.individuals` (все) и `out.selectedIndividual`.
6. Доп: можно форсить через `'Individual', 'animal3'`.

Бонус: значения `< 0` в X/Y/likelihood конвертятся в NaN на выходе
(и для single-animal тоже) — Hampel/sgolay теперь корректно их
пропускают.

### Что проверено на твоих файлах
- `Demo/DLC/Stfp 1 D5 T2 1-14-1...el.csv`:
  individuals = {observer, demonstrator, single}. Selected
  **observer** (11 bodyparts). `single` (1 bp = miniscope)
  правильно отброшен.
- `Demo/BARNES/3_DLC/2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv`:
  10 animals (animal0..animal9), 27 bodyparts каждый. Selected
  **animal0** (88.1% populated, остальные 0-1%).

### Что проверить руками
1. Clear classes / restart MATLAB (после edit `+sphynx/+app/.m`).
2. Block 5 свежий: Strategy=circle, Wall=15, ObjZone=3.
3. Загрузи `..._snapshot.csv` в Preprocess Tracking tab. В логе
   должно быть `[readDLC] multi-animal: 10 individuals found ...;
   selected "animal0"`. Графики X/Y/likelihood должны рисоваться.
4. Hampel + sgolay должны работать без NaN-крашей.

## iteration 9 (2026-06-09) — Block 5 defaults + класс-кеш guidance

## iteration 9 (2026-06-09) — Block 5 defaults + класс-кеш guidance

**ВАЖНО — про ошибки `Unable to find function @(~,~)app.previewZones()`:**
Это **не баг кода**, а stale classdef в interactive MATLAB. После любого
edit'а .m в `+sphynx/+app/CreatePresetApp.m` MATLAB продолжает использовать
**предыдущую** версию класса (методы кешируются на сессию).

**Лечение:**
```matlab
clear classes
close all force
startup
sphynx.app.CreatePresetApp
```

Либо просто перезапусти MATLAB (но это дольше). Я добавил это в memory
project_matlab_function_cache.md.

В batch (`matlab -batch`) всё работает чисто потому что каждый запуск
стартует с чистого листа.

### Block 5 defaults (Barnes)
- Strategy = **circle-with-center**
- Wall = **12 cm**
- Center diameter = **20 cm** (уже было)
- Object zone = **3 cm** (было 2.5)

Эта схема для эллипса 92 cm:
- wall ring толщиной 12 cm у стены
- center диск 20 cm в середине
- middle — всё остальное между ними
- + per-hole object zones 3 cm вокруг каждой лунки.

### Что проверить после `clear classes` + рестарт
1. Block 5 при свежем запуске: должны стоять **circle-with-center / 12 /
   20 / 3** по умолчанию.
2. Создай savedObjects (через manager → Finish), нажми **Preview** —
   должны нарисоваться: wall (синий ring) + middle + center (диск) +
   маленькие кружки `object1_realout`..`objectN_realout`.
3. Нажми **Add to set**. Должно прибавиться ~6-12 зон в зависимости от
   количества лунок.
4. Поменяй Strategy на **circle-rings** (Wall 12, Middle 24). Preview
   покажет новую схему + те же object zones. Add — добавит ещё.
5. Если хочешь чисто перестроить — **Clear zones** сначала, потом
   Preview + Add.

   Замечание: дедуп по startsWith('object') / endsWith('_center')
   мешает повторно добавить object zones с новой шириной. Если поменял
   ObjectZone width — Clear zones, затем Preview + Add.

## iteration 8 (2026-06-09) — 4 fixes (labels, selection, main listbox, lowercase)

1. **Order Barnes теперь видно на картинке.** Метки на manager preview
   были числовые (1,2,3...) — оставались стабильны при reorder.
   Теперь рисую `o.type` — после Order Barnes: `target`, `object1`,
   `object2`, ... `objectN-1` на каждом круге.

2. **Selection sync в manager preview.** `setSelectedObjectIdx`
   обновлял главное окно + listbox, но НЕ перерисовывал manager axes.
   Теперь добавил `refreshManagerPreview` в конец — жёлтое выделение
   тапнутого объекта следует за листбоксом.

3. **Main mirror listbox интерактивный.** В Block 4 listbox был
   `Enable='off'`. Сейчас multiselect, callback пишет в
   `app.State.selectedSavedIdx`, `refreshPreview` рисует жёлтую обводку
   + name label у каждого выделенного saved-объекта на main картинке.
   Selection переживает Finish (refreshObjectsList восстанавливает
   Value после Items update).

4. **Lowercase везде**.
   - Объекты: `Object1..N` → `object1..N` (target всегда был мелким).
   - Зоны от объектов (buildObjectZones):
     `Object1Real` → `object1_real`, `Object1RealOut` → `object1_realout`,
     `Object1Out` → `object1_out`. Plus combined `objectall_real/realout/out`.
     Подчёркивание-разделитель — иначе `object1realout` нечитабельно.
   - `ArenaCorner1` → `arenacorner1`, `Object1Center` → `object1_center`.
   - `analyzeSession` defaultBehaviorZoneSpec обновлён под новые имена.
   - Хелперы детекции (`startsWith/endsWith`) обновлены под новые
     префиксы/суффиксы.

   **Совместимость**: старые preset'ы со старыми (заглавными) именами
   зон не будут матчиться по новой spec в `analyzeSession`. Re-save
   preset один раз — и всё.

Что проверить:
- Order Barnes: на картинке должны появиться `target`,
  `object1`..`objectN-1` в правильных позициях.
- Прощёлкивание объектов в listbox менеджера: жёлтое выделение
  должно прыгать на manager preview.
- В main: в Block 4 listbox теперь кликается. Тапни любой — на main
  картинке должна появиться жёлтая обводка + name label.
- Save preset → перепрочитай `.mat` — все имена зон должны быть
  lowercase (object1_realout, arenacorner1, и т.д.).

## iteration 7 (2026-06-09) — 4 fixes (focus, mix order, INFO, defaults)

1. **Manager focus flicker** — больше не «сворачивается-разворачивается».
   - `refreshPreview` теперь короткозамыкает если manager открыт (main вообще не
     перерисовывается во время сессии менеджера — точно как ты предложил).
   - `refocus()` / `status()` не дёргают `figure(MainFigure)` пока manager жив.
   - Старый `focusManagerIfOpen` (visibility off→on cycle) превращён в no-op:
     теперь нет вспышек — никто не пытается «вернуть фокус» обратно.
   - На Finish: одно обновление main, всё гладко.

2. **Manual после auto-detect commit** — багфикс.
   - Корень: `autoDetectObjects` возвращал 6-field struct (нет
     `border_separate_x/y`), а `readArenaGeometry` 8-field. После commit
     auto-detected `State.objects` становился 6-field, и следующий
     `+ Add shape` падал при попытке `objects(end+1) = obj` из-за
     несовпадения полей.
   - Добавлен `canonicalizeObjects` helper — приводит любой struct array
     к каноническому виду (8 fields, missing border_separate_x/y = `{}`).
   - Применён в `commitAutoDetected`, `commitPendingShapes`, `addObject`.
   - **Mix работает в любом порядке**: manual → auto → manual → auto.
   - Двойной клик для polygon: да, обязателен (стандарт MATLAB drawpolygon).
     Для circle/ellipse тоже double-click. Подсказка в статус-баре уже была.

3. **Double-click hint в калибровке + ревизия всех INFO**.
   - Choose tooltip: «1 line / 2 lines: double-click to confirm».
   - `helpCalibrationText` переписан — каждый режим расписан, плюс
     «Для BARNES: 1 line по умолчанию, 92 cm».
   - `helpArenaText` переписан — `shape` vs `points`, упоминание «Для BARNES:
     Ellipse + points».
   - `helpObjectsText` переписан под Objects Manager (Manager 3-column,
     draft-режим, Finish, mix manual+auto).
   - `helpZonesText` — `none` упомянут как Barnes default; `Clear all` →
     `Clear zones` (актуальное название).
   - `helpSaveText` — убрана отсутствующая кнопка «Make plot», добавлено
     описание auto-finish при сохранении.

4. **Barnes defaults**:
   - **Блок 2 calibration**: cm Y = 92, cm X = 92, mode = **1 line**
     (cm X dimmed). При смене на 4 points/2 lines cm X включается.
   - **Блок 3 arena**: geometry = **Ellipse**, pick mode = **points**.
   - **Блок 4 objects**: manual geometry = **Circle**, pick mode = **shape**,
     auto Mode = **all-circles** (Algorithm dropdown активен, можно
     прощёлкивать threshold/hough).
   - **Блок 5 zones**: Strategy = **none**. Никакой разметки арены —
     только object-зоны (если нужны) поверх лунок.

Что проверить:
- Открой manager, добавь пару ручных объектов (+ Add shape, рисуй
  круг, двойной-клик), Commit pending. Затем Auto-detect → Commit.
  Затем снова + Add shape — должно работать, не падать.
- Manager не должен «мерцать» в основное окно при операциях.
- Defaults: всё совпадает с настройкой выше при свежем запуске.
- INFO buttons (5 штук): Calibration / Arena / Objects (в menager
  правый INFO там же) / Zones / Save — все актуальные.

## iteration 6 (2026-06-04) — draft model + 6 fixes

Commit `748144f`. Главное — **draft-режим**: manager работает на копии,
main показывает только committed.

1. **Neighborhood default 5** (было 10).

2. **INFO кнопка в самый низ** auto-detect панели (row 10, full width).
   Не ломает остальной layout.

3. **Conditional Enable** в auto-detect:
   - Mode `all-circles` → Algorithm dropdown active.
   - Mode иное (free-form / polygons / ellipses) → Algorithm disabled (forced threshold).
   - Algorithm `threshold` → Neighborhood **enabled**, Radius range **disabled**.
   - Algorithm `hough` → Neighborhood **disabled**, Radius range **enabled**.

4. **Sensitivity показывает значение** справа от ползунка (`0.75` обновляется на drag). **Default 0.75** (было 0.5).

5. **DRAFT model** — самое крупное:
   - `app.State.objects` — рабочая копия в manager'е.
   - `app.State.savedObjects` — закоммиченное состояние (показывается в main).
   - При открытии manager'а: snapshot `objects = savedObjects` (продолжаем с того, что в main).
   - **Все операции в manager** (Add shape commit, auto-detect commit, copy×N, delete, rename, class, order, align radii, ...) **меняют ТОЛЬКО `objects`** — в main ничего не меняется.
   - Main mirror listbox / main preview показывают только `savedObjects`.
   - `Finish` кнопка (см. fix 6) копирует `objects → savedObjects`, main обновляется, manager закрывается.
   - `savePreset` автоматически делает Finish если есть незакоммиченный draft.

   Так что **в main окне ничего не отрисовывается пока не нажат Finish** — точно как ты просил.

6. **Finish кнопка** под preview-картинкой в menager'е, ярко-зелёная, на всю ширину.
   - "Finish (commit all to preset)".
   - Один клик — все работы (manual pending + auto-detect commit + любые edit'ы) уходят в preset.
   - Manager закрывается, main обновляется.

7. **Mix manual + auto** — естественно работает. Можешь нарисовать вручную несколько,
   запустить auto-detect, commit auto-detected, поправить align radii, добавить ещё
   вручную, Order by Barnes — всё в драфте `objects`. Один Finish коммитит всё.

---

## iteration 5 (2026-06-04) — 6 manager refinements

Commit `c422f37`.

1. **Дефолты автодетекта**: Min area 1 cm², **Max area 100** (было 500),
   **Radius 2..7 cm** (было 1..5). Подобрано под Barnes лунки.

2. **Кнопка `Align radii`** в auto-detect (3-я кнопка справа в row 9):
   - После Auto-detect жми Align radii.
   - Считает средний радиус всех detected объектов.
   - Открывает inputdlg pre-filled средним — можешь поправить вручную.
   - Применяет к ВСЕМ detected кругам (с тем же центром, новым
     радиусом). Объекты остаются в preview (зелёным пунктиром).
   - После этого можно Commit чтобы зафиксировать.

3. **Uniform radius чекбокс/поле удалены** — заменены кнопкой Align radii.

4. **Neighborhood перенесено** под Sensitivity slider (row 4). Раньше
   было row 6, скрытно. Теперь сразу видно.

5. **INFO кнопка** в auto-detect panel (row 1 col 3, синяя). Открывает
   help-диалог со всеми режимами, алгоритмами, параметрами и Barnes-
   рекомендацией.

6. **Focus retention** — теперь visibility cycle (`Visible='off'/'on'` +
   `figure(uifig)`). На R2020a это рекомендуемый workaround для uifigure
   focus, но **на каждой операции окно будет мигать** один раз. Если
   бесит — скажу, переведу на no-op (тогда фокус может скакать, но без
   мигания). Или переезд на MATLAB 2025b решит саму проблему фокуса
   (см. чат — там я расписал плюсы/минусы переезда).

---

## iteration 4 (2026-06-04) — 7 manager fixes

Commit `384ab21`.

1. **Тоньше ROI линии** (LineWidth=1) при рисовании в manager. Мелкие
   объекты теперь нормально выделять.

2. **Order by Barnes**: target → `'target'`, остальные → `'Object1'..'Object(N-1)'`
   в CW порядке от target.

3. **Focus в manager**: после всех операций (Commit, Order, Delete,
   Auto-detect и т.д.) фокус возвращается в окно menager'а через
   новый метод `focusManagerIfOpen`. На uifigure это не 100% reliable
   на всех платформах MATLAB — fallback на `WindowStyle='normal'` +
   `drawnow`. Если иногда фокус всё же скакнёт — это известная
   ограничения uifigure'ов в R2020a.

4. **Refresh после delete**: `refreshManagerPreview` теперь вызывается
   из `removeSelectedObject`, `replaceSelectedObject`, `deleteAllObjects`,
   `assignClassToSelected`, `renameSelectedObject`, `copyObjectsN`,
   `runAutoDetect`, `commitAutoDetected`. Удалённые объекты пропадают
   с preview сразу.

5. **Threshold действительно local** (`adaptthresh` from Image Processing).
   Добавил параметр **Neighborhood, cm** (default 10) — управляет
   размером окна локального threshold. Меньше = более локально
   (хорошо для неравномерного освещения). 0 = автоматически (default
   MATLAB).

6. **Uniform radius + параметры в cm**:
   - Чекбокс **Uniform radius (all-circles)**. Если включён, все
     детектируемые круги получают один и тот же радиус (из поля
     **Uniform radius, cm**). Центр приходит из детектора.
   - **Radius range** теперь в **cm** (default 1..5 cm), не в px.
     Внутри переводится в px через pxlPerCm. Калибровка обязательна.
   - Новый тест `testUniformRadiusMode` подтверждает все круги имеют
     один радиус.

7. **Mirror listbox в Block 4**: главная вкладка Preset, блок Objects
   теперь показывает живой read-only listbox объектов (помимо label
   `N object(s)` и кнопки `Manage objects...`). Синхронизируется
   автоматически с `app.State.objects` через `refreshObjectsList`.

   Примечание про "утверждение" из твоей формулировки: сейчас manager
   мутирует `app.State.objects` напрямую (без draft state). Если
   нужно настоящее draft-separation (manager работает над копией,
   "Apply changes" коммитит в main) — это +1 итерация. Скажи если
   хочешь.

---

## iteration 3 (2026-06-04) — Objects Manager rework

Commit `e3e454b`. Manager переделан полностью.

**Layout 3 колонки (1400×750):**
- **Слева** (260 px): listbox + listbox-related кнопки (Remove, Replace, Rename, Delete all, Class+Assign, Copy×N, **Order by Barnes**).
- **По центру** (1x flex, самая широкая): preview-frame из главного окна + arena (orange) + existing objects (blue filled + numbered) + pending shapes (green dashed). Сверху toolbar: geometry toggles + pick mode + кнопки **`+ Add shape`**, **`Commit pending`**, **`Cancel pending`**.
- **Справа** (300 px, уже): Auto-detect controls.

**Multi-pick flow:**
1. Выбери геометрию (Polygon/Circle/Ellipse).
2. Жми `+ Add shape` → откроется ROI прямо на центральном preview, нарисуй фигуру (double-click чтобы зафиксировать).
3. Фигура остаётся на превью зелёной обводкой как **draggable** handle.
4. Повторяй `+ Add shape` сколько нужно — все pending фигуры накапливаются.
5. До коммита можешь дёргать любую мышкой за края.
6. Один раз нажми **Commit pending** → все pending становятся реальными объектами (Object1..N с masks).
7. **Cancel pending** — отменить все pending без сохранения.

**Auto-detect — live slider:**
- Sensitivity слайдер теперь интерактивный (`ValueChangingFcn`). Двигаешь — detect перезапускается, зелёные пунктиры на preview обновляются. Подбирать порог проще.
- На медленной машине может слегка тормозить — если бесит, скажу как перевести на ValueChangedFcn (срабатывает только при отпускании ползунка).

**Auto-detect — arena clipping safety:**
- Раньше при определённых параметрах в результаты попадал большой объект, похожий на арену. Фикс: арена-маска эродируется на `max(3, pxlPerCm)` px (чтобы детектированные объекты не касались границы), плюс жёсткий cap `area < 50% × arena_area`. Большие "арена-shaped" blob'ы отбрасываются.
- Новый тест: `testNoArenaBoundaryComponent` проверяет что синтетический ring у границы не классифицируется как объект.

**Order by Barnes:**
1. В listbox выбери ровно 1 объект (целевая лунка = Object1 после переупорядочивания).
2. Кнопка `Order by Barnes`.
3. Алгоритм:
   - Центр арены = `mean(border_x), mean(border_y)`.
   - Угол каждого объекта = `atan2(obj_cy - arena_cy, obj_cx - arena_cx)`.
   - В image space (y вниз) рост atan2 = визуально по часовой стрелке.
   - Target получает `Object1`, далее по CW нумеруются Object2..N.
4. Listbox обновляется, target становится selected.

**Hough — что это и нужно ли:**
- Hough Circle Transform — алгоритм для детекции кругов. Каждая edge-точка голосует за все окружности, на которых может лежать (cx, cy, r). Локальные максимумы accumulator'а = найденные круги.
- Параметры `imfindcircles`: `Sensitivity` (выше → больше детекций), `Method` (PhaseCode default), радиальный диапазон в pixels.
- **Для Barnes** Hough теоретически идеален (лунки круглые, контраст обычно хороший). Попробуй сначала его — задай radius range узким, например `[8 20]` px (зависит от твоего кадра). Если ловит лишнее или пропускает — задай уже range.
- Threshold лучше для произвольных форм или фрагментированных объектов.

--- Ниже smoke-протокол по фичам — прокликай порядком,
кидай вывод в конец файла под `## iteration N` если что-то не так.

## iteration 2 (2026-06-04) — 3 UX requests round 2

Commit `f12b59e`:

1. **Calibrate 1-line математика исправлена.** Раньше я паковал endpoint'ы
   как одновременно Y-pair (vertical projection) и X-pair (horizontal
   projection), и cm value использовался для обеих проекций — что
   математически неверно для любой не-axis-aligned линии (для 45° линии
   10 см: projection 7.07 cм, не 10).

   Теперь в режиме `1 line` Compute считает напрямую:
   - `lengthPx = sqrt(dx² + dy²)` (пиксельная длина)
   - `pxlPerCm = lengthPx / totalCm` (uniform scaling, X=Y, kcorr=1)
   - Status показывает: legs `[dx, dy]` в pixels и cm, плюс total
     `lengthPx / totalCm` — для проверки глазами.

   Workflow прежний: выбери `1 line` -> Choose (drawline) -> введи cm в
   поле `cm Y` (cm X disabled) -> Compute.

2. **Barnes добавлен в Exp dropdown** первым пунктом, default value
   `Barnes`. Остальные experiment'ы остаются ниже.

3. **Блок 4 (Objects) полностью переделан.** Теперь:
   - В главной левой колонке `4. Objects` показывает только:
     - Лейбл `N object(s) — click Manage to add/edit`
     - Большая кнопка `Manage objects...`
   - Кнопка открывает отдельное окно **Objects Manager** (1100×700).
   - В окне-менеджере:
     - **Слева панель `Objects`**: geometry toggles (Polygon/Circle/Ellipse),
       pick mode, Add, listbox (теперь во весь рост ~12+ entries),
       Remove/Replace/Rename/Delete all, Class+Assign, Copy×N.
     - **Справа панель `Auto-detect`** (380 px): всё из старой
       auto-detect панели — Mode/Algorithm/Sensitivity/Min/Max area/
       Radius range/Start numbering + кнопки **Auto-detect** и **Commit**.
   - Окно можно закрыть крестиком; state объектов и автодетектированных
     сохраняется. Повторное открытие восстанавливает listbox из state.
   - Block 5 (Zones) сместился на одну строку вверх в LeftGrid
     (раньше было 7 рядов с auto-detect внизу, теперь 6).

Перезапусти MATLAB → `startup` → `sphynx.app.CreatePresetApp` для теста.

---

## iteration 1 (2026-06-04) — 6 UX фиксов из твоего смока

Твой репорт привёл к следующим правкам в `88ae206`:

1. **Calibrate 1 line** — теперь третий пункт в существующем dropdown
   `4 points / 2 lines / 1 line` (отдельная кнопка удалена). Flow единый:
   выбери `1 line` -> Choose (drawline на frame) -> Compute. В режиме
   `1 line` поле `cm X` автоматически отключается (используется только
   `cm Y` как единственное расстояние).

2. **Объекты panel** — row height 200 -> 340 px. Listbox теперь
   умещает ~12 entries (раньше 3).

3. **Overlay при рисовании нового объекта** — теперь видна и арена
   (оранжевая обводка) и существующие объекты (полупрозрачные синие
   filled). Раньше передавались только объекты. Применяется в
   `Add object` и `Replace selected`. При `Pick arena` арена не
   рисуется (её и так перерисовываешь), только объекты.

4. **Copy x N полностью переделан**:
   - Дефолтное место — **ring вокруг centroid'а** копируемого объекта
     (радиус = max(2.5*размер_объекта, 15 cm)).
   - Открывается интерактивный figure: фон-кадр + арена + существующие
     объекты + **N draggable полигонов** (зелёные ROI).
   - Кнопки **Confirm** / **Cancel**. До Confirm можешь дёргать любую
     копию мышкой как при interactive geometry pick.
   - Confirm коммитит финальные позиции в `app.State.objects`,
     Cancel — ничего не добавляется.

5. **circle-with-center walls** — теперь поддерживает поле `Wall width, cm`.
   Если 0 (дефолт) — старое поведение: 2 зоны `{wall=annulus, center}`.
   Если >0 — 3 зоны `{wall=thin ring, middle=annulus, center=disc}`. Поле
   `Wall width` теперь enabled когда strategy = `circle-with-center`.

6. **Auto-detect кнопки видимы** — кнопки `Auto-detect` и `Commit`
   перенесены в отдельный row 8 на всю ширину панели, styled action-color
   (light blue). Раньше зажаты были в `fit`-колонку и схлопывались.

Перезапусти MATLAB → `startup` → `sphynx.app.CreatePresetApp`, погоняй
заново. Старые шаги ниже актуальны с учётом изменений выше.

---

## Сборка

```matlab
cd C:\Users\User\PycharmProjects\sphynx
startup
sphynx.app.CreatePresetApp
```

## S6 — Frame picker N-of-M (твой запрошенный manual frame entry)

В nav-row справа от кнопки `Next frame` появилось:
- `N: 20` (field, range 2..200)
- Dropdown `1/20`...`20/20`

Тест:
1. Загрузи BARNES video. Должен показать `Frame 1 / 2703`.
2. В dropdown выбери `10/20` — превью перепрыгивает на frame ~1350.
3. Меняй N: 50, dropdown пересобирается в `1/50..50/50`.
4. `Next frame` теперь крутит индекс dropdown'а на +1 (с wrap-around).

## S1 — Object multi-select

1. Загрузи preset с 3+ объектами.
2. В listbox объектов: Ctrl+click несколько — на превью у выделенных
   обводки **жёлто-янтарного цвета** (`[1 0.85 0]`, толщина 2).
3. Снять выбор — кликнуть в пустое место listbox'а.

## S8 — Object class

Рядом с listbox'ом — новые контролы:
- `Class:` editfield
- `Assign to selected` кнопка

Тест:
1. Выдели 2 объекта (S1).
2. Введи в Class поле `neutral`, нажми Assign.
3. В консоли: `Assigned class "neutral" to 2 objects`.
4. Сохрани preset, загрузи — поле `class` должно подняться (т.е. при
   повторном клике на объект и Assign'е поле подгружается).

## S9 — Multi-select group move

Когда выбрано >=2 объекта (S1), в `MoveTargetDropDown` появляется
пункт `<selection>`.

Тест:
1. Выдели 3 объекта.
2. В MoveTargetDropDown выбери `<selection>`.
3. Жми стрелки Left/Right/Up/Down — все 3 двигаются совместно.
4. Жми Rot ↺ / Rot ↻ — все 3 вращаются вокруг общего centroid
   (форма каждого сохраняется, поворачивается только pattern).

## S2 — Copy × N

Под listbox'ом объектов:
- `Copy: 5` (field, range 1..20)
- `Copy x N` кнопка

Тест:
1. Калибровка должна быть проставлена (любым способом).
2. Выдели РОВНО 1 объект.
3. Введи Copy=5, жми Copy x N.
4. Появляется 5 копий смещённых на 30 см вправо (или grid 5×... при N>5).
5. Все 5 копий **автоматически становятся selected** — сразу можно
   двигать их через `<selection>` (S9).
6. Если выделено 0 или 2+ объекта — статус `Copy x N requires exactly 1`.

## S3 — Overlay existing on picker

1. Поставь 2+ объекта.
2. Add Object → выбери геометрию (например Circle).
3. В всплывающем окне рисования: **существующие объекты видны
   полупрозрачно** (синий fill, alpha 0.2), чтобы не наставить
   новый поверх старого.
4. То же при Replace selected (existing рисуются, кроме того что
   заменяешь) и при Mark arena.

## S4 — Calibrate by 1 line

Рядом с кнопкой `Calibrate (4 points)` — новая `Calibrate (1 line)`.

Тест:
1. Load video.
2. Жми `Calibrate (1 line)`.
3. В попапе: рисуй линию известной длины (например по ребру арены).
4. Вводи cm.
5. `pxlPerCm` обновляется, X=Y=pxlPerCm, x_kcorr=1.
6. Cancel'и в любой точке — статус `Calibration cancelled`.

## S5 — Zoning strategy `circle-with-center`

В dropdown `Zones strategy` появилось `circle-with-center`.

Тест:
1. Круг арена (любой диаметр).
2. Стратегия `circle-with-center`.
3. Поле `Center diameter, cm` — введи 20.
4. `Preview zones` → 2 зоны: wall (annulus) + center (disc).
5. Сохрани preset, перезагрузи — `CenterDiameterCm` подхватывается
   (default 20 если поле не было в старом preset'е).

## S10 — Manual exclusion: circle option

На вкладке Preprocess Tracking → Regions:
- Новый dropdown `Region shape` (polygon | circle, default polygon).

Тест:
1. Выбери `circle`.
2. Add region.
3. В попапе появляется `drawcircle` (не drawpolygon).
4. После клика — region в списке как 60-vertex polygon
   (визуально круглый).
5. Apply preprocessing — кадры внутри круга → NaN.

## S11 — Auto exclusion ring N cm

На вкладке Preprocess → Regions, новые контролы:
- Чекбокс `Auto-add ring outside arena`
- `Width cm: 5`
- Кнопка `Add ring`

Тест:
1. Загрузи preset с ареной + pxlPerCm.
2. Введи Width=5, жми Add ring.
3. Region(s) появляются в списке как polygon(s) — каждый component
   ring'а отдельно (если арена касается края кадра, рвётся на
   несколько).
4. Apply preprocessing — DLC точки в кольце 5 см вне арены → NaN.

## S7 — Auto-detect objects (главная фича для Barnes)

Внизу левой колонки — новая панель `Auto-detect objects`. Контролы:
- `Mode`: free-form / all-circles / all-polygons / all-ellipses
- `Algorithm (circles)`: threshold / hough
- `Sensitivity`: slider 0..1, default 0.5
- `Min area, cm²`: 1
- `Max area, cm²`: 500
- `Radius range, px (Hough)`: 5 / 30
- `Start numbering from`: 1
- `Auto-detect` + `Commit` кнопки

Тест на Barnes:
1. Загрузи BARNES video + preset с ареной (Circle).
2. Mode = `all-circles`, Algorithm = `threshold`, Sensitivity = 0.5.
3. Min area 1, Max area 50 (для маленьких barnes-лунок).
4. Auto-detect → **зелёным пунктиром** обводятся обнаруженные круги
   на превью (только preview, не зафиксировано).
5. Подкрути sensitivity, повторяй Auto-detect.
6. Если лучше с Hough — переключи Algorithm, попробуй Radius range
   подобрать (например 8..20 px для barnes-лунок).
7. Когда устраивает: `Start numbering from` = `numel(объектов)+1`,
   жми Commit.
8. Зелёные пунктиры превращаются в полноценные Object1, Object2, ...
   в listbox'е. Дальше можно через S1 multi-select, S9 двигать
   группой, S8 присвоить класс (например 'barnes hole'),
   S2 копировать дополнительно.

**Известная особенность:** для синтетически-однотонного фона
`adaptthresh` плодит artifact'ы. Я добавил гибридный фильтр через
75-percentile фона + sensitivity scaling. На реальных video frame'ах
работает корректно (8 объектов из 8 в simulation Барнс-арены),
на синтетических ровных тоже. Но если ловишь странности — слайдер
sensitivity это первый параметр для подкрутки.

## Что ещё

`Calibrate (1 line)` — также проверь что **не** ломает существующую
4-point калибровку. Те же поля (`X`, `Y`, `avg`, `kcorr`) обновляются.

## Deferred polish (накопил, отдашь пачкой)

Из ревью обоих passes собран список в `claude_log.md`. Ничего критичного;
например float-compare в pickGoodFrame, missing `border_y` isfield guard
в overlay, magic numbers в auto-detect floorThresh formula. Скажи
"polish pass" — сделаем за один заход.

## Что закидывать обратно

Под заголовком `## iteration N — что не так` сюда же. Кидай:
- Точный фрагмент output из MATLAB Command Window.
- Какой шаг был.
- Что увидел (или не увидел) на превью / в listbox.

Если всё ок — скажи "pass 2 ок" и переходим к следующему этапу
(если хочешь — возобновим Project subsystem brainstorm от 2026-05-12,
или новая тема).

---

## Round 14 — 10.06 правки (6 пунктов)

Коммит: <см. git log после commit>

### Что сделано
1. Калибровка-gate: warn для auto-detect/preview/add, hard-block для copy/align.
2. Объекты двигаются после autodetect — дедуп типов + auto-finish на X.
3. Pending shapes — без двойного клика (Circle/Ellipse drag-release).
4. Copy x N — drawcircle/drawellipse/drawpolygon по геометрии исходника.
5. Sensitivity — длинная шкала + numeric input снизу + tick labels 0..1.
6. 1-line калибровка — guard 20..70 deg с redraw/cancel.

### Команды для smoke (MATLAB)
1. `clear classes; close all; sphynx.app.CreatePresetApp` — стартовать.
2. Прогнать сценарии из user_log 2026-06-10 (пункты 1..6).

### Что прислать назад
- Что увидел / не увидел по каждому пункту.
- Любые подсказки/ошибки в logs/claude_log.md или GUI textarea.

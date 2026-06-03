# Barnes features (Pass 1 + Pass 2) — design

**Date:** 2026-06-03
**Branch:** `sphynx-GUI`
**Status:** awaiting user review

## Context

Юзер запускает Barnes-парадигму. Старая CreatePresetApp заморожена (`feedback_createpreset_frozen`), теперь расконсервируется. Нужны 3 bug fixes + 11 feature additions.

Деление работы:

- **Pass 1** — три точечных bug fix'а, разблокируют текущую работу.
- **Pass 2** — 11 фич в одной спеке.

## Pass 1 — Bug fixes

### A1. `numFrames` robustification

**Проблема.** Юзер видит «два кадра на выбор» при перемотке Next Frame. Причина: `VideoReader.NumFrames` в R2020a возвращает `2` для VFR h264 mp4 (репро: `Demo/BARNES/2_Video/VIDEO_20260411_130747271.mp4`, 59/3 fps).

Шаг = `max(round(numFrames/20), 1) = 1`; `mod(idx+0, 2) + 1` крутит между 1 и 2.

**Фикс.** `+sphynx/+preset/pickGoodFrame.m`:

```matlab
n = v.NumFrames;
if isnan(n) || n <= 1
    n = round(v.Duration * v.FrameRate);
    sphynx.util.log('warn', '[pickGoodFrame] NumFrames=%g unreliable; using Duration*FrameRate=%d', v.NumFrames, n);
end
out.numFrames = n;
```

**Тест.** Mock VideoReader, выставить NumFrames=2 при Duration=135s, FrameRate=19.67 → ожидаем `numFrames ≈ 2702`.

### A2. `classifyCircle` relaxed boundaries

**Проблема.** При WallW=12, MidW=24, arena diameter=92 (Circle или Ellipse) middle ring пропадает.

Причина: `if maxDist < wallW + minC; return;` отсекает арены, где центральный диск получился бы уже `minCenterCm`. Boundary case + floating point делает поведение flaky.

**Фикс.** `+sphynx/+zones/classifyCircle.m`:

- Убрать early return. Wall теперь ВСЕГДА добавляется.
- В loop: `while cumW + midW <= maxDist + eps` (eps = 0.5 px). Это фиксит boundary case 92-cm арены.
- После loop: `center` добавляется если есть свободное место любой ширины (включая < `MinCenterCm`).

Покрывает оба случая: точный boundary для круга, и эллипс с разными полуосями.

**Тест.** Unit: arena радиусом `wallW + midW + minC` ровно → `{wall, middle1, center}`. Эллипс 90×60 cm с тем же wallW/midW → `{wall, center}` (без middle, но не падает).

### A3. `readDLC` decimal separator

**Проблема.** На RU-локали Windows `readmatrix` без явного `DecimalSeparator` может интерпретировать `.` как разделитель тысяч → NaN'ы → Hampel/sgolay падают с типовой ошибкой про `double`.

**Фикс.** `+sphynx/+io/readDLC.m:58`:

```matlab
data = readmatrix(csvPath, 'NumHeaderLines', 3, 'DecimalSeparator', '.');
```

**Тест.** Unit: написать синтетический CSV (DLC header + `0.123`-значения) с временной сменой locale; прочитать; проверить отсутствие NaN.

### Pass 1 объём

~50 строк кода, 3 unit-теста. Один коммит на каждый баг + опциональный финальный smoke на BARNES видео.

---

## Pass 2 — Features

Целиком — 11 секций. Реализация идёт в порядке зависимостей: S1 (selection) первой, потом всё, что её использует.

### S1. Object selection model (foundation)

База для S2/S8/S9.

- `ObjectsListBox.Multiselect = true`. `Value` становится cell array.
- Marquee на preview canvas через кнопку `Marquee select`: открывает `drawrectangle(PreviewAxes)`, после `wait(h)` — найти объекты, чьи centroids внутри прямоугольника. Объединяется с уже selected в listbox через `union`.
- State: `app.State.selectedObjectIdx` (vector). Источник истины.
- Visual: selected объекты на preview обводятся жёлтой каймой.
- Все downstream (move/rotate/class/delete/replace) принимают vector indices.

### S2. F4 — Copy object ×N

- Кнопка `Copy ×N` рядом с Add Object. Поле `N` (default 5, range 1..20).
- Требует ровно 1 selected (иначе error message).
- Координаты копий: при N≤5 — row горизонтальный (вправо). При N>5 — grid 5 columns × `ceil(N/5)` rows, заполнение row-major. Шаг между копиями `30*pxlPerCm` (≈ 30 cm) по обеим осям.
- Каждая копия = deep copy original + `border_x/y += offset`. Type = `Object<next>+1..N`.
- Все скопированные сразу становятся selected (S1) — пользователь сразу двигает их вместе (S9).

### S3. F5 — Overlay existing on picker

В `readArenaGeometry.m`: новый параметр `'ExistingObjects', state.objects`.

Перед `drawpolygon`/`drawcircle`/`drawellipse` рисуем existing objects полупрозрачно:

```matlab
hold(ax, 'on');
for k = 1:numel(existing)
    fill(ax, existing(k).border_x, existing(k).border_y, ...
        [0.3 0.5 0.8], 'FaceAlpha', 0.2, 'EdgeColor', [0.1 0.3 0.6], ...
        'EdgeAlpha', 0.8, 'LineWidth', 1);
end
hold(ax, 'off');
```

Передавать из `addObject` и `replaceSelectedObject`.

### S4. F6 — Calibrate by 1 line

Новая кнопка `Calibrate (1 line)` рядом с существующим `Calibrate (4 points)`.

```matlab
hL = drawline(ax);
wait(hL);
P = hL.Position;
lengthPx = sqrt(diff(P(:,1))^2 + diff(P(:,2))^2);
cm = inputdlg('Длина линии в cm:');
pxlPerCm = lengthPx / str2double(cm{1});
% pxlPerCmX = pxlPerCmY = pxlPerCm, x_kcorr = 1
app.setPixelsPerCm(pxlPerCm, 'Y', pxlPerCm, 'X', pxlPerCm, 'KCorr', 1);
```

4-point калибровка остаётся (для perspective distortion). Сохраняется/читается одинаково.

### S5. F7 — Zoning strategy `circle-with-center`

Не новый geometry арены — новая **strategy** в `ZonesStrategy` dropdown.

- Items: добавляем `'circle-with-center'` рядом с `'circle-rings'`.
- Новое поле `CenterDiameterCm` (видимо только когда стратегия выбрана).
- Применимо к любой arena geometry (Circle/Ellipse/Polygon/O-maze). Centroid = `mean([X, Y])` по точкам border (для O-maze — по outer border).
- Логика: 2 зоны
  - `center` = диск радиуса `CenterDiameterCm/2`, концентричный с arena centroid (`(X-cx)^2 + (Y-cy)^2 < r^2`), пересечён с arena.mask
  - `wall` = `arena.mask & ~center.maskfilled`
- Реализация: `+sphynx/+preset/buildZonesCircleCenter.m` (новый файл, тонкий).

### S6. F8 — Frame picker «N кадров на выбор»

В nav-row (после Pass 1 A1 fix, numFrames достоверен):

- Поле `N frames` (default 20, integer 2..200).
- Dropdown `Pick: 1/N, 2/N, ..., N/N` (label показывает `1/N (frame X of NumFrames)`).
- Изменение dropdown → `frameIndex = round(numFrames * k / N); readFrame; refreshPreview`.
- Кнопка `Next frame` теперь advances dropdown index (как сейчас, но через новый механизм).

### S7. F9 — Auto-detect objects

**Самая большая секция.** Pipeline:

```
gray = rgb2gray(frame)
roiMask = arena.mask
threshMap = adaptthresh(gray, sensitivity)
binary = imbinarize(gray, threshMap) & roiMask
[L, n] = bwlabel(binary)
stats = regionprops(L, 'Centroid', 'Area', 'BoundingBox', ...
                       'MajorAxisLength', 'MinorAxisLength', 'Orientation', ...
                       'PixelIdxList')
filtered = stats([stats.Area] in [minArea, maxArea])
```

**Modes (post-fit blobs):**

- `free-form` — каждый blob → Polygon через `bwboundaries(mask)` + dense outline
- `all circles`:
  - subset `Threshold` — `circleFit(boundary)` per blob
  - subset `Hough` — `imfindcircles(gray, radiusRange, 'Sensitivity', s)` напрямую, blob filter не нужен
- `all polygons` — `bwboundaries` + `reducepoly` если есть (R2019b+, есть в R2020a), иначе uniform sampling ~30 pts
- `all ellipses` — `regionprops` уже даёт MajorAxis/MinorAxis/Orientation → построить ellipse outline

**UI panel** (новая, рядом с Objects panel в Create Preset):

- Dropdown `Mode`: `free-form / all circles / all polygons / all ellipses`
- Sub-dropdown `Algorithm` (видим только для `all circles`): `Threshold / Hough`
- Slider `Sensitivity` (0..1, default 0.5)
- Slider `Min Area, cm²` (0..200, default 1)
- Slider `Max Area, cm²` (0..2000, default 500)
- Slider `Radius range, cm` (для Hough only, диапазон)
- Live overlay preview: контуры обнаруженных объектов на превью с alpha 0.3, обновляется при изменении любого slider'а (debounce ~100ms).
- Button `Auto-detect` — запускает обнаружение в текущих параметрах, обновляет overlay.
- Field `Start numbering from`: integer (default = `numel(state.objects)+1`).
- Button `Commit detected` — фиксирует detected объекты в `state.objects` начиная с указанного номера. После commit пользователь может drag-and-move отдельные объекты обычными move-кнопками (или S9 multi-select).
- Требует загруженной арены (`arena.mask` непустой). Если арены нет — кнопка disabled с tooltip.

### S8. F10 — Object class

- В object struct новое поле `class` (string, default `''`).
- В Object panel: editfield `Class:` + кнопка `Assign to selected`. Применяется к multi-selected (S1).
- Сохранение: `arena.objects(k).class` пишется/читается в .mat preset.
- Downstream: пока никакой логики. Просто хранится, проходит до Analyze. Будет использовано позже.

### S9. F11 — Multi-select + group move

Поверх S1:

- `moveTarget(delta)`: для каждого `objIdx in selected`: `border_x += delta(1); border_y += delta(2); refit mask`.
- `rotateTarget(sign)`: вычисляем centroid пула (среднее по border points всех selected). Для каждого selected — pivot rotation вокруг pool centroid. Индивидуальные orientation объектов **не меняются** — вращается только pattern.
- `MoveTargetDropDown` получает пункт `<selection>` (видим когда `numel(selected)>=2`).

### S10. F12 — Manual exclusion: circle option

В Preprocess `addManualRegion`:

- Dropdown `Region shape`: `polygon` / `circle`. Default `polygon` (back-compat).
- Circle path: `drawcircle(ax)` → centroid + radius → sample 60 pts:

```matlab
ang = linspace(0, 2*pi, 60)';
vertices = [cx + r*cos(ang), cy + r*sin(ang)];
```

Сериализация = vertices как у polygon. Downstream (`inpolygon` filter) работает без изменений.

### S11. F13 — Exclusion auto N cm from arena boundary

В Preprocess Region panel:

- Чекбокс `Auto-add ring outside arena boundary`.
- Если включён: новое поле `Width, cm` (default 5). Кнопка `Add ring` (вместо `Add region` для этого режима).
- Алгоритм:

```matlab
% Inverse mask
distOutside = bwdist(arenaMask);
ringMask = distOutside > 0 & distOutside <= N*pxlPerCm;
B = bwboundaries(ringMask, 'noholes');
% Берём ВСЕ компоненты ringMask (арена может касаться края кадра, тогда ring
% разрывается на несколько кусков). Сохраняем их как массив manualRegions —
% каждый компонент = одна region (один polygon).
regions = struct('vertices', {}, 'appliesTo', {}, 'scope', {});
for k = 1:numel(B)
    v = B{k};
    if size(v, 1) < 3; continue; end
    regions(end+1) = struct(...
        'vertices', v(:, [2 1]), ...   % [row,col] -> [x,y]
        'appliesTo', applies, ...
        'scope', scope);
end
% append to obj.State.manualRegions
```

Snapshot в момент клика. Если арена двигается — re-click. Требует загруженный preset (`arena.mask` + `pxlPerCm`).

### Pass 2 объём

11 секций, каждая локальная (1-3 файла). Большая — S7 (~150 LOC + UI panel). Остальные — 30-80 LOC. Тесты: для S5 (zone math), S7 (algorithm), S11 (ring geometry).

---

## Implementation order (предложение для writing-plans)

**Pass 1 (single plan):**
1. A1 numFrames fallback
2. A2 classifyCircle relaxed
3. A3 readDLC decimal separator
→ commit each + smoke на BARNES video.

**Pass 2 (single plan, but several commits):**
1. S1 selection model (foundation)
2. S8 object class (использует S1) + S9 multi-move
3. S2 Copy×N + S3 overlay existing
4. S4 calibrate-by-1-line
5. S5 circle-with-center strategy
6. S6 frame picker
7. S10 + S11 preprocess exclusion enhancements
8. S7 auto-detect (большая, последняя)

## Out of scope (для будущих pass)

- Project subsystem (продолжение брейншторма от 2026-05-12 спека) — отдельно.
- Скаффолд для Barnes-specific metrics (8 метрик обучение + 9 метрик тест) — позже.
- Custom Barnes export presets / templates — позже.

# Диагностика "real-valued vector of type double" (sgolay / Hampel)

Эта инструкция -- для удалённой машины

## Что сделать пользователю

### Шаг 1. Открыть MATLAB на той машине

В Command Window:

```matlab
cd C:/<путь к проекту sphynx>
startup
diagnose_ts_error
```

Откроется диалог выбора файла -- выбрать тот DLC csv, на котором
возникала ошибка.

### Шаг 2. Скопировать ВЕСЬ вывод из Command Window

Он начинается со строки `sphynx -- TS error diagnostic` и
заканчивается `Diagnostic done`. Прислать в чат / на почту.

### Шаг 3. Также прислать полный текст ошибки

Если ошибка ещё возникает -- запустить операцию которая её триггерит
и скопировать ВСЕ красные строки из Command Window. Минимум нужно:

- Текст ошибки (одной строкой `Error using ...`)
- Stack trace (несколько строк ниже)
- Имя файла из которого падает (последняя строка stack trace)

## Что покажет diagnose_ts_error

Скрипт автоматически проверяет 8 пунктов:

| # | Проверка | Что значит FAIL |
|---|----------|-----------------|
| 1 | MATLAB / locale | sprintf %g 0.5 = "0,5" -> RU локаль активна и могла бы ломать readmatrix |
| 2 | DecimalSeparator fix в readDLC | если FAIL -- свежий код не накатили, нужно `git pull` |
| 3 | readDLC отрабатывает | class(X)='double' и NaN-only=0 -> данные парсятся, проблема НЕ в чтении |
| 4 | Sample body part | finite frames > 30 -> есть на чём тестировать |
| 5 | sgolayfilt(double) | если PASS -> sgolayfilt работает с double; если FAIL -- проблема в Signal Processing Toolbox / версии |
| 6 | hampel(double) | то же про hampel |
| 7 | sphynx.preprocess.smoothTrace | проверка нашей обёртки end-to-end |
| 8 | git HEAD + history | какой именно commit на машине; должен быть >= c4edd31 |

## Гипотезы по убыванию вероятности

1. **Старый код на машине** (PyCharm "Update Project" не подтянул фикс
   c4edd31 / последующие). Проверка: пункт 2 = FAIL ИЛИ пункт 8 показывает
   HEAD < c4edd31. Решение: вручную git pull через терминал.

2. **Single precision где-то** (на момент 2026-06-26 -- защита от этого
   уже встроена в smoothTrace и в новый smoothDerived helper). Проверка:
   пункт 5 показывает что sgolayfilt(single) кидает ту же ошибку.

3. **NaN run внутри trace** (нашу обёртку не использовали; legacy code
   шёл напрямую в sgolayfilt). Проверка: stack trace показывает
   sgolayfilt вызвавшийся НЕ через sphynx.preprocess.smoothTrace.

4. **Signal Processing Toolbox недоступен/повреждён**. Проверка: пункт 1
   "Signal Processing Toolbox: 0".

## Что я починил на стороне sphynx (коммит этого turn'а)

- Все производные сглаживания (rear sumDist, applyAct rears, velocity)
  переведены на `smoothdata`-based helper `sphynx.util.smoothDerived`.
  Не требует Signal Processing Toolbox и terpимее к single/NaN.
- `sphynx.preprocess.smoothTrace` теперь явно кастует input к double
  и заполняет интерьерные NaN перед вызовом sgolayfilt.

После того как remote-машина подтянет свежий код, ошибка должна
исчезнуть. Если нет -- diagnose_ts_error выявит конкретную причину.

## Iteration 2 (2026-06-29, R30) -- разбор присланного output'а

### Прислано

| Пункт | Результат |
|---|---|
| [1] Signal Processing Toolbox license | **1** (license check проходит) |
| [2] readDLC DecimalSeparator fix      | PASS |
| [3] readDLC parses csv                | OK, class(X)=double, NaN-only=0 |
| [4] First body part                   | 4923/5795 finite frames |
| [5] sgolayfilt(double)                | **FAIL: Undefined function** |
| [5b] sgolayfilt(single)               | **FAIL: Undefined function** |
| [6] hampel(double)                    | **FAIL: Undefined function** |
| [7] smoothTrace                       | FAIL (cascaded from [5]) |
| [8] git probe                         | failed -- broken cmd.exe quoting (мой баг в диагностике, не у пользователя) |

### Вердикт

**Signal Processing Toolbox не установлен** на машине коллеги, хотя
лицензия числится валидной. Это типичная ситуация со стрипнутой
MATLAB-инсталляцией: `license('test','signal_toolbox')` смотрит
ТОЛЬКО лицензионный файл, не факт наличия функций. Авторитетный
тест -- `exist('sgolayfilt','file') == 2`.

Что подтверждает диагноз: ошибка `Undefined function 'sgolayfilt'
for input arguments of type 'double'` -- это не MATLAB-ошибка
сигнатуры аргумента, это _no method found_, т.е. функция вообще
неизвестна интерпретатору.

### Два пути для коллеги

**A. Установить Signal Processing Toolbox**
   - В MATLAB: Home -> Add-Ons -> Get Add-Ons -> искать "Signal
     Processing Toolbox" -> Install. Нужен Mathworks-аккаунт с
     лицензией; раз license=1 -- он есть.

**B. Подтянуть свежий sphynx-GUI (рекомендуется как первый шаг)**
   - R30 добавил graceful fallbacks:
     - `smoothTrace`: при отсутствии `sgolayfilt` -> `smoothdata`
       movmean (base MATLAB). Однократный warning в Command Window.
     - `hampelFilter`: при отсутствии `hampel` -> rolling-MAD через
       `movmedian` (base MATLAB). Однократный warning.
   - Pipeline продолжит работать, качество сглаживания немного
     ниже Savitzky-Golay, но для downstream метрик приемлемо.
   - `git pull` на ветке `sphynx-GUI` -> перезапуск тестового
     прогона.

### Что улучшено в самом diagnose_ts_error (R30)

- **Пункт [1]** теперь печатает `exist('sgolayfilt','file')` и
  `which sgolayfilt` отдельно от license. Если в следующий раз
  столкнёмся с этим у кого-то ещё -- root cause будет виден сразу
  и явный VERDICT-блок укажет на оба пути выше.
- **Пункт [8]**: git probe quoting починен (на Windows trailing
  backslash в repoRoot съедал закрывающую кавычку). Теперь
  будет нормально печатать HEAD и историю.

### Что не нужно слать ещё раз

Если коллега выбрал путь B (просто `git pull`) -- повторный
`diagnose_ts_error` уже не нужен, достаточно проверить, что:
- В Command Window появилось `Warning: sgolayfilt not found ...`
  или `hampel not found ...` (это нормально, fallback работает)
- Анализ сессии доходит до конца без `Undefined function` ошибки.

Если коллега выбрал путь A (поставил toolbox) -- запустить
`diagnose_ts_error` ещё раз: пункты [5][6] должны стать PASS,
warning-ов от fallback быть не должно.

## Iteration 3 (2026-06-29, R30b) -- Женя: та же ошибка в Compute body part

### Что прислала

```
[ERROR] [Preprocess] Compute nose failed:
        Undefined function 'hampel' for input arguments of type 'double'.
[ERROR] [Preprocess] Compute nose failed:
        Undefined function 'sgolayfilt' for input arguments of type 'double'.
```

Кнопка `Compute this` в Preprocess Tracking tab. Та же машина без
Signal Processing Toolbox.

### Что это значит

R30 на её машине **ещё не подтянут**. Pull ветки `sphynx-GUI`
включит fallback'и -- ошибка превратится в однократный warning
`sgolayfilt not found ...` / `hampel not found ...` и Compute
доедет до конца.

`PreprocessTabController.computePart` (line 199) -> вызывает
`sphynx.preprocess.applyPerPartSettings` -> внутри идут наши
обёртки `sphynx.preprocess.hampelFilter` и
`sphynx.preprocess.smoothTrace`. R30 их обернул, R30b добавил
покрытие для `sphynx.angles.unwrapForSmooth` -- последнего
прямого callsite в `+sphynx`.

### Инструкция Жене

1. В терминале на её машине:
   ```
   cd <папка проекта sphynx>
   git pull
   ```
2. В MATLAB перезапустить:
   ```
   clear functions
   sphynx.app.CreatePresetApp
   ```
3. Загрузить тот же DLC, нажать `Compute this` на nose.
   Ожидается:
   - В Command Window появится **один** Warning:
     `Warning: sgolayfilt not found ...` (или hampel)
   - Compute доедет до конца, в Preprocess Tab появится статус
     `Computed nose: status=ok, NaN=...%`.

### R30b -- patch для unwrapForSmooth

Один файл: `+sphynx/+angles/unwrapForSmooth.m`. Тот же паттерн
что в R30: cached `exist`-probe + fallback на `smoothdata movmean`
+ однократный warning. Срабатывает при сглаживании HeadDirection /
BodyDirection.

Если бы оставили как есть, после Compute body part (который
работает через applyPerPartSettings) Женя наткнулась бы на ту же
ошибку при попытке посчитать direction.

Тесты после R30b: 350 / 0 / 3, без регрессий.

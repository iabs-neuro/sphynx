# Диагностика "real-valued vector of type double" (sgolay / Hampel)

Эта инструкция -- для удалённой машины (Windows, RU локаль, пользователь
не знаком с MATLAB/git).

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

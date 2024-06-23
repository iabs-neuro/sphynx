%% Загрузка данных из файла
filePath = 'i:\_STFP\SpecializationResults\STFP INTENS cross-stats all plus mice v1 no thr.csv';
dataTable = readtable(filePath, 'ReadVariableNames', true);

%% 
% Определение диапазона столбцов для проверки
colsToCheck = 2:5;

% Создание логического массива, который определяет, какие строки нужно оставить
validRows = true(height(dataTable), 1);

% Проверка каждого столбца в диапазоне 2-5
for col = colsToCheck
    % Обновление логического массива: строки, в которых значение '0.0' в текущем столбце, становятся недействительными
    validRows = validRows & ~strcmp(dataTable{:, col}, '0.0');
end

% Создание новой таблицы, содержащей только действительные строки
MatchedOnlyInAllSessionsTable = dataTable(validRows, :);

%% BD
function filteredTable = filterTable(tt, filters)
    % dataTable - таблица с данными
    % filters - структура с полями, где каждое поле содержит список значений для фильтрации
    filters = 'nosenosedist';
    % Инициализация логического массива для фильтрации строк
    validRows = true(height(tt), 1);
    
    % Проверка каждого столбца
    validRows = [];
    for col = 1:width(tt)
        columnData = tt{:, col}; % Извлекаем данные текущего столбца
        columnData = dataTable{:, col}; % Извлекаем данные текущего столбца
        % Применяем фильтры для текущего столбца
        for filter = filters
%             validRows = [validRows  contains(columnData, filter)];
            validRows = contains(columnData, 'interaction');
        end
    end
    SumValid = sum(validRows,2);
    histogram(SumValid);
    % Создание новой таблицы, содержащей только строки, удовлетворяющие условиям фильтрации
    filteredTable = MatchedOnlyInAllSessionsTable(logical(validRows), :);
end

% Пример использования функции

% Загрузка данных из файла (предположим, что таблица уже загружена в dataTable)
dataTable = readtable('path_to_your_file.csv', 'ReadVariableNames', true);

%% Создание структуры фильтров

filters = {'place', 'nosenosedist', 'interaction', 'speed', 'bodydirection', 'headdirection', 'distance_object1', 'distance_object2', 'rest', 'walk', 'locomotion', 'freezing', 'rear', 'body_in_area1', 'body_in_object1', 'head_in_area1', 'head_in_object1', 'head_in_hole1', 'interact_object1', 'interact_deep_object1', 'interact_odor1', 'body_in_area2', 'body_in_object2', 'head_in_area2', 'head_in_object2', 'head_in_hole2', 'interact_object2', 'interact_deep_object2', 'interact_odor2', 'body_in_areas', 'body_in_objects', 'head_in_areas', 'head_in_objects', 'head_in_holes', 'interact_objects', 'interact_deep_objects', 'interact_odors', 'head_in_hole1_long', 'head_in_hole1_short', 'head_in_hole2_long', 'head_in_hole2_short', 'head_in_holes_long', 'head_in_holes_short'};

% Вызов функции для фильтрации таблицы
filteredTable = filterTable(MatchedOnlyInAllSessionsTable, 'nosenosedist');

% Отображение результатов
disp('Фильтрованная таблица:');
disp(filteredTable);



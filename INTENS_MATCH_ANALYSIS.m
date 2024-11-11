%% Загрузка данных из файла
filePath = 'f:\_STFP\SpecializationResults\STFP INTENS cross-stats all plus mice v1 no thr.csv';
MainDataTable = readtable(filePath, 'ReadVariableNames', true);

%% фильтр таблицы с заменой cued control так, чтобы cued всегда 1
% Для 2 и 3 столбца для строк, в которых в 7ом столбце значения 'STFP_A03.csv' или 'STFP_A04.csv'
% Для 5го столбца для строк, в которых в 7ом столбце значения 'STFP_A03.csv'

% Создание копии таблицы для внесения изменений
modifiedTable = MainDataTable;

% Проход по всем строкам таблицы
for i = 1:height(modifiedTable)
    % Проверка условия для 2-го и 3-го столбцов
    if ismember(modifiedTable{i, 7}, {'STFP_A03.csv', 'STFP_A04.csv'})
        % Замена '1' на '2' и '2' на '1' в 2-м столбце
%         if ischar(modifiedTable{i, 2})
            modifiedTable{i, 2} = strrep(strrep(modifiedTable{i, 2}, '1', '_tmp'), '2', '1');
            modifiedTable{i, 2} = strrep(modifiedTable{i, 2}, '_tmp', '2');
%         end
        % Замена '1' на '2' и '2' на '1' в 3-м столбце
%         if ischar(modifiedTable{i, 3})
            modifiedTable{i, 3} = strrep(strrep(modifiedTable{i, 3}, '1', '_tmp'), '2', '1');
            modifiedTable{i, 3} = strrep(modifiedTable{i, 3}, '_tmp', '2');
%         end
    end
    
    % Проверка условия для 5-го столбца
    if strcmp(modifiedTable{i, 7}, 'STFP_A03.csv')
        % Замена '1' на '2' и '2' на '1' в 5-м столбце
%         if ischar(modifiedTable{i, 5})
            modifiedTable{i, 5} = strrep(strrep(modifiedTable{i, 5}, '1', '_tmp'), '2', '1');
            modifiedTable{i, 5} = strrep(modifiedTable{i, 5}, '_tmp', '2');
%         end
    end
end

%% только сметченные
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

% Загрузка данных из файла (предположим, что таблица уже загружена в dataTable)
% dataTable = readtable('path_to_your_file.csv', 'ReadVariableNames', true);

%% Создание структуры фильтров

% filters = {'place', 'nosenosedist', 'interaction', 'speed', 'bodydirection', 'headdirection', 'distance_object1', 'distance_object2', 'rest', 'walk', 'locomotion', 'freezing', 'rear', 'body_in_area1', 'body_in_object1', 'head_in_area1', 'head_in_object1', 'head_in_hole1', 'interact_object1', 'interact_deep_object1', 'interact_odor1', 'body_in_area2', 'body_in_object2', 'head_in_area2', 'head_in_object2', 'head_in_hole2', 'interact_object2', 'interact_deep_object2', 'interact_odor2', 'body_in_areas', 'body_in_objects', 'head_in_areas', 'head_in_objects', 'head_in_holes', 'interact_objects', 'interact_deep_objects', 'interact_odors', 'head_in_hole1_long', 'head_in_hole1_short', 'head_in_hole2_long', 'head_in_hole2_short', 'head_in_holes_long', 'head_in_holes_short'};
% filters = {'interaction'};
filters = {'head_in_areas'};
target_filter = 2;
targetColumns = 2:5;
% Вызов функции для фильтрации таблицы

filteredTable = filterTable(modifiedTable, filters, target_filter);
filteredTable = modifiedTable;
target_acts = {'nosenosedist','place','speed', 'headdirection', 'interact_odor1','interact_odor2','interact_odors','head_in_area1','head_in_area2','head_in_areas','head_in_hole1_long','head_in_hole2_long','head_in_holes_long'};
uniqueWords = Sankey_acts_finding_table(filteredTable);

% Поиск строк, которых нет в target_acts
missingWords = setdiff(uniqueWords, target_acts);

% добавить no matched no selective
filteredTable = Sankey_filter_table(filteredTable, missingWords);

[adjMat, uniqueWords] = Sankey_adjMat_uniq_acts(filteredTable);

%% making nodes names
nodeList=[uniqueWords{1} uniqueWords{2} uniqueWords{3} uniqueWords{4}];
% formattednodeList = cellfun(@(x) strrep(x, '_', '\_'), nodeList, 'UniformOutput', false);

% Создание словаря для замены строк
replacements = containers.Map({'nosenosedist','place', 'interact_odor1', 'interact_odor2', 'interact_odors', 'headdirection', 'head_in_hole1_long', 'head_in_hole2_long', 'head_in_holes_long'}, ...
                              {'No-to-nose distance','Place Cells', 'Head_in_object1', 'Head_in_object2', 'Head_in_objects', 'HeadDirection', 'Head_in_hole1', 'Head_in_hole2', 'Head_in_holes'});

formattedNodes = nodeList;

% Замена строк в formattedNodes
for i = 1:length(formattedNodes)
    if isKey(replacements, formattedNodes{i})
        formattedNodes{i} = replacements(formattedNodes{i});
    end
    % Сделать строку с большой буквы
    formattedNodes{i} = regexprep(formattedNodes{i}, '^(.)', '${upper($1)}');
end


% Преобразование строк в nodeList для корректного отображения и замены
formattedNodes = cellfun(@(x) strrep(x, '_', '\_'), formattedNodes, 'UniformOutput', false);

%% санки
SK=SSankey([],[],[],'NodeList',formattedNodes,'AdjMat',adjMat);
% method 1
% SK=SSankey([],[],[],'AdjMat',adjMat);
% method 2
% SK=SSankey([],[],[],'NodeList',nodeList,'AdjMat',adjMat)
% method 3
% SK=SSankey([],[],[]);
% SK.AdjMat=adjMat;

SK.draw()


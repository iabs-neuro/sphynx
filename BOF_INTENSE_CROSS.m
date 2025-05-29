% Скрипт для обработки нескольких CSV-файлов и создания итоговой таблицы

% Запрос выбора файлов
[filenames, pathname] = uigetfile('*.csv', 'Выберите CSV-файлы', 'MultiSelect', 'on');

% Проверка, выбран ли хотя бы один файл
if isequal(filenames, 0)
    disp('Файлы не выбраны. Скрипт завершен.');
    return;
end

% Если выбран только один файл, преобразуем в cell array для единообразия
if ischar(filenames)
    filenames = {filenames};
end

%% Создаем структуру для итоговой таблицы
resultTable = table();

% Обрабатываем каждый файл
for i = 1:length(filenames)
    filename = fullfile(pathname, filenames{i});
    
    % 1. Получаем первые 7 символов имени файла
    [~, name, ~] = fileparts(filenames{i});
    filePrefix = name(1:min(7, length(name)));
    
    % 2. Читаем таблицу
    data = readtable(filename, 'PreserveVariableNames', true);
    
    % 3. Находим столбец total_bowlinside или total_bowlinteraction
    bowlCol = [];
    if any(strcmp('total_bowlinside', data.Properties.VariableNames))
        bowlCol = 'total_bowlinside';
    elseif any(strcmp('total_bowlinteraction', data.Properties.VariableNames))
        bowlCol = 'total_bowlinteraction';
    else
        warning('Файл %s не содержит нужных столбцов. Пропускаем.', filenames{i});
        continue;
    end
    
    %% 4. Категоризуем данные
    categories = [0, 1, 2, 3];
    
    % Инициализируем переменные для результатов
    n_6T = zeros(1, 4);
    av_6T = zeros(1, 4);
    n_7T = zeros(1, 4);
    av_7T = zeros(1, 4);
    
    % Обрабатываем каждую категорию
    for catIdx = 1:length(categories)
        if categories(catIdx) == 3
            % Для категории 3 берем значения >=3
            mask = data.(bowlCol) >= 3;
        else
            mask = data.(bowlCol) == categories(catIdx);
        end
        
        % 5. Обработка столбца '6T av'
        col6T = '6T av';
        if any(strcmp(col6T, data.Properties.VariableNames))
            mask6T = mask;
            n_6T(catIdx) = sum(mask6T);
            if n_6T(catIdx) > 0
                av_6T(catIdx) = mean(data.(col6T)(mask6T));
            else
                av_6T(catIdx) = 0;
            end
        end
        
        % 6. Обработка столбца '7T av'
        col7T = '7T av';
        if any(strcmp(col7T, data.Properties.VariableNames))
            mask7T = mask;
            n_7T(catIdx) = sum(mask7T);
            if n_7T(catIdx) > 0
                av_7T(catIdx) = mean(data.(col7T)(mask7T));
            else
                av_7T(catIdx) = 0;
            end
        end
    end
    
    %% Создаем строку для итоговой таблицы
    row = table();
    row.filePrefix = {filePrefix};
    
    % Добавляем результаты для 6T
    for catIdx = 1:length(categories)
        row.(sprintf('n_6T_%d', categories(catIdx))) = n_6T(catIdx);
    end
    for catIdx = 1:length(categories)
        row.(sprintf('av_6T_%d', categories(catIdx))) = av_6T(catIdx);
    end
    
    % Добавляем результаты для 7T
    for catIdx = 1:length(categories)
        row.(sprintf('n_7T_%d', categories(catIdx))) = n_7T(catIdx);
    end
    for catIdx = 1:length(categories)
        row.(sprintf('av_7T_%d', categories(catIdx))) = av_7T(catIdx);
    end    
    % Добавляем строку в итоговую таблицу
    if isempty(resultTable)
        resultTable = row;
    else
        resultTable = [resultTable; row];
    end
end

% Сохраняем итоговую таблицу
if ~isempty(resultTable)
    outputFilename = fullfile(pathname, 'result_table.csv');
    writetable(resultTable, outputFilename);
    fprintf('Итоговая таблица сохранена в файл: %s\n', outputFilename);
else
    disp('Не удалось создать итоговую таблицу. Проверьте входные файлы.');
end
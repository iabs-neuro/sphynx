%% анализ сырой таблички интенса
% Запросить путь к файлу CSV
[fileName, filePath] = uigetfile('*.csv', 'Select CSV file', 'i:\_STFP\INTENS_Data\' );
if isequal(fileName, 0)
    disp('Выбор файла отменен');
    return;
end
fullFilePath = fullfile(filePath, fileName);

% Чтение таблицы из CSV файла
dataTable = readtable(fullFilePath, 'ReadVariableNames', false);

% Извлечение имен поведенческих актов из первой строки
behaviorNames = string(table2cell(dataTable(1, 2:end)));
neuronNumbers = string(table2cell(dataTable(2:end, 1)));

% Преобразование данных в таблице в строковый тип
dataMatrix = string(table2cell(dataTable(2:end, 2:end)));

% Инициализация переменных для хранения результатов
significantNeurons = cell(1, length(behaviorNames));
percentSignificantNeurons = zeros(1, length(behaviorNames));

% Обработка данных
for behaviorIdx = 1:length(behaviorNames)
    neuronIndices = [];
    for neuronIdx = 1:size(dataMatrix, 1)
        cellData = dataMatrix(neuronIdx, behaviorIdx);
        if contains(cellData, "'rel_mi_beh': None")
            continue;
        else
            pattern = "'rel_mi_beh': ([0-9.]+)";
            matches = regexp(cellData, pattern, 'tokens');
            if ~isempty(matches)
                relMiBehValue = str2double(matches{1}{1});
                if relMiBehValue > 0
                    neuronIndices = [neuronIndices; neuronNumbers(neuronIdx)];
                end
            end
        end
    end
    significantNeurons{behaviorIdx} = neuronIndices;
    percentSignificantNeurons(behaviorIdx) = length(neuronIndices) / size(dataMatrix, 1) * 100;
end

% Вывод результатов
for behaviorIdx = 1:length(behaviorNames)
    fprintf('Поведенческий акт: %s\n', behaviorNames(behaviorIdx));
    if ~isempty(significantNeurons{behaviorIdx})
        fprintf('Индексы нейронов: %s\n', strjoin(cellstr(significantNeurons{behaviorIdx}), ', '));
    else
        fprintf('Индексы нейронов: None\n');
    end
    fprintf('Процент значимо специализированных нейронов: %.2f%%\n\n', percentSignificantNeurons(behaviorIdx));
end

% Предполагается, что таблица dataTable уже прочитана и преобразована в строковый тип
% behaviorNames - строковый массив с именами поведенческих актов
% dataMatrix - строковый массив данных (все ячейки содержат строки JSON-подобного типа)

% Запросить путь для сохранения графиков
% savePath = uigetdir('', 'Выберите папку для сохранения графиков');
savePath = 'i:\_STFP\INTENS_Data\STFP_A04_D2_T2\histogram\';
% Инициализация переменной для хранения степеней pval
pvalExponents = cell(1, length(behaviorNames));

% Извлечение степеней pval
for behaviorIdx = 1:length(behaviorNames)
    exponents = [];
    for neuronIdx = 1:size(dataMatrix, 1)
        cellData = dataMatrix(neuronIdx, behaviorIdx);
        if contains(cellData, "'pval': None")
            continue;
        else
            pattern = "'pval': ([0-9.eE+-]+)";
            matches = regexp(cellData, pattern, 'tokens');
            if ~isempty(matches)
                pvalValue = str2double(matches{1}{1});
                if ~isnan(pvalValue)
                    exponent = floor(log10(pvalValue));
                    exponents = [exponents; exponent];
                end
            end
        end
    end
    pvalExponents{behaviorIdx} = exponents;
end

% Построение и сохранение гистограмм
for behaviorIdx = 1:length(behaviorNames)
    figure;
    histogram(pvalExponents{behaviorIdx});
    title(sprintf('Гистограмма степеней pval для поведенческого акта: %s', behaviorNames(behaviorIdx)));
    xlabel('Степень pval');
    ylabel('Частота');
    
    % Сохранение графика
    saveas(gcf, fullfile(savePath, sprintf('Histogram_%s.png', behaviorNames(behaviorIdx))));
    close(gcf);
end

disp('Графики сохранены.');
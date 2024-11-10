function uniqueWords = Sankey_acts_finding(dataTable, col_num)
% Предполагается, что таблица dataTable уже загружена в рабочую область
% dataTable - таблица, содержащая строки и числа в ячейках

% Инициализация пустого списка для хранения уникальных слов
uniqueWords = {};

% Проход по всем ячейкам таблицы
for i = 1:height(dataTable)
    for j = col_num
        % Извлечение содержимого ячейки
        cellContent = dataTable{i, j};
        if ~isempty(cellContent) && ~strcmp(cellContent, '---')
            % Извлечение слов из ячейки
            matches = regexp(cellContent, '''(\w+)''', 'tokens');
            matches = [matches{:}]; % Преобразование в одномерный массив
            uniqueWords = [uniqueWords matches];
        end
    end
end

% Удаление дубликатов из списка слов
uniqueWords = unique(cellfun(@char, uniqueWords, 'UniformOutput', false));
% Отображение уникальных слов
% disp('Уникальные слова в таблице:');
% disp(uniqueWords);

end

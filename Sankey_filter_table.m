function modifiedTable = Sankey_filter_table(filteredTable, missingWords)

% Проход по всем ячейкам таблицы filteredTable
for i = 1:height(filteredTable)
    for j = 2:5
        % Извлечение содержимого ячейки
        cellContent = filteredTable{i, j};
        if ~isempty(cellContent) && ~strcmp(cellContent, '---')
            % Проход по каждому слову из missingWords
            for k = 1:length(missingWords)
                % Создание шаблона для удаления слова и связанного числа
                pattern = sprintf('\\(''%s'', [0-9.]+\\),*\\s*', missingWords{k});
                % Замена шаблона на пустую строку
                cellContent = regexprep(cellContent, pattern, '');
            end
            % Удаление ведущих и завершающих запятых и пробелов
            cellContent = strtrim(regexprep(cellContent, '^,|,$', ''));
            % Обновление ячейки
            filteredTable{i, j} = cellContent;
        end
    end
end

% Копирование оригинальной таблицы для изменений
modifiedTable = filteredTable;

% Проход по всем ячейкам таблицы
for i = 1:height(modifiedTable)
    for j = 2:5
        % Извлечение содержимого ячейки
        cellContent = modifiedTable{i, j};
        
        % Замена '---' на 'non selective'
        if strcmp(cellContent, '---')
            modifiedTable{i, j} = {'(''non_selective'', 1)'};
        end
        
        % Замена '0.0' на 'no matched'
        if strcmp(cellContent, '0.0')
            modifiedTable{i, j} = {'(''no_matched'', 1)'};
        end
        
        % Замена '' на 'non selective'
        if strcmp(cellContent, '')
            modifiedTable{i, j} = {'(''non_selective'', 1)'};
        end
    end
end

% Отображение результирующей таблицы
% disp('Обновленная таблица:');
% disp(filteredTable);

end
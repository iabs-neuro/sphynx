function filteredTable = filterTable(tt, filters, num_col)
    % dataTable - таблица с данными
    % filters - структура с полями, где каждое поле содержит список значений для фильтрации
%     filters = 'nosenosedist';
    % Инициализация логического массива для фильтрации строк
%     validRows = true(height(tt), 1);
    
    % Проверка каждого столбца
    validRows = [];
    for col = 1:width(tt)
        columnData = tt{:, num_col}; % Извлекаем данные текущего столбца
%         columnData = dataTable{:, col}; % Извлекаем данные текущего столбца
        % Применяем фильтры для текущего столбца
        for filter = filters
%             validRows = [validRows  contains(columnData, filter)];
            validRows = contains(columnData, filter);
        end
    end
%     SumValid = sum(validRows,2);
%     histogram(SumValid);
    % Создание новой таблицы, содержащей только строки, удовлетворяющие условиям фильтрации
    filteredTable = tt(logical(validRows), :);
end
function adjMat = Sankey_adjMat(dataTable)
% dataTable - таблица, содержащая строки и числа в ячейках

uniqueWords = Sankey_acts_finding(dataTable);

% Определение целевых столбцов для анализа
targetColumns = 2:4;

% Инициализация матрицы смежности
n = length(uniqueWords);
adjMat = zeros(n, n);

% % Создание словаря для индексации уникальных слов
% wordIndex = containers.Map(uniqueWords, 1:n);

% Проход по всем целевым ячейкам таблицы для построения матрицы смежности
for i = 1:height(dataTable)
    for j = targetColumns
        % Извлечение содержимого ячейки
        cellContent = dataTable{i, j};
        if ~isempty(cellContent)
            % Извлечение слов и значений из ячейки
            matches_this = regexp(cellContent, '''(\w+)''', 'tokens');
            matches_this = [matches_this{:}]; % Преобразование в одномерный массив
            
            matches_next = regexp(dataTable{i, j+1}, '''(\w+)''', 'tokens');
            matches_next = [matches_next{:}]; % Преобразование в одномерный массив
            
            % Заполнение матрицы смежности
            for k = 1:length(matches_this)
                act_ind = find(strcmp(uniqueWords,matches_this{k}));                
                for l = 1:length(matches_next)
                    act_next_ind = find(strcmp(uniqueWords,matches_next{l}));
                    adjMat(act_ind, act_next_ind) = adjMat(act_ind, act_next_ind) + 1;
                end
            end
        end
    end
end

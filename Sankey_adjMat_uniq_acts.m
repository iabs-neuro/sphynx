function [adjMat,uniqueWords] = Sankey_adjMat_uniq_acts(dataTable)
% dataTable - таблица, содержащая строки и числа в ячейках

% Определение целевых столбцов для анализа
targetColumns = 2:4;
uniqueWords = [];
uniqueWords{1} = Sankey_acts_finding(dataTable,2);
uniqueWords{2} = Sankey_acts_finding(dataTable,3);
uniqueWords{3} = Sankey_acts_finding(dataTable,4);
uniqueWords{4} = Sankey_acts_finding(dataTable,5);
Num_acts = [length(uniqueWords{1}) length(uniqueWords{2}) length(uniqueWords{3}) length(uniqueWords{4})];
Sum_acts = [0 Num_acts(1) Num_acts(1)+Num_acts(2) Num_acts(1)+Num_acts(2)+Num_acts(3)];
% Инициализация матрицы смежности
n = sum(Num_acts);
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
                act_ind = find(strcmp(uniqueWords{j-1},matches_this{k}))+Sum_acts(j-1);                
                for l = 1:length(matches_next)
                    act_next_ind = find(strcmp(uniqueWords{j},matches_next{l}))+Sum_acts(j);
                    adjMat(act_ind, act_next_ind) = adjMat(act_ind, act_next_ind) + 1;
                end
            end
        end
    end
end

end
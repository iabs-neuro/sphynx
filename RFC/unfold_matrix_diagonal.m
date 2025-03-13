function resultArray = unfold_matrix_diagonal(pairwiseMatrix)
    N = size(pairwiseMatrix, 1); % Размер матрицы
    resultArray = []; % Итоговый массив
    
    % Перебираем диагонали (разность индексов d = j - i)
    for d = 1:N-1
        for i = 1:N-d
            j = i + d; % Второй индекс
            resultArray = [resultArray, pairwiseMatrix(i, j)];
        end
    end
end

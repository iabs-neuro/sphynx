function [r, p] = computePearsonCorrelation(matrix1_orig, matrix2_orig)
    % computePearsonCorrelation - вычисляет корреляцию Пирсона между двумя матрицами
    %
    % Входные параметры:
    %   matrix1 - первая матрица (числовая)
    %   matrix2 - вторая матрица (числовая)
    %
    % Выход:
    %   r - коэффициент корреляции Пирсона

    % Убедимся, что размеры матриц совпадают
    if ~isequal(size(matrix1_orig), size(matrix2_orig))
        disp(['Матрицы не одинакового размера. 1: [' num2str(size(matrix1_orig)) ']  2: [' num2str(size(matrix2_orig)) ']']);
        new_size = [min(size(matrix1_orig,1),size(matrix2_orig,1)) min(size(matrix1_orig,2),size(matrix2_orig,2))];
        matrix1 = matrix1_orig(1:new_size(1),1:new_size(2));
        matrix2 = matrix2_orig(1:new_size(1),1:new_size(2));
        disp(['Новый размер: ' num2str(size(matrix1)) ' и ' num2str(size(matrix2))]);
    else
        matrix1 = matrix1_orig;
        matrix2 = matrix2_orig;
    end

    % Преобразуем матрицы в одномерные массивы
    vector1 = matrix1(:);
    vector2 = matrix2(:);

    % Вычисляем корреляцию
    [r, p] = corr(vector1, vector2);

%     % Вывод результата
%     fprintf('Коэффициент корреляции Пирсона: %.4f\n', r);
%     fprintf('p-значение: %.4f\n', p);
% 
%     % Интерпретация значимости
%     if p < 0.05
%         fprintf('Корреляция значима (p < 0.05).\n');
%     else
%         fprintf('Корреляция незначима (p >= 0.05).\n');
%     end
end

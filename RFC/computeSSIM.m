function [ssim_val, ssim_map] = computeSSIM(matrix1_orig, matrix2_orig)
    % computeSSIM - вычисляет индекс структурного сходства (SSIM) между двумя матрицами
    %
    % Входные параметры:
    %   matrix1 - первая матрица (числовая)
    %   matrix2 - вторая матрица (числовая)
    %
    % Выход:
    %   ssim_val - среднее значение SSIM по всему изображению
    %   ssim_map - карта локальных значений SSIM (опционально)

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

    % Нормализуем данные в диапазон [0, 1] (если нужно)
    matrix1 = (matrix1 - min(matrix1(:))) / (max(matrix1(:)) - min(matrix1(:)));
    matrix2 = (matrix2 - min(matrix2(:))) / (max(matrix2(:)) - min(matrix2(:)));

    % Вычисляем SSIM
    [ssim_val, ssim_map] = ssim(matrix1, matrix2);

    % Вывод результата (опционально)
%     fprintf('SSIM: %.4f\n', ssim_val);
end
function compareMatrixDimensions(matrix1, matrix2)

    if size(matrix1, 2) ~= size(matrix2, 2)
        disp('!!!! Количество клеток в таблицах трейсов и спайков не совпадает !!!!');
    end

    if size(matrix1, 1) ~= size(matrix2, 1)
        disp('!!!! Количество временных точек в таблицах трейсов и спайков не совпадает !!!!');
    end
    
    if size(matrix1, 2) == size(matrix2, 2) && size(matrix1, 1) == size(matrix2, 1)
        disp('Размер таблиц трейсов и спайков совпадает');
    end
end

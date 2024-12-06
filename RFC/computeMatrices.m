function [N_trace] = computeMatrices(x_int_sm, y_int_sm, trace_id, cage_size, bin_size)
% строит карту активности по сырому кальциевому сигналу для бокса УРЗ
% (24х29 см) cage_size = [29 24]

    % Вычисляет матрицы суммированных данных и нормированных данных
    %
    % Входные параметры:
    %   x_int_sm - массив x-координат (1D массив)
    %   y_int_sm - массив y-координат (1D массив)
    %   trace_id - массив значений (например, интенсивность следа) (1D массив)
    %   bin_size - размер бинов (скаляр)
    %
    % Выходные параметры:
    %   N_trace - нормированная матрица данных (размер: SizeMY x SizeMX)
    %   N_frame_orig - матрица временных данных (размер: SizeMY x SizeMX)

    % Проверка корректности входных данных
    if length(x_int_sm) ~= length(y_int_sm) || length(x_int_sm) ~= length(trace_id)
        error('Длины массивов x_int_sm, y_int_sm и trace_id должны совпадать.');
    end

    % Вычисление индексов на основе координат и размера бинов
    x_ind = fix(x_int_sm / bin_size) + 1; 
    y_ind = fix(y_int_sm / bin_size) + 1;

    % Размеры матриц на основе области и размера бинов
    SizeMX = fix(cage_size(1) / bin_size) + 1;
    SizeMY = fix(cage_size(2) / bin_size) + 1;    
    n_frames = length(x_int_sm);

    % Инициализация матриц
    N_trace_sum = zeros(SizeMY, SizeMX);
    N_frame_orig = zeros(SizeMY, SizeMX);

    % Заполнение матрицы суммированных данных
    for d = 1:n_frames
        N_trace_sum(y_ind(d), x_ind(d)) = ...
            N_trace_sum(y_ind(d), x_ind(d)) + trace_id(d);
    end

    % Заполнение матрицы временных данных
    for d = 1:n_frames
        N_frame_orig(y_ind(d), x_ind(d)) = ...
            N_frame_orig(y_ind(d), x_ind(d)) + 1;
    end

    % Нормализация
    N_trace = N_trace_sum ./ N_frame_orig;

    % Установка NaN для деления на 0 (если такие ячейки есть)
    N_trace(isnan(N_trace)) = 0;
end

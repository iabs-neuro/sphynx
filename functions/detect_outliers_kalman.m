function [outliers, innovations, state_means] = detect_outliers_kalman(measurements, varargin)
    % DETECT_OUTLIERS_KALMAN - Обнаружение выбросов в координатах с помощью фильтра Калмана
    %
    % Входные параметры:
    %   measurements - вектор измерений координат [Nx1]
    %   'ProcessNoise' - дисперсия шума процесса (по умолчанию: 0.01)
    %   'ObservationNoise' - дисперсия шума измерений (по умолчанию: 1.0)
    %   'Threshold' - порог для обнаружения выбросов в сигма (по умолчанию: 3.0)
    %   'ModelOrder' - порядок модели (1=позиция, 2=позиция+скорость)
    %
    % Выходные параметры:
    %   outliers - логический вектор выбросов [Nx1]
    %   innovations - инновации (разность между измерением и предсказанием)
    %   state_means - оцененные состояния фильтра

    % Парсинг входных параметров
    p = inputParser;
    addRequired(p, 'measurements', @isnumeric);
    addParameter(p, 'ProcessNoise', 0.01, @isnumeric);
    addParameter(p, 'ObservationNoise', 1.0, @isnumeric);
    addParameter(p, 'Threshold', 3.0, @isnumeric);
    addParameter(p, 'ModelOrder', 1, @(x) ismember(x, [1, 2]));
    
    parse(p, measurements, varargin{:});
    
    % Извлекаем параметры
    measurements = p.Results.measurements(:); % Преобразуем в вектор-столбец
    Q = p.Results.ProcessNoise;
    R = p.Results.ObservationNoise;
    threshold = p.Results.Threshold;
    model_order = p.Results.ModelOrder;
    
    n = length(measurements);
    
    if model_order == 1
        % Модель 1-го порядка (только позиция)
        [outliers, innovations, state_means] = kalman_order1(measurements, Q, R, threshold);
    else
        % Модель 2-го порядка (позиция + скорость)
        [outliers, innovations, state_means] = kalman_order2(measurements, Q, R, threshold);
    end
end
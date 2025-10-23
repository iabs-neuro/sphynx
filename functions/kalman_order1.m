function [outliers, innovations, state_means] = kalman_order1(measurements, Q, R, threshold)
    % KALMAN_ORDER1 - Фильтр Калмана 1-го порядка (только позиция)
    
    n = length(measurements);
    
    % Матрицы модели состояния (позиция)
    F = 1;  % Матрица перехода
    H = 1;  % Матрица наблюдений
    
    % Инициализация
    x = measurements(1);  % Начальное состояние
    P = 1;               % Начальная ковариация ошибки
    
    % Выходные переменные
    state_means = zeros(n, 1);
    innovations = zeros(n, 1);
    innovation_covariances = zeros(n, 1);
    
    for k = 1:n
        % --- Prediction Step ---
        x_pred = F * x;
        P_pred = F * P * F' + Q;
        
        % --- Update Step ---
        innovation = measurements(k) - H * x_pred;
        S = H * P_pred * H' + R;  % Ковариация инноваций
        K = P_pred * H' / S;      % Коэффициент усиления Калмана
        
        x = x_pred + K * innovation;
        P = (1 - K * H) * P_pred;
        
        % Сохраняем результаты
        state_means(k) = x;
        innovations(k) = innovation;
        innovation_covariances(k) = S;
    end
    
    % Обнаружение выбросов на основе инноваций
    innovation_std = sqrt(innovation_covariances);
    normalized_innovations = abs(innovations) ./ innovation_std;
    outliers = normalized_innovations > threshold;
end
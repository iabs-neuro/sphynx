function [outliers, innovations, state_means] = kalman_order2(measurements, Q, R, threshold)
    % KALMAN_ORDER2 - Фильтр Калмана 2-го порядка (позиция + скорость)
    
    n = length(measurements);
    dt = 1;  % Временной шаг (можно адаптировать под вашу частоту дискретизации)
    
    % Матрицы модели состояния [позиция; скорость]
    F = [1, dt; 0, 1];  % Матрица перехода
    H = [1, 0];         % Матрица наблюдений (наблюдаем только позицию)
    
    % Шум процесса
    Q_matrix = Q * [dt^3/3, dt^2/2; dt^2/2, dt];
    
    % Инициализация
    x = [measurements(1); 0];  % [начальная позиция; начальная скорость]
    P = eye(2);               % Начальная ковариация
    
    % Выходные переменные
    state_means = zeros(n, 1);
    innovations = zeros(n, 1);
    innovation_covariances = zeros(n, 1);
    
    for k = 1:n
        % --- Prediction Step ---
        x_pred = F * x;
        P_pred = F * P * F' + Q_matrix;
        
        % --- Update Step ---
        innovation = measurements(k) - H * x_pred;
        S = H * P_pred * H' + R;  % Ковариация инноваций
        K = P_pred * H' / S;      % Коэффициент усиления Калмана
        
        x = x_pred + K * innovation;
        P = (eye(2) - K * H) * P_pred;
        
        % Сохраняем результаты
        state_means(k) = x(1);  % Сохраняем только позицию
        innovations(k) = innovation;
        innovation_covariances(k) = S;
    end
    
    % Обнаружение выбросов
    innovation_std = sqrt(innovation_covariances);
    normalized_innovations = abs(innovations) ./ innovation_std;
    outliers = normalized_innovations > threshold;
end
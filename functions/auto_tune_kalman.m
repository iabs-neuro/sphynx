function params = auto_tune_kalman(coordinates)
    % Анализ данных для автоматического подбора параметров
    
    % Анализ шума измерений
    velocity = diff(coordinates);
    acceleration = diff(velocity);
    
    % Шум измерений (R) оцениваем по высокочастотным колебаниям
    R = std(acceleration) * 0.1;  % Эмпирическая формула
    
    % Шум процесса (Q) оцениваем по изменчивости скорости
    Q = std(velocity) * 0.01;
    
    % Порог для выбросов (адаптивный)
    mad_velocity = median(abs(velocity - median(velocity)));
    threshold = 3.0;  % Начинаем с 3σ
    
    % Выбор порядка модели
    autocorr_value = autocorr(coordinates, 1);
    autocorr_value = autocorr_value(2);  % Первый лаг
    
    if autocorr_value > 0.8
        % Сильная автокорреляция - используем модель 2-го порядка
        model_order = 2;
    else
        % Слабая автокорреляция - модель 1-го порядка
        model_order = 1;
    end
    
    params.Q = max(Q, 0.001);  % Минимальное значение
    params.R = max(R, 0.1);    % Минимальное значение  
    params.threshold = threshold;
    params.model_order = model_order;
    
    fprintf('Автоматически подобранные параметры:\n');
    fprintf('Шум процесса (Q): %.4f\n', params.Q);
    fprintf('Шум измерений (R): %.4f\n', params.R);
    fprintf('Порог: %.1fσ\n', params.threshold);
    fprintf('Порядок модели: %d\n', params.model_order);
end
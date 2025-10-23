%% synthetic data
% Генерация тестовых данных с выбросами
t = 1:18000;
true_trajectory = 10 * sin(t/500) + 5 * cos(t/200); % Истинная траектория
noise = randn(size(t)) * 0.5;                       % Шум измерений
measurements = true_trajectory + noise;

% Добавляем выбросы
outlier_indices = [500, 1500, 3000, 4500, 6000, 7500, 9000];
measurements(outlier_indices) = measurements(outlier_indices) + 20 * randn(size(outlier_indices));

% Обнаружение выбросов
[outliers, innovations, state_means] = detect_outliers_kalman(measurements, ...
    'ProcessNoise', 0.01, ...
    'ObservationNoise', 1.0, ...
    'Threshold', 3.0, ...
    'ModelOrder', 2);

% Визуализация
plot_kalman_results(measurements, outliers, innovations, state_means);

% Статистика
fprintf('Обнаружено выбросов: %d из %d (%.2f%%)\n', ...
    sum(outliers), length(outliers), 100*sum(outliers)/length(outliers));

%% real data
% Шаг 1: Анализ данных
coordinates = BodyPartsTraces(13).TraceOriginal.X  ;
coordinates = BodyPartsTraces(13).TraceOriginal.Y  ;
analyze_data(coordinates);

% Шаг 2: Автоматический подбор параметров
params = auto_tune_kalman(coordinates);

% Шаг 3: Запуск с подобранными параметрами
[outliers, innovations, state_means] = detect_outliers_kalman(coordinates, ...
    'ProcessNoise', params.Q, ...
    'ObservationNoise', params.R, ...
    'Threshold', params.threshold, ...
    'ModelOrder', params.model_order);

% Визуализация
plot_kalman_results(coordinates, outliers, innovations, state_means);

% Шаг 4: Валидация результатов
fprintf('Обнаружено выбросов: %d (%.2f%%)\n', ...
    sum(outliers), 100*sum(outliers)/length(outliers));
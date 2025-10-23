function plot_kalman_results(measurements, outliers, innovations, state_means)
    % PLOT_KALMAN_RESULTS - Визуализация результатов обнаружения выбросов
    
    figure('Position', [100, 100, 1200, 800]);
    
    % График 1: Исходные данные и выбросы
    subplot(3, 1, 1);
    plot(measurements, 'b.-', 'LineWidth', 1, 'MarkerSize', 8);
    hold on;
    plot(find(outliers), measurements(outliers), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    plot(state_means, 'g-', 'LineWidth', 1.5);
    legend('Исходные данные', 'Выбросы', 'Оценка фильтра', 'Location', 'best');
    title('Обнаружение выбросов в координатах животного');
    ylabel('Координата');
    grid on;
    
    % График 2: Инновации
    subplot(3, 1, 2);
    plot(innovations, 'm.-', 'LineWidth', 1);
    hold on;
    plot(find(outliers), innovations(outliers), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    legend('Инновации', 'Выбросы', 'Location', 'best');
    title('Инновации фильтра Калмана');
    ylabel('Инновации');
    grid on;
    
    % График 3: Нормализованные инновации
    subplot(3, 1, 3);
    innovation_std = movstd(innovations, 50); % Скользящее СКО
    normalized_innovations = abs(innovations) ./ innovation_std;
    plot(normalized_innovations, 'k.-', 'LineWidth', 1);
    hold on;
    threshold_line = 3 * ones(size(innovations));
    plot(threshold_line, 'r--', 'LineWidth', 2);
    plot(find(outliers), normalized_innovations(outliers), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    legend('Нормализованные инновации', 'Порог 3σ', 'Выбросы', 'Location', 'best');
    title('Нормализованные инновации');
    ylabel('σ');
    xlabel('Время (отсчеты)');
    grid on;
end
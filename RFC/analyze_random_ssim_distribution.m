function analyze_random_ssim_distribution(n_iterations, map_type, radius, n_bootstrap, sample_size)
% ANALYZE_RANDOM_SSIM_DISTRIBUTION Анализ распределения SSIM для случайных карт
%   n_iterations - количество попарных сравнений карт
%   map_type - тип карты: 'noise' (шум) или 'gaussian' (гауссово пятно)
%   radius - радиус для SSIM
%   n_bootstrap - количество бутстреп-выборок (по умолчанию 1000)
%   sample_size - размер каждой выборки (по умолчанию 4)

    % Параметры по умолчанию
    if nargin < 5
        sample_size = 4; % Размер выборки для среднего
    end
    if nargin < 4
        n_bootstrap = 1000; % Количество бутстреп-выборок
    end
    if nargin < 3
        radius = 1; % Радиус по умолчанию
    end
    if nargin < 2
        map_type = 'noise'; % По умолчанию - случайный шум
    end
    if nargin < 1
        n_iterations = 1000; % По умолчанию 1000 итераций
    end
    
    map_size = [15, 15]; % Размер карты активности
    ssim_values = zeros(n_iterations, 1); % Массив для хранения значений SSIM
    
    % Параметры для гауссова пятна
    gaussian_sigma = 2; % Стандартное отклонение
    
    fprintf('Генерация %d случайных SSIM значений...\n', n_iterations);
    
    % Генерируем и сравниваем случайные карты
    for i = 1:n_iterations
        % Генерируем две случайные карты
        map1 = generate_random_map(map_size, map_type, gaussian_sigma);
        map2 = generate_random_map(map_size, map_type, gaussian_sigma);
        
        % Вычисляем SSIM
        ssim_values(i) = ssim(map1, map2, 'Radius', radius);
        
        % Прогресс-бар
        if mod(i, round(n_iterations/10)) == 0
            fprintf('Выполнено: %d%%\n', round(i/n_iterations*100));
        end
    end
    
    % Вычисляем статистику исходного распределения
    mean_ssim = mean(ssim_values);
    std_ssim = std(ssim_values);
    median_ssim = median(ssim_values);
    
    % БУТСТРЕППИНГ: вычисляем средние для случайных выборок
    fprintf('\nБутстреппинг: %d выборок по %d значений...\n', n_bootstrap, sample_size);
    bootstrap_means = zeros(n_bootstrap, 1);
    
    for i = 1:n_bootstrap
        % Случайная выборка из распределения SSIM
        random_sample = randsample(ssim_values, sample_size, true);
        bootstrap_means(i) = mean(random_sample);
        
        % Прогресс-бар
        if mod(i, round(n_bootstrap/10)) == 0
            fprintf('Бутстреп: %d%%\n', round(i/n_bootstrap*100));
        end
    end
    
    % Статистика бутстреп-распределения
    mean_bootstrap = mean(bootstrap_means);
    std_bootstrap = std(bootstrap_means);
    ci_95 = prctile(bootstrap_means, [2.5, 97.5]); % 95% доверительный интервал
    
    % ВЫВОД РЕЗУЛЬТАТОВ
    fprintf('\n=== РЕЗУЛЬТАТЫ АНАЛИЗА ===\n');
    fprintf('Параметры: %s карты, радиус=%d, N=%d\n', map_type, radius, n_iterations);
    
    fprintf('\nИсходное распределение SSIM:\n');
    fprintf('Среднее: %.4f ± %.4f\n', mean_ssim, std_ssim);
    fprintf('Медиана: %.4f\n', median_ssim);
    fprintf('Диапазон: [%.4f, %.4f]\n', min(ssim_values), max(ssim_values));
    
    fprintf('\nБутстреп-распределение средних (выборки по %d):\n', sample_size);
    fprintf('Среднее средних: %.4f ± %.4f\n', mean_bootstrap, std_bootstrap);
    fprintf('95%% ДИ: [%.4f, %.4f]\n', ci_95(1), ci_95(2));
    fprintf('Диапазон средних: [%.4f, %.4f]\n', min(bootstrap_means), max(bootstrap_means));
    
    % ВИЗУАЛИЗАЦИЯ
    figure('Position', [50, 50, 1200, 800]);
    
    % 1. Исходное распределение SSIM
    subplot(2, 2, 1);
    histogram(ssim_values, 50, 'Normalization', 'probability', ...
             'FaceColor', [0.2, 0.6, 0.8], 'EdgeColor', 'none');
    title(sprintf('Исходное распределение SSIM\n%s, радиус=%d, N=%d', ...
          map_type, radius, n_iterations), 'FontSize', 12);
    xlabel('Значение SSIM', 'FontSize', 10);
    ylabel('Вероятность', 'FontSize', 10);
    grid on;
    xline(mean_ssim, 'r--', 'LineWidth', 2, 'Label', sprintf('μ=%.4f', mean_ssim));
    
    % 2. Бутстреп-распределение средних
    subplot(2, 2, 2);
    histogram(bootstrap_means, 50, 'Normalization', 'probability', ...
             'FaceColor', [0.8, 0.4, 0.2], 'EdgeColor', 'none');
    title(sprintf('Распределение средних (%d выборок по %d)', ...
          n_bootstrap, sample_size), 'FontSize', 12);
    xlabel('Среднее значение SSIM', 'FontSize', 10);
    ylabel('Вероятность', 'FontSize', 10);
    grid on;
    xline(mean_bootstrap, 'r--', 'LineWidth', 2, 'Label', sprintf('μ=%.4f', mean_bootstrap));
    xline(ci_95(1), 'g--', 'LineWidth', 1.5, 'Label', '2.5%');
    xline(ci_95(2), 'g--', 'LineWidth', 1.5, 'Label', '97.5%');
    
    % 3. QQ-plot для проверки нормальности бутстреп-распределения
    subplot(2, 2, 3);
    qqplot(bootstrap_means);
    title('QQ-plot бутстреп-распределения', 'FontSize', 12);
    grid on;
    
    % 4. Сравнение распределений
    subplot(2, 2, 4);
    hold on;
    histogram(ssim_values, 50, 'Normalization', 'pdf', ...
             'FaceColor', [0.2, 0.6, 0.8], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    histogram(bootstrap_means, 50, 'Normalization', 'pdf', ...
             'FaceColor', [0.8, 0.4, 0.2], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    title('Сравнение распределений', 'FontSize', 12);
    xlabel('Значение SSIM', 'FontSize', 10);
    ylabel('Плотность вероятности', 'FontSize', 10);
    legend({'Исходные SSIM', 'Средние SSIM'});
    grid on;
    hold off;
    
    % Сохраняем данные
    results = struct();
    results.ssim_values = ssim_values;
    results.bootstrap_means = bootstrap_means;
    results.stats = struct('mean_original', mean_ssim, 'std_original', std_ssim, ...
                          'mean_bootstrap', mean_bootstrap, 'std_bootstrap', std_bootstrap, ...
                          'ci_95', ci_95, 'sample_size', sample_size);
    
    save(sprintf('ssim_results_%s_r%d.mat', map_type, radius), 'results');
    fprintf('\nРезультаты сохранены в ssim_results_%s_r%d.mat\n', map_type, radius);
end
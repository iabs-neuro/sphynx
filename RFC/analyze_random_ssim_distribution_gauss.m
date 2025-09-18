function analyze_random_ssim_distribution_gauss(n_iterations, map_type, radius, n_bootstrap, sample_size)
% ANALYZE_RANDOM_SSIM_DISTRIBUTION Анализ распределения SSIM для случайных карт
%   n_iterations - количество попарных сравнений карт
%   map_type - тип карты: 'noise' (шум), 'gaussian' (гауссово пятно) или 'gaussian_split' (разделенные гауссовы пятна)
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
    
    % Дополнительные массивы для разделения гауссовых пятен
    if strcmp(map_type, 'gaussian_split')
        ssim_far = []; % Значения SSIM для далеких центров (>5)
        ssim_close = []; % Значения SSIM для близких центров (<3)
        distances = []; % Расстояния между центрами
    end
    
    fprintf('Генерация %d случайных SSIM значений...\n', n_iterations);
    
    % Генерируем и сравниваем случайные карты
    for i = 1:n_iterations
        % Генерируем две случайные карты
        if strcmp(map_type, 'gaussian_split')
            % Для разделения гауссовых пятен нужна информация о центрах
            [map1, center1] = generate_random_map2(map_size, 'gaussian', gaussian_sigma);
            [map2, center2] = generate_random_map2(map_size, 'gaussian', gaussian_sigma);
            
            % Вычисляем расстояние между центрами
            dist = norm(center1 - center2);
            distances = [distances; dist];
            
            % Вычисляем SSIM
            ssim_val = ssim(map1, map2, 'Radius', radius);
            ssim_values(i) = ssim_val;
            
            % Разделяем по расстоянию
            if dist >= 5
                ssim_far = [ssim_far; ssim_val];
            elseif dist <= 3
                ssim_close = [ssim_close; ssim_val];
            end
            
        else
            % Обычная генерация
            map1 = generate_random_map2(map_size, map_type, gaussian_sigma);
            map2 = generate_random_map2(map_size, map_type, gaussian_sigma);
            ssim_values(i) = ssim(map1, map2, 'Radius', radius);
        end
        
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
    
    % Бутстреппинг для разделенных выборок (если есть данные)
    if strcmp(map_type, 'gaussian_split') && ~isempty(ssim_far) && ~isempty(ssim_close)
        % Бутстреппинг для далеких центров
        bootstrap_far = zeros(n_bootstrap, 1);
        for i = 1:n_bootstrap
            random_sample = randsample(ssim_far, min(sample_size, length(ssim_far)), true);
            bootstrap_far(i) = mean(random_sample);
        end
        
        % Бутстреппинг для близких центров
        bootstrap_close = zeros(n_bootstrap, 1);
        for i = 1:n_bootstrap
            random_sample = randsample(ssim_close, min(sample_size, length(ssim_close)), true);
            bootstrap_close(i) = mean(random_sample);
        end
        
        % Статистика бутстреп-распределений
        ci_far = prctile(bootstrap_far, [2.5, 97.5]);
        ci_close = prctile(bootstrap_close, [2.5, 97.5]);
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
    
    % Дополнительная статистика для разделенных гауссовых пятен
    if strcmp(map_type, 'gaussian_split') && ~isempty(ssim_far) && ~isempty(ssim_close)
        fprintf('\n=== ДОПОЛНИТЕЛЬНАЯ СТАТИСТИКА ДЛЯ ГАУССОВЫХ ПЯТЕН ===\n');
        fprintf('Центры дальше 5 единиц (N=%d):\n', length(ssim_far));
        fprintf('  Среднее SSIM: %.4f ± %.4f\n', mean(ssim_far), std(ssim_far));
        fprintf('  Диапазон: [%.4f, %.4f]\n', min(ssim_far), max(ssim_far));
        
        fprintf('Центры ближе 3 единиц (N=%d):\n', length(ssim_close));
        fprintf('  Среднее SSIM: %.4f ± %.4f\n', mean(ssim_close), std(ssim_close));
        fprintf('  Диапазон: [%.4f, %.4f]\n', min(ssim_close), max(ssim_close));  
        
        % Статистический тест
        if length(ssim_far) > 10 && length(ssim_close) > 10
            [~, p] = ttest2(ssim_far, ssim_close);
            fprintf('T-тест: p-value = %.6f\n', p);
            if p < 0.05
                fprintf('  Статистически значимое различие (p < 0.05)\n');
            else
                fprintf('  Различие не статистически значимо\n');
            end
        end
    end
    
    fprintf('\nБутстреп-распределение средних (выборки по %d):\n', sample_size);
    fprintf('Среднее средних: %.4f ± %.4f\n', mean_bootstrap, std_bootstrap);
    fprintf('95%% ДИ: [%.4f, %.4f]\n', ci_95(1), ci_95(2));
    fprintf('Диапазон средних: [%.4f, %.4f]\n', min(bootstrap_means), max(bootstrap_means));
    
    % ВИЗУАЛИЗАЦИЯ
    figure('Position', [50, 50, 1200, 800]);
    
    % 1. Исходное распределение SSIM
    subplot(2, 2, 1);
    hold on;
    histogram(ssim_values, 50, 'Normalization', 'probability', ...
             'FaceColor', [0.2, 0.6, 0.8], 'EdgeColor', 'none');
    
    % Добавляем линии для разделенных гауссовых пятен
    if strcmp(map_type, 'gaussian_split') && ~isempty(ssim_far) && ~isempty(ssim_close)
        xline(mean(ssim_far), 'g--', 'LineWidth', 2, 'Label', 'Далекие центры');
        xline(mean(ssim_close), 'r--', 'LineWidth', 2, 'Label', 'Близкие центры');
    end
    
    title(sprintf('Исходное распределение SSIM\n%s, радиус=%d, N=%d', ...
          map_type, radius, n_iterations), 'FontSize', 12);
    xlabel('Значение SSIM', 'FontSize', 10);
    ylabel('Вероятность', 'FontSize', 10);
    grid on;
    xline(mean_ssim, 'r--', 'LineWidth', 2, 'Label', sprintf('μ=%.4f', mean_ssim));
    hold off;
    
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
    
    % 3. Распределение для ближних и дальних пятен (оригинальные данные)
    subplot(2, 2, 3);
    if strcmp(map_type, 'gaussian_split') && ~isempty(ssim_far) && ~isempty(ssim_close)
        hold on;
        
        % Гистограмма для дальних центров
        histogram(ssim_far, 30, 'Normalization', 'probability', ...
                 'FaceColor', [0, 0.5, 0], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        
        % Гистограмма для близких центров
        histogram(ssim_close, 30, 'Normalization', 'probability', ...
                 'FaceColor', [0.8, 0, 0], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        
        % Линии средних и доверительных интервалов
        xline(mean(ssim_far), 'g-', 'LineWidth', 3, 'Label', sprintf('Дальние: %.3f', mean(ssim_far)));
        xline(mean(ssim_close), 'r-', 'LineWidth', 3, 'Label', sprintf('Ближние: %.3f', mean(ssim_close)));
        
        title('Распределение SSIM для ближних и дальних центров', 'FontSize', 12);
        xlabel('Значение SSIM', 'FontSize', 10);
        ylabel('Вероятность', 'FontSize', 10);
        legend({'Центры >5 ед.', 'Центры <3 ед.'}, 'Location', 'best');
        grid on;
        hold off;
    else
        % Заглушка, если нет данных для разделения
        text(0.5, 0.5, 'Нет данных для разделения', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'Units', 'normalized');
        title('Распределение для ближних/дальних центров', 'FontSize', 12);
        axis off;
    end
    
    % 4. Бутстреп-распределение для ближних и дальних пятен
    subplot(2, 2, 4);
    if strcmp(map_type, 'gaussian_split') && ~isempty(ssim_far) && ~isempty(ssim_close)
        hold on;
        
        % Гистограмма для дальних центров (бутстреп)
        histogram(bootstrap_far, 30, 'Normalization', 'probability', ...
                 'FaceColor', [0, 0.5, 0], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        
        % Гистограмма для близких центров (бутстреп)
        histogram(bootstrap_close, 30, 'Normalization', 'probability', ...
                 'FaceColor', [0.8, 0, 0], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        
        % Линии средних и доверительных интервалов
        xline(mean(bootstrap_far), 'g-', 'LineWidth', 3, 'Label', sprintf('Дальние: %.3f', mean(bootstrap_far)));
        xline(mean(bootstrap_close), 'r-', 'LineWidth', 3, 'Label', sprintf('Ближние: %.3f', mean(bootstrap_close)));
        
        % Доверительные интервалы
        xline(ci_far(1), 'g--', 'LineWidth', 1.5, 'Label', '2.5%');
        xline(ci_far(2), 'g--', 'LineWidth', 1.5, 'Label', '97.5%');
        xline(ci_close(1), 'r--', 'LineWidth', 1.5, 'Label', '2.5%');
        xline(ci_close(2), 'r--', 'LineWidth', 1.5, 'Label', '97.5%');
        
        title(sprintf('Бутстреп-распределение средних\n(выборки по %d)', sample_size), 'FontSize', 12);
        xlabel('Среднее значение SSIM', 'FontSize', 10);
        ylabel('Вероятность', 'FontSize', 10);
        legend({'Центры >5 ед.', 'Центры <3 ед.'}, 'Location', 'best');
        grid on;
        hold off;
    else
        % Заглушка, если нет данных для разделения
        text(0.5, 0.5, 'Нет данных для разделения', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'Units', 'normalized');
        title('Бутстреп для ближних/дальних центров', 'FontSize', 12);
        axis off;
    end
    
    % Сохраняем данные
    results = struct();
    results.ssim_values = ssim_values;
    results.bootstrap_means = bootstrap_means;
    results.stats = struct('mean_original', mean_ssim, 'std_original', std_ssim, ...
                          'mean_bootstrap', mean_bootstrap, 'std_bootstrap', std_bootstrap, ...
                          'ci_95', ci_95, 'sample_size', sample_size);
    
    % Добавляем данные для разделенных гауссовых пятен
    if strcmp(map_type, 'gaussian_split') && ~isempty(ssim_far) && ~isempty(ssim_close)
        results.ssim_far = ssim_far;
        results.ssim_close = ssim_close;
        results.distances = distances;
        results.bootstrap_far = bootstrap_far;
        results.bootstrap_close = bootstrap_close;
        results.stats.mean_far = mean(ssim_far);
        results.stats.std_far = std(ssim_far);
        results.stats.mean_close = mean(ssim_close);
        results.stats.std_close = std(ssim_close);
        results.stats.ci_far = ci_far;
        results.stats.ci_close = ci_close;
    end
    
    save(sprintf('ssim_results_%s_r%d.mat', map_type, radius), 'results');
    fprintf('\nРезультаты сохранены в ssim_results_%s_r%d.mat\n', map_type, radius);
end
function plotMatricesFiringRate(matrix1, matrix2, cell_1, cell_2, days, metric1, metric2, metric_type, nameout)
    % plotMatrices - строит две матрицы рядом, сохраняя их реальные размеры
    % с возможностью отображения разных метрик сравнения
    %
    % Входные параметры:
    %   matrix1 - первая матрица (числовая)
    %   matrix2 - вторая матрица (числовая)
    %   cell - номер нейрона
    %   days - дни экспериментов [day1, day2]
    %   metric1 - первая метрика (r для Пирсона или ssim значение)
    %   metric2 - вторая метрика (p для Пирсона или не используется для ssim)
    %   metric_type - тип метрики: 'pearson' или 'ssim'
    %   nameout - имя файла для сохранения
    %
    % Примеры использования:
    %   Для Пирсона: plotMatricesFiringRate(m1, m2, 5, [1 2], 0.8, 0.01, 'pearson', 'output.png')
    %   Для SSIM: plotMatricesFiringRate(m1, m2, 5, [1 2], 0.95, [], 'ssim', 'output.png')

    % Размеры матриц
    [m1_rows, m1_cols] = size(matrix1);
    [m2_rows, m2_cols] = size(matrix2);

    % Общий размер окна
    figure_width = (m1_cols + m2_cols) * 50; % Ширина окна (50 пикселей на колонку)
    figure_height = max(m1_rows, m2_rows) * 50; % Высота окна (50 пикселей на строку)

    % Создаём окно с заданными размерами
    h = figure('Units', 'pixels', 'Position', [100, 100, figure_width, figure_height]);

    % Используем tiledlayout для размещения двух графиков
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    % Построение первой матрицы
    nexttile;
    imagesc(matrix1); % Визуализация данных
    colorbar; % Панель цвета
    title(sprintf('Карта активности. %d день', days(1)), 'FontWeight', 'normal'); % Убираем жирный шрифт
    xlabel('Сектора, X-координата');
    ylabel('Сектора, Y-координата');
    axis equal; % Сохраняем пропорции
    axis tight; % Убираем лишние поля

    % Построение второй матрицы
    nexttile;
    imagesc(matrix2); % Визуализация данных
    colorbar; % Панель цвета
    title(sprintf('Карта активности. %d день', days(2)), 'FontWeight', 'normal');
    xlabel('Сектора, X-координата');
    ylabel('Сектора, Y-координата');
    axis equal; % Сохраняем пропорции
    axis tight; % Убираем лишние поля

    % Настройка общей цветовой схемы
    colormap('parula'); % Цветовая схема для обеих матриц
    
    % Создание заголовка в зависимости от типа метрики
    switch lower(metric_type)
        case 'pearson'
            title_text = sprintf('Карты активности нейрона %d. Корреляция Пирсона r = %4.3f, p = %0.3g', cell_1, metric1, metric2);
        case 'ssim'
            title_text = sprintf('Карты активности нейрона #%d %d. SSIM = %4.2f', cell_1, cell_2, metric1);
        otherwise
            error('Неизвестный тип метрики. Используйте ''pearson'' или ''ssim''');
    end
    
    % Добавление общего заголовка
    sgtitle(title_text, 'FontSize', 16);    
    saveas(h, nameout);
    delete(h);
end
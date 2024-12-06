function plotMatrices(matrix1, matrix2, cell, r, p, nameout)
    % plotMatrices - строит две матрицы рядом, сохраняя их реальные размеры
    %
    % Входные параметры:
    %   matrix1 - первая матрица (числовая)
    %   matrix2 - вторая матрица (числовая)
    %
    % Пример использования:
    %   plotMatrices(rand(9, 10), rand(9, 10));

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
    title('Карта активности. Предэкспозиция', 'FontWeight', 'normal'); % Убираем жирный шрифт
    xlabel('Сектора, X-координата');
    ylabel('Сектора, Y-координата');
    axis equal; % Сохраняем пропорции
    axis tight; % Убираем лишние поля

    % Построение второй матрицы
    nexttile;
    imagesc(matrix2); % Визуализация данных
    colorbar; % Панель цвета
    title('Карта активности. Тест', 'FontWeight', 'normal');
    xlabel('Сектора, X-координата');
    ylabel('Сектора, Y-координата');
    axis equal; % Сохраняем пропорции
    axis tight; % Убираем лишние поля

    % Настройка общей цветовой схемы
    colormap('parula'); % Цветовая схема для обеих матриц
    
    % Добавление общего заголовка
    sgtitle(sprintf('Карты активности нейрона %d. Корреляция Пирсона r = %2.1f, p = %0.3g',cell,r,p), 'FontSize', 16);    
    saveas(h, nameout);
    delete(h);
    end

function plotMatricesTraceRate(varargin)
    % plotMatricesTraceRate - строит несколько матриц активности нейронов рядом
    % с возможностью отображения метрик сравнения (Пирсон или SSIM)
    %
    % Входные параметры:
    %   matrices        - массив матриц (например, {matrix1, matrix2, matrix3})
    %   cell_numbers    - номера нейронов (например, [5, 7, 10])
    %   days            - дни экспериментов (например, [1, 2, 3])
    %   metric_type     - тип метрики: 'pearson' или 'ssim'
    %   metric_values   - метрики (для Пирсона: [r1,p1,r2,p2,...], для SSIM: [ssim1,ssim2,...])
    %   nameout         - имя файла для сохранения
    %
    % Примеры использования:
    %   Для Пирсона (3 дня):
    %     plotMatricesTraceRate({m1,m2,m3}, [5,5,5], [1,2,3], 'pearson', [0.8,0.01,0.7,0.02], 'output.png')
    %   Для SSIM (3 дня):
    %     plotMatricesTraceRate({m1,m2,m3}, [5,5,5], [1,2,3], 'ssim', [0.95,0.92], 'output.png')

    % Проверка входных данных
    if nargin < 6
        error('Недостаточно входных аргументов!');
    end

    matrices = varargin{1}; % Ячейка с матрицами
    cell_numbers = varargin{2}; % Номера нейронов
    days = varargin{3}; % Дни экспериментов
    metric_type = lower(varargin{4}); % Тип метрики
    metric_values = varargin{5}; % Метрики
    nameout = varargin{6}; % Имя файла

    num_matrices = length(matrices);
    if num_matrices < 2
        error('Нужно минимум 2 матрицы!');
    end

    % Проверка размеров
    if length(cell_numbers) ~= num_matrices || length(days) ~= num_matrices
        error('Количество нейронов и дней должно совпадать с количеством матриц!');
    end

    % Проверка количества метрик
    switch metric_type
        case 'pearson'
            required_metrics = 2*(num_matrices-1);
            if length(metric_values) ~= required_metrics
                error('Для Пирсона нужно %d метрик (r и p для каждой пары)!', required_metrics);
            end
        case 'ssim'
            required_metrics = num_matrices-1;
            if length(metric_values) ~= required_metrics
                error('Для SSIM нужно %d метрик (по одной на каждую пару)!', required_metrics);
            end
        otherwise
            error('Неизвестный тип метрики. Используйте ''pearson'' или ''ssim''.');
    end
    
    % Проверяем и выравниваем размеры всех матриц
    if num_matrices > 1
        % Находим минимальные размеры по всем матрицам
        min_rows = Inf;
        min_cols = Inf;
        for i = 1:num_matrices
            [rows, cols] = size(matrices{i});
            if rows < min_rows
                min_rows = rows;
            end
            if cols < min_cols
                min_cols = cols;
            end
        end
        
        % Проверяем, нужно ли изменять размеры
        need_resize = false;
        for i = 1:num_matrices
            if ~isequal(size(matrices{i}), [min_rows, min_cols])
                need_resize = true;
                break;
            end
        end
        
        % Если нужно, изменяем размеры всех матриц
        if need_resize
            disp('Матрицы разного размера. Выравниваем до минимального общего размера:');
            disp(['Новый размер: [' num2str(min_rows) ' ' num2str(min_cols) ']']);
            
            for i = 1:num_matrices
                original_size = size(matrices{i});
                if ~isequal(original_size, [min_rows, min_cols])
                    disp(['Матрица ' num2str(i) ': исходный размер [' num2str(original_size) ']']);
                    matrices{i} = matrices{i}(1:min_rows, 1:min_cols);
                end
            end
        end
    end
    

    % Определяем общий размер окна и общий масштаб цветовой шкалы
    total_cols = 0;
    max_rows = 0;
    all_data = [];
    for i = 1:num_matrices
        [rows, cols] = size(matrices{i});
        total_cols = total_cols + cols;
        if rows > max_rows
            max_rows = rows;
        end
        all_data = [all_data; matrices{i}(:)];
    end
    
    % Определяем общие пределы цветовой шкалы
    cmin = min(all_data);
    cmax = max(all_data);

    % Размеры окна (50 пикселей на колонку/строку)
    figure_width = total_cols * 50 + 100; % +100 для цветовой шкалы
    figure_height = max_rows * 50;

    % Создаём окно
    h = figure('Units', 'pixels', 'Position', [100, 100, figure_width, figure_height]);

    % Используем tiledlayout для размещения графиков
    t = tiledlayout(1, num_matrices+1, 'Padding', 'compact', 'TileSpacing', 'compact');
    t.TileSpacing = 'compact';
    t.Padding = 'compact';

    % Построение каждой матрицы
    for i = 1:num_matrices
        nexttile;
        imagesc(matrices{i}, [cmin cmax]);
        axis equal tight;
        xlabel('Сектора, X-координата');
        ylabel('Сектора, Y-координата');
        
        % Добавляем метрики в заголовок
        switch metric_type
            case 'pearson'
                if i > 1
                    idx_r = 2*(i-2)+1;
                    idx_p = 2*(i-2)+2;
                    title(sprintf('День %d\nr=%.2f p=%.2g', days(i), ...
                        metric_values(idx_r), metric_values(idx_p)), 'FontWeight', 'normal');
                else
                    title(sprintf('День %d', days(i)), 'FontWeight', 'normal');
                end
            case 'ssim'
                if i > 1
                    title(sprintf('День %d\nSSIM=%.2f', days(i), metric_values(i-1)), 'FontWeight', 'normal');
                else
                    title(sprintf('День %d\nSSIM= ..', days(i)), 'FontWeight', 'normal');
                end
        end
    end

    % Создаем отдельные оси для цветовой шкалы
    cbar_ax = axes('Position', [0.85, 0.20, 0.02, 0.7]); % [left, bottom, width, height]
    caxis([cmin cmax]);
    
    % Создаем цветовую шкалу с уменьшенной высотой
    c = colorbar(cbar_ax, 'Location', 'west');
    c.Position = [0.85, 0.2, 0.01, 0.6]; % Уменьшаем высоту до 40%
    
    % Настраиваем внешний вид
    colormap(cbar_ax, 'parula');
    cbar_ax.Visible = 'off';  % Скрываем оси, оставляя только цветовую шкалу
    
    % Делаем шкалу цветной и контрастной
    set(c, 'Color', [0 0 0]);  % Черный цвет для текста и линий
    set(c, 'FontWeight', 'bold');
    set(c, 'Box', 'on');
    set(c, 'LineWidth', 1);

    % Создание общего заголовка
    if numel(unique(cell_numbers)) == 1
        title_text = sprintf('Карты активности нейрона %d', cell_numbers(1));
    else
        title_text = sprintf('Карты активности нейрона %s', mat2str(cell_numbers));
    end
    sgtitle(title_text, 'FontSize', 16);

    % Сохранение и закрытие
    saveas(h, nameout);
    delete(h);
end
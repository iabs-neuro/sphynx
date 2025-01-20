function [statsText] = plotCorrelationWithStats(x, y, color, markerSize, mode)

    % Параметры
    if nargin < 3 || isempty(color)
        color = 'k';                                    % Цвет по умолчанию — синий
    end
    if nargin < 4 || isempty(markerSize)
        markerSize = 10;                                % Размер точек по умолчанию
    end
    if nargin < 5 || isempty(markerSize)
        mode = 'abs';                                   % Размер точек по умолчанию
    end

    % Построение графика
    scatter(x, y, markerSize, color, 'filled');
    hold on;
    
    switch mode
        case 'equal'
            % Извлечение текущих границ осей
            xLimits = get(gca, 'XLim'); % Границы оси X
            yLimits = get(gca, 'YLim'); % Границы оси Y

            % Вычисление общего размаха
            minLimit = min([xLimits(1), yLimits(1)]); % Минимум для обеих осей
            maxLimit = max([xLimits(2), yLimits(2)]); % Максимум для обеих осей

            % Установка симметричных границ
            set(gca, 'XLim', [minLimit, maxLimit]);
            set(gca, 'YLim', [minLimit, maxLimit]);

            % Установка равных масштабов для осей
%             set(gca, 'LooseInset', get(gca, 'TightInset')); % Убирает лишние отступы
%             axis equal;
        case 'abs'
            
    end
    
    % Линейная регрессия
    coeffs = polyfit(x, y, 1);
    yFit = polyval(coeffs, x);
    plot(x, yFit, 'r-', 'LineWidth', 2);                % Линия регрессии

    % Расчёт корреляции и статистики
    [r, p] = corr(x(:), y(:), 'Type', 'Pearson');       % Коэффициент корреляции и p-value
    SSres = sum((y - yFit).^2);                         % Остаточная сумма квадратов
    SStot = sum((y - mean(y)).^2);                      % Общая сумма квадратов
    R2 = 1 - SSres / SStot;                             % Коэффициент детерминации

    % Отображение статистики на графике
    statsText = sprintf('r = %.3f\np-value = %.1e\nR^2 = %.3f', r, p, R2);
    
end

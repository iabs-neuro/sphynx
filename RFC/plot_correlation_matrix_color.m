function plot_correlation_matrix_color(corrMatrix, labels, normalizationMethod)
    % Проверяем, что матрица квадратная
    [rows, cols] = size(corrMatrix);
    if rows ~= cols
        error('Матрица корреляций должна быть квадратной.');
    end
    
    % Создаем копию матрицы, чтобы оставить диагональные элементы нетронутыми
    corrMatrixNoDiag = corrMatrix;
    corrMatrixNoDiag(eye(rows) == 1) = NaN; % Исключаем диагональ
    
    % Определяем границы нормировки цветовой карты
    switch normalizationMethod
        case 'zero_to_max'
            colorLimits = [0, max(corrMatrixNoDiag(:), [], 'omitnan')]; % От 0 до максимума (без диагонали)
        case 'min_to_max'
            colorLimits = [min(corrMatrixNoDiag(:), [], 'omitnan'), max(corrMatrixNoDiag(:), [], 'omitnan')]; % Полный диапазон
        case 'zero_to_one'
            colorLimits = [0, 1]; % Фиксированный диапазон от 0 до 1
        case 'neg_one_to_one'
            colorLimits = [-1, 1]; % Фиксированный диапазон от -1 до 1
        otherwise
            error('Неизвестный метод нормировки. Используйте "zero_to_max", "min_to_max", "zero_to_one" или "neg_one_to_one".');
    end
    
    % Визуализация
    figure;
    imagesc(corrMatrix, 'AlphaData', ~eye(rows)); % Оставляем диагональ прозрачной
    colormap(jet); % Цветовая карта
    colorbar; % Добавляем шкалу значений
    caxis(colorLimits); % Применяем выбранные границы
    
    % Закрашиваем диагональ серым
    hold on;
    for i = 1:rows
        rectangle('Position', [i-0.5, i-0.5, 1, 1], 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'none');
    end
    hold off;

    % Устанавливаем подписи осей
    xticks(1:cols); yticks(1:rows);
    xticklabels(labels); yticklabels(labels);
    set(gca, 'FontSize', 12, 'FontWeight', 'bold', 'XTickLabelRotation', 45);

    % Добавляем числовые значения корреляций
    for i = 1:rows
        for j = 1:cols
            if i ~= j  % Не наносим числа на диагональ
                text(j, i, sprintf('%.2f', corrMatrix(i, j)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
                    'Color', 'w');
            end
        end
    end

    title('Correlation Matrix', 'FontSize', 14, 'FontWeight', 'bold');
end

function plot_correlation_matrix(corrMatrix, labels)
    % Проверяем, что матрица квадратная
    [rows, cols] = size(corrMatrix);
    if rows ~= cols
        error('Матрица корреляций должна быть квадратной.');
    end

    % Визуализация
    figure;
    imagesc(corrMatrix);  
    colormap(jet); % Цветовая карта
    colorbar; % Добавляем шкалу значений
    caxis([-1, 1]); % Устанавливаем диапазон цветов от -1 до 1

    % Устанавливаем подписи осей
    xticks(1:cols); yticks(1:rows);
    xticklabels(labels); yticklabels(labels);
    set(gca, 'FontSize', 12, 'FontWeight', 'bold', 'XTickLabelRotation', 45);

    % Добавляем числовые значения корреляций
    for i = 1:rows
        for j = 1:cols
            text(j, i, sprintf('%.2f', corrMatrix(i, j)), ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Color', 'w');
        end
    end

    title('Correlation Matrix', 'FontSize', 14, 'FontWeight', 'bold');
end

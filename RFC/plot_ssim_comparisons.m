function mean_ssim = plot_ssim_comparisons(ssim_neurons, nameout)
    % Проверка входных данных
    if size(ssim_neurons, 2) ~= 4
        error('Матрица должна содержать 4 столбца сравнений (n×4)');
    end
    
    % Создаем фигуру
    h = figure('Position', [100, 100, 800, 500]);
    
    % Параметры графика
    num_neurons = size(ssim_neurons, 1);
    num_comparisons = size(ssim_neurons, 2);
    x_labels = {'1D-2D', '2D-3D', '3D-4D', '4D-5D'};
    x_labels = x_labels(1:num_comparisons); % Обрезаем если сравнений меньше 4
    
    % Рисуем индивидуальные нейроны (полупрозрачные линии)
    hold on;
    for i = 1:num_neurons
        plot(1:num_comparisons, ssim_neurons(i,:), ...
             'Color', [0.5 0.5 0.5 0.3], 'LineWidth', 1);
    end
    
    % Рисуем среднее значение (толстая синяя линия)
    mean_ssim = mean(ssim_neurons, 1);
    plot(1:num_comparisons, mean_ssim, ...
         'b-o', 'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
     
  	% Рисуем линию случаной стабильности
    line([1 num_comparisons], [0.2 0.2], 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2); % Красная пунктирная линия на уровне Y=50
    
    % Добавляем доверительные интервалы (стандартное отклонение)
    std_ssim = std(ssim_neurons, 0, 1);
    errorbar(1:num_comparisons, mean_ssim, std_ssim, ...
             'b', 'LineStyle', 'none', 'LineWidth', 2);
    
    % Настройка осей и легенды
    xlim([0.5 num_comparisons+0.5]);
    ylim([0 1]);
    xticks(1:num_comparisons);
    xticklabels(x_labels);
    ylabel('SSIM');
%     xlabel('Сравнение дней');
    title('Похожесть карт активности нейронов');
    grid on;
    
    
    % Дополнительная информация на графике
    text(0.6, 0.9, sprintf('Всего нейронов: %d\nДанные представлены как\nmean±std', num_neurons), ...
         'FontSize', 10, 'Color', 'k');
     
   	% Сохранение и закрытие
    saveas(h, nameout);
    delete(h);
    
end
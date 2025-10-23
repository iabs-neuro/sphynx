function analyze_data(coordinates)
    figure('Position', [100, 100, 1200, 600]);
    
    % График координат
    subplot(2,2,1);
    plot(coordinates, 'b.-');
    title('Исходные координаты');
    ylabel('Координата');
    grid on;
    
    % Гистограмма
    subplot(2,2,2);
    histogram(coordinates, 50);
    title('Распределение координат');
    xlabel('Координата');
    ylabel('Частота');
    
    % Скорость (первая разность)
    subplot(2,2,3);
    velocity = diff(coordinates);
    plot(velocity, 'g.-');
    title('Скорость изменения (первая разность)');
    ylabel('Δ координата');
    grid on;
    
    % Автокорреляция
    subplot(2,2,4);
    autocorr(coordinates, 100);
    title('Автокорреляция координат');
    
    % Вывод статистик
    fprintf('Статистики координат:\n');
    fprintf('Среднее: %.3f\n', mean(coordinates));
    fprintf('Стандартное отклонение: %.3f\n', std(coordinates));
    fprintf('Медиана: %.3f\n', median(coordinates));
    fprintf('Максимум: %.3f\n', max(coordinates));
    fprintf('Минимум: %.3f\n', min(coordinates));
    
    fprintf('\nСтатистики скорости:\n');
    fprintf('Средняя скорость: %.3f\n', mean(abs(velocity)));
    fprintf('Макс. скорость: %.3f\n', max(abs(velocity)));
    fprintf('СКО скорости: %.3f\n', std(velocity));
end
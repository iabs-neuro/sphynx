function [velocity, mean_velocity, total_distance, total_height_up, total_height_down, total_height] = analyze_movement_3D(MouseCenterX, MouseCenterY, MouseCenterZ, time, SmoothWindow)
% ANALYZE_MOVEMENT Анализирует движение животного по координатам
%
% Входные параметры:
%   MouseCenterX, MouseCenterY, MouseCenterZ - координаты в см
%   time - вектор времени в секундах
%
% Выходные параметры:
%   velocity - мгновенная скорость (см/с) в каждый момент времени
%   mean_velocity - средняя скорость за весь период (см/с)
%   total_distance - общее пройденное расстояние (см)
%   total_height - общий набор высоты (см)

    % Проверка входных данных
    if nargin < 4
        error('Необходимо указать все 4 входных параметра');
    end
    
    if length(MouseCenterX) ~= length(time) || length(MouseCenterY) ~= length(time) || length(MouseCenterZ) ~= length(time)
        error('Все векторы должны быть одинаковой длины');
    end

    % Вычисление разностей координат и времени
    dx = diff(MouseCenterX);
    dy = diff(MouseCenterY);
    dz = diff(MouseCenterZ);
    dt = diff(time);
    
    % Проверка на нулевые интервалы времени
    if any(dt <= 0)
        error('Временные точки должны быть строго возрастающими');
    end
    
    % Мгновенная скорость (см/с)
    velocity = sqrt(dx.^2 + dy.^2 + dz.^2) ./ dt;
    velocity = [0, velocity]; % Добавляем нулевую скорость в начальный момент
    
    velocity = smooth(velocity,SmoothWindow,'sgolay',3);
    velocity = max(0, min(50, velocity));
    
    % Средняя скорость за весь период
    mean_velocity = mean(velocity(2:end)); % Исключаем начальный нуль
    
    % Общее пройденное расстояние
    total_distance = sum(sqrt(dx.^2 + dy.^2 + dz.^2));
    
    % Общий набор высоты (только положительные изменения по Z)
    dz_positive = dz(dz > 0);
    total_height_up = sum(dz_positive);
    
    % Общий спуск высоты (только отрицательные изменения по Z)
    dz_negative = dz(dz < 0);
    total_height_down = sum(dz_negative);
    
    % Общий пройденный путь по Z
    total_height = total_height_up-total_height_down;
    
    % Дополнительный вывод информации
    fprintf('Анализ движения завершен:\n');
    fprintf(' - Средняя скорость: %.1f см/с\n', mean_velocity);
    fprintf(' - Общее пройденное расстояние: %.0f см\n', total_distance);
    fprintf(' - Общий набор высоты: %.0f см\n', total_height_up);
    fprintf(' - Общий спуск высоты: %.0f см\n', total_height_down);
    fprintf(' - Общее расстояние по Z: %.0f см\n', total_height);
    
end
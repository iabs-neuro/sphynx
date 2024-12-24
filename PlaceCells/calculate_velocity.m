function [mouse] = calculate_velocity(mouse)
    % calculate_velocity - Вычисляет скорость, сглаживает её и генерирует бинарный результат
    % 
    % Входные параметры:
    % mouse - структура со всеми параметрами и координатами
    %
    % Выходные параметры:
    % vel - несглаженная скорость
    % vel_sm - сглаженная скорость
    % vel_sm_line - бинарный массив после пороговой обработки
    % vel_ref - уточнённый бинарный массив после RefineLine
    
    % Инициализация скорости
    vel = zeros(1, mouse.duration_frames);
    
    % Вычисление скорости
    for i = 2:mouse.duration_frames
        vel(i) = sqrt((mouse.x(i) - mouse.x(i-1))^2 + (mouse.y(i) - mouse.y(i-1))^2) * mouse.framerate;
    end
    vel(1) = vel(2);
    
    % Сглаживание скорости
    mouse.velocity = smooth(vel, mouse.params_main.SmoothWindow);
    
    % Бинаризация на основе порога
    vel_sm_line = zeros(1, mouse.duration_frames);
    vel_sm_line(mouse.velocity >= mouse.params_main.vel_border) = 1;
    
    % Уточнение бинарного массива с помощью RefineLine
    [mouse.velocity_binary, ~, ~, ~, ~, ~] = RefineLine(vel_sm_line, mouse.params_main.length_line, mouse.params_main.length_line);
end

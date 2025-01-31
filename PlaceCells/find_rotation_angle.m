function angle = find_rotation_angle(point1, point2)
    % findLineAngle - вычисляет угол наклона прямой через две точки.
    % 
    % Входные аргументы:
    %   point1: Координаты первой точки [x1, y1]
    %   point2: Координаты второй точки [x2, y2]
    %
    % Выходной аргумент:
    %   angle: Угол наклона прямой относительно оси X (в градусах)
    
    % Извлечение координат
    x1 = point1(1); y1 = point1(2);
    x2 = point2(1); y2 = point2(2);
    
    % Разница координат
    deltaX = x2 - x1;
    deltaY = y2 - y1;
    
    % Вычисление угла (в радианах)
    angle_rad = atan2(deltaY, deltaX);
    
    % Перевод угла в градусы
    angle = rad2deg(angle_rad);
end

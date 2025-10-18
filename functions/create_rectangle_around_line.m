function [rect_x, rect_y] = create_rectangle_around_line(x1, y1, x2, y2, offset, num_points)
    % Функция создает прямоугольник вокруг удлиненной прямой
    %
    % Входные параметры:
    % x1, y1 - координаты первой точки
    % x2, y2 - координаты второй точки
    % offset - половина ширины прямоугольника и величина удлинения прямой
    % num_points - количество точек для аппроксимации прямой (по умолчанию 1000)
    %
    % Выходные параметры:
    % rect_x - x-координаты вершин прямоугольника (5 точек, включая замыкающую)
    % rect_y - y-координаты вершин прямоугольника (5 точек, включая замыкающую)

    % Установка значений по умолчанию
    if nargin < 5
        offset = 20;
    end
    if nargin < 6
        num_points = 20000;
    end

    % 1. Вычисляем направляющий вектор прямой
    dx = x2 - x1;
    dy = y2 - y1;
    
    % 2. Нормализуем направляющий вектор
    length = sqrt(dx^2 + dy^2);
    if length > 0
        dx = dx / length;
        dy = dy / length;
    else
        error('Точки совпадают, нельзя построить прямую');
    end
    
    % 3. Удлиняем прямую на offset с каждого конца
    extended_x1 = x1 - dx * offset;
    extended_y1 = y1 - dy * offset;
    extended_x2 = x2 + dx * offset;
    extended_y2 = y2 + dy * offset;
    
    % 4. Получаем координаты точек на удлиненной прямой (осевая линия)
    t_line = linspace(0, 1, num_points)';
    line_x = extended_x1 + t_line * (extended_x2 - extended_x1);
    line_y = extended_y1 + t_line * (extended_y2 - extended_y1);

    % 5. Вычисляем перпендикулярный вектор (для смещения)
    perp_dx = -dy;
    perp_dy = dx;

    % 6. Создаем верхнюю и нижнюю стороны прямоугольника
    upper_x = line_x + perp_dx * offset;
    upper_y = line_y + perp_dy * offset;
    lower_x = line_x - perp_dx * offset;
    lower_y = line_y - perp_dy * offset;

    % 7. Создаем левую и правую стороны прямоугольника
    % Левая сторона (от нижней точки к верхней)
    t_side = linspace(0, 1, num_points)';
    left_x = lower_x(1) + t_side * (upper_x(1) - lower_x(1));
    left_y = lower_y(1) + t_side * (upper_y(1) - lower_y(1));
    
    % Правая сторона (от верхней точки к нижней)
    right_x = upper_x(end) + t_side * (lower_x(end) - upper_x(end));
    right_y = upper_y(end) + t_side * (lower_y(end) - upper_y(end));

    % 8. Формируем полный прямоугольник (с замыканием)
    % Порядок обхода: 
    % 1) левая сторона (снизу вверх)
    % 2) верхняя сторона (слева направо)
    % 3) правая сторона (сверху вниз)
    % 4) нижняя сторона (справа налево)
    % 5) замыкаем в начальную точку
    
    rect_x = [left_x; upper_x; right_x; lower_x(end:-1:1); left_x(1)];
    rect_y = [left_y; upper_y; right_y; lower_y(end:-1:1); left_y(1)];end
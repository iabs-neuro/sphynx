function mouse = calculateBinaryMatrix(mouse)
if mouse.arena_opt.geometry == "Polygon"
mouse.behav_opt.bin_map_mask = 
    mouse.behav_opt.bin_map_mask = 
end
    
% Размеры маски
[mask_height, mask_width] = size(mouse.arena_opt.maskfilled);

% Создаем координатную сетку
[x_grid, y_grid] = meshgrid(1:mask_width, 1:mask_height);

% Определяем вершины полигона (если это квадрат под углом)
polygon_vertices = bwboundaries(ArenaAndObjects(1).maskborder{1});
polygon_vertices = polygon_vertices{1}; % Получаем координаты вершин

% Проверяем, какие точки находятся внутри полигона
in_poly = inpolygon(x_grid, y_grid, polygon_vertices(:,2), polygon_vertices(:,1));

% Генерация бинарной маски для области внутри полигона
binary_inside = in_poly & mouse.arena_opt.maskfilled;

% Бинаризация внутри полигона
bin_size = mouse.bin_size; % Размер бина
x_min = 1;
y_min = 1;

% Генерация индексов бинов
x_bin = fix((x_grid - x_min) / bin_size) + 1;
y_bin = fix((y_grid - y_min) / bin_size) + 1;

% Применяем бинаризацию только для точек внутри полигона
x_bin(~binary_inside) = NaN;
y_bin(~binary_inside) = NaN;

% Отображаем результаты
figure;
subplot(1, 2, 1);
imagesc(mouse.arena_opt.maskfilled); 
title('Исходная маска');
axis equal;

subplot(1, 2, 2);
imagesc(binary_inside);
title('Бинаризированная область');
axis equal;

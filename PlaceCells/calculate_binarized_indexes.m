function mouse = calculate_binarized_indexes(mouse)

% point_origin - translation vector ib cm

% распаковка параметров
heatmap_border = mouse.params_main.heatmap_border;
bin_size_cm = mouse.params_main.bin_size_cm;

x = mouse.x;
y = mouse.y;

% не нужно подгонять размер бина под арену, т.к. много измерений может быть
% bin_count = fix(abs(mouse.behav_opt.arena_border.left(1) - mouse.behav_opt.arena_border.right(1))/mouse.behav_opt.pxl2sm/bin_size_cm);
% bin_size_cm_reshaped = abs(mouse.behav_opt.arena_border.left(1) - mouse.behav_opt.arena_border.right(1))/mouse.behav_opt.pxl2sm/bin_size_cm);
% mouse.behav_opt.arena_border.top(2)

% find a Origin Point and Rotation angle for HeatMaps
if mouse.arena_opt.geometry == "Circle" && mouse.exp == "FOF"
    
    % для круговой арены и FOF режим только трансляции
    mouse.behav_opt.point_origin = [
        mouse.behav_opt.arena_border.left(1)/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr - heatmap_border*bin_size_cm ...
        mouse.behav_opt.arena_border.bottom(2)/mouse.behav_opt.pxl2sm - heatmap_border*bin_size_cm
        ];
    [x_transformed, y_transformed] = coordinate_transform(x, y, mouse.behav_opt.point_origin, 0, 'translation', 'Forward');
    [x_arena_transformed, y_arena_transformed] = coordinate_transform(mouse.arena_opt.border_x/mouse.behav_opt.pxl2sm, mouse.arena_opt.border_y/mouse.behav_opt.pxl2sm, mouse.behav_opt.point_origin, 0, 'translation', 'Forward');
    
elseif mouse.arena_opt.geometry == "Polygon" && mouse.exp == "MSS"
    
    % для квадратной арены и MSS режим только трансляции
    mouse.behav_opt.point_origin = [
        mouse.arena_opt.border_separate_x(1) ...
        mouse.arena_opt.border_separate_y(1)
        % Добавить дополнительный бин по краям уже после поворота
        ];
    
    find_rotation_angle();
    
    [x_transformed, y_transformed] = coordinate_transform(x, y, mouse.behav_opt.point_origin, 0, 'both', 'Forward');
end

% Генерация индексов бинов
x_ind = fix(x_transformed / bin_size_cm) + 1;
y_ind = fix(y_transformed / bin_size_cm) + 1;

max_x_ind = fix((max(x_arena_transformed) + heatmap_border*bin_size_cm)/bin_size_cm)+1;
max_y_ind = fix((max(y_arena_transformed) + heatmap_border*bin_size_cm)/bin_size_cm)+1;
min_x_ind = 1;
min_y_ind = 1;

mouse.SizeMY = (max_y_ind-min_y_ind)+1;
mouse.SizeMX = (max_x_ind-min_x_ind)+1;

mouse.x_ind = x_ind;
mouse.y_ind = y_ind;

mouse.x_transformed = x_transformed;
mouse.y_transformed = y_transformed;

mouse.shift = [mouse.behav_opt.point_origin(1)*mouse.behav_opt.pxl2sm/mouse.behav_opt.x_kcorr mouse.behav_opt.point_origin(2)*mouse.behav_opt.pxl2sm]; % in original pxles


end
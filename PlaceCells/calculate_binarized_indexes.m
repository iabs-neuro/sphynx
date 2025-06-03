function mouse = calculate_binarized_indexes(mouse)

% point_origin - translation vector in cm

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
if mouse.arena_opt(1).geometry == "Circle" && mouse.exp == "FOF"
    
    % для круговой арены и FOF режим только трансляции
    mouse.behav_opt.point_origin = [
        mouse.behav_opt.arena_border.left(1)/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr - heatmap_border*bin_size_cm ...
        mouse.behav_opt.arena_border.bottom(2)/mouse.behav_opt.pxl2sm - heatmap_border*bin_size_cm
        ];
    [x_transformed, y_transformed] = coordinate_transform(x, y, mouse.behav_opt.point_origin, 0, 'translation', 'Forward');
    [x_arena_transformed, y_arena_transformed] = coordinate_transform(mouse.arena_opt(1).border_x/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr, mouse.arena_opt(1).border_y/mouse.behav_opt.pxl2sm, mouse.behav_opt.point_origin, 0, 'translation', 'Forward');
    
elseif mouse.arena_opt(1).geometry == "Polygon" && (mouse.exp == "MSS" || mouse.exp == "NOF")
    
    % для квадратной арены и MSS режим трансляции и поворота
    mouse.behav_opt.point_origin = [
        mouse.arena_opt(1).border_separate_x{1}(1)/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr ...  
        mouse.arena_opt(1).border_separate_y{1}(1)/mouse.behav_opt.pxl2sm
        ];    
%     imshow(mouse.behav_opt.GoodVideoFrame); hold on; plot(mouse.behav_opt.point_origin(1),mouse.behav_opt.point_origin(2), 'r*')
    
    angle = find_rotation_angle([mouse.arena_opt(1).border_separate_y{1}(1), mouse.arena_opt(1).border_separate_x{1}(1)], ...
        [mouse.arena_opt(1).border_separate_y{4}(1), mouse.arena_opt(1).border_separate_x{4}(1)]);

    [x_transformed1, y_transformed1] = coordinate_transform(x, y, mouse.behav_opt.point_origin, deg2rad(angle), 'both', 'Forward');
%     plot(x_transformed1, y_transformed1);
    [x_transformed, y_transformed] = coordinate_transform(x_transformed1, y_transformed1, [-heatmap_border*bin_size_cm, -heatmap_border*bin_size_cm], 0, 'translation', 'Forward');

    [x_arena_transformed, y_arena_transformed] = coordinate_transform(mouse.arena_opt(1).border_x/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr, mouse.arena_opt(1).border_y/mouse.behav_opt.pxl2sm, mouse.behav_opt.point_origin, deg2rad(angle), 'both', 'Forward');
    [x_arena_transformed, y_arena_transformed] = coordinate_transform(x_arena_transformed, y_arena_transformed, [-heatmap_border*bin_size_cm, -heatmap_border*bin_size_cm], 0, 'translation', 'Forward');
    
end

% Генерация индексов бинов
x_ind = fix(x_transformed / bin_size_cm) + 1;
y_ind = fix(y_transformed / bin_size_cm) + 1;

max_x_ind = fix((max(x_arena_transformed) + heatmap_border*bin_size_cm)/bin_size_cm)+1;
max_y_ind = fix((max(y_arena_transformed) + heatmap_border*bin_size_cm)/bin_size_cm)+1;
min_x_ind = 1;
min_y_ind = 1;

mouse.size_map(1) = (max_y_ind-min_y_ind)+1;
mouse.size_map(2) = (max_x_ind-min_x_ind)+1;

mouse.x_ind = x_ind;
mouse.y_ind = y_ind;

mouse.x_transformed = x_transformed;
mouse.y_transformed = y_transformed;

mouse.shift = [(mouse.behav_opt.point_origin(1)-heatmap_border*bin_size_cm)*mouse.behav_opt.pxl2sm/mouse.behav_opt.x_kcorr (mouse.behav_opt.point_origin(2)-heatmap_border*bin_size_cm)*mouse.behav_opt.pxl2sm]; % in original pxles


end
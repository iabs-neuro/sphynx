function mouse = find_arena_features(mouse)

% ищет крайние точки границы арены
[row, col] = find(mouse.arena_opt(1).maskfilled == 1);

% upper pixel
top_rows = row(row == min(row));
top_cols = col(row == min(row));
top_coord = [top_cols(ceil(end/2)), min(top_rows)];

% bottom pixel
bottom_rows = row(row == max(row));
bottom_cols = col(row == max(row));
bottom_coord = [bottom_cols(ceil(end/2)), max(bottom_rows)];

% left pixel
left_rows = row(col == min(col));
left_cols = col(col == min(col));
left_coord = [min(left_cols), left_rows(ceil(end/2))];

% right pixel
right_rows = row(col == max(col));
right_cols = col(col == max(col));
right_coord = [max(right_cols), right_rows(ceil(end/2))];

% invertation up to bottom 
mouse.behav_opt.arena_border.top = bottom_coord;
mouse.behav_opt.arena_border.bottom = top_coord;
mouse.behav_opt.arena_border.left = left_coord;
mouse.behav_opt.arena_border.right = right_coord;

switch mouse.exp
    case "FOF"
        mouse.behav_opt.arena_area = pi*98*98/4;
    case "MSS"
        mouse.behav_opt.arena_area = 44*44;
    case "NOF"
        mouse.behav_opt.arena_area = 44*44;
end

end
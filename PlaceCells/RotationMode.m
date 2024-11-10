function [x_int_sm, y_int_sm] = RotationMode(x_int_sm, y_int_sm, ArenaAndObjects)

BWDMask = bwdist(~ArenaAndObjects(1).maskfilled);

% Ищем индексы элемента с максимальным значением
[~, max_index] = max(BWDMask(:));

% Преобразуем индекс в координаты
[CenterX, CenterY] = ind2sub(size(BWDMask), max_index);

BWDMask = bwdist(~ArenaAndObjects(2).maskfilled);  
imshow(BWDMask);
end
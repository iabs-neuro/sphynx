hist([FieldStat{1, 1}.CellICAll; FieldStat{1, 2}.CellICAll;FieldStat{1, 3}.CellICAll],100)
% Получаем объект оси
ax = gca;

% Устанавливаем размер шрифта для меток по оси X и Y
set(ax, 'FontSize', 12); % 12
title('Все группы (название рабочее)','FontSize', 15);
xlabel('Z-scored(IC)','FontSize', 15);
ylabel('Количество нейронов','FontSize', 15);
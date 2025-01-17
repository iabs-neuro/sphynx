function [mouse] = define_axes(mouse)

% define x axes
axes(1) = min(min(mouse.x), mouse.behav_opt.arena_border.left(1)/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr) - mouse.params_main.axes_step;
axes(2) = max(max(mouse.x), mouse.behav_opt.arena_border.right(1)/mouse.behav_opt.pxl2sm*mouse.behav_opt.x_kcorr) + mouse.params_main.axes_step;

% define y axes
axes(3) = min(min(mouse.y), mouse.behav_opt.arena_border.bottom(2)/mouse.behav_opt.pxl2sm) - mouse.params_main.axes_step;
axes(4) = max(max(mouse.y), mouse.behav_opt.arena_border.top(2)/mouse.behav_opt.pxl2sm) + mouse.params_main.axes_step;

mouse.axes = axes;

end
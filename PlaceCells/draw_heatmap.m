function draw_heatmap(rgb_image, opt, N_time, max_N_time, x_track, y_track, shift, x_kcorr, bin_size,  spike_t_good)
% 26.04.24 VVP Sphynx compatible added
%
% opt.trackp = 1 for drawing trajectory
% opt.textl = 1 for drawinh values
% opt.scale = 1 for Nan bins drawing in white color
% opt.transp = 1 for transparency of patches
% opt.fon = 1 for drawing cage and objects in background
% opt.spike_opt = 1 for drawing spikes

%%
% rgb_image = mouse.behav_opt.rgb_image;
% opt = mouse.params_main.heatmap_opt.track;
% N_time = mouse.ocuppancy_time_smoothed;
% max_N_time = 0;
% x_track = mouse.x_track;
% y_track = mouse.y_track;
% spike_t_good = [];
% x_kcorr = mouse.behav_opt.x_kcorr;
% bin_size = mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm;

min_x_ind = 1;
min_y_ind = 1;


x_shift = shift(1);
y_shift = shift(2);

if opt.fon
    imshow(rgb_image);
    hold on;
end

if opt.scale
    N_time(N_time == 0) = NaN;
end

% dtawinf patches (bins)
k=1;
binx = zeros(4,size(N_time,1)*size(N_time,2));
biny = zeros(4,size(N_time,1)*size(N_time,2));
for j=1:size(N_time,1)
    for  i=1:size(N_time,2)
        binx(1, k) = i*bin_size/x_kcorr;
        biny(1, k) = j*bin_size;
        binx(2, k) = (i+1)*bin_size/x_kcorr;
        biny(2, k) = j*bin_size;
        binx(3, k) = (i+1)*bin_size/x_kcorr;
        biny(3, k) = (j+1)*bin_size;
        binx(4, k) = i*bin_size/x_kcorr;
        biny(4, k) = (j+1)*bin_size;
        k=k+1;
    end
end

binx(1, k) = min_x_ind*bin_size/x_kcorr;
biny(1, k) = min_y_ind*bin_size;
binx(2, k) = min_x_ind*bin_size/x_kcorr+0.01;
biny(2, k) = min_y_ind*bin_size;
binx(3, k) = min_x_ind*bin_size/x_kcorr+0.01;
biny(3, k) = min_y_ind*bin_size+0.01;
binx(4, k) = min_x_ind*bin_size/x_kcorr;
biny(4, k) = min_y_ind*bin_size+0.01;

binx = binx + x_shift - bin_size/x_kcorr;
biny = biny + y_shift - bin_size;

N_time_res = N_time;
c = reshape(N_time_res.',1,[]);
c(length(c)+1) = max_N_time;

if opt.transp
    trasparent = 0.5;
else
    trasparent = 1;
end

if max_N_time>0
    norm_k = max_N_time;
else
    norm_k = max(c);
end

patch(binx,biny,c./norm_k,'FaceAlpha',trasparent, 'EdgeColor', 'none');

%adding colorbar
clb = cell(11,1);
for j = 0:10
    if max_N_time
        clb{j+1} = sprintf('%.f',max_N_time*j/10);
    else
        clb{j+1} = sprintf('%.f',min(min(N_time)) + (max(max(N_time)) - min(min(N_time)))*j/10);
    end
end
colorbar('YTickLabel',clb);
hold on;

% % drawing objects
% if opt.fon
%     for object  = 2:size(ArenaAndObjects,2)
%         plot(ArenaAndObjects(object).border_x, ArenaAndObjects(object).border_y, 'r', 'LineWidth', 1);
%         hold on;
%     end
% end

% drawing trajectory
if opt.trackp
    plot(x_track, y_track, 'Color', [0 1 0 0.5],'LineWidth',1);
    hold on;
end

%draw spikes
if opt.spike_opt
    plot(x_track(spike_t_good),y_track(spike_t_good),'k*', 'MarkerSize',12, 'LineWidth',1);
    hold on;
end

%draw values
if opt.textl
    for j=0:size(N_time,2)-1
        for  i=0:size(N_time,1)-1
            if N_time(i+1,j+1)>=0
                text(x_shift+(j+0.3)*bin_size/x_kcorr, y_shift+(i+0.5)*bin_size, sprintf('%2.1f',N_time(i+1,j+1)), 'Color', 'white', 'FontSize',9);
            end
        end
    end
end

end
function DrawHeatMapModSphynx (Options,ArenaAndObjects,opt,N_time,max_N_time, x_track,y_track,bin_size,x_kcorr,spike_t_good)
% 26.04.24 VVP Sphynx compatible added
%
% opt.trackp = 1 for drawing trajectory
% opt.textl = 1 for drawinh values
% opt.scale = 1 for Nan bins drawing in white color
% opt.transp = 1 for transparency of patches
% opt.fon = 1 for drawing cage and objects in background
% opt.spike_opt = 1 for drawing spikes

x_track = x_track*Options.pxl2sm;
y_track = y_track*Options.pxl2sm;
bin_size = bin_size*Options.pxl2sm;

if opt.fon
    rgb_image = ind2rgb(Options.GoodVideoFrame, gray(256));
    
%     objects_image = zeros(size(ArenaAndObjects(2).maskborder,1),size(ArenaAndObjects(2).maskborder,2));
%     for object  = 2:size(ArenaAndObjects,2)
%         objects_image = objects_image + ArenaAndObjects(object).maskborder;
%     end
%     objects_image(objects_image>1) = 1;
%     objects_image = objects_image./max(max(objects_image))*255;
%     rgb_objects_image  = ind2rgb(objects_image , hot(256));
%     imshow(rgb_objects_image);
    
    imshow(rgb_image);
    hold on;    
end

if opt.scale
    N_time(N_time == 0) = NaN;
end

% main part
x_ind = fix(x_track/bin_size);
y_ind = fix(y_track/bin_size);
min_x_ind = min(x_ind);
min_y_ind = min(y_ind);
x_shift = min_x_ind-1;
y_shift = min_y_ind-1;

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

binx = binx + x_shift*bin_size;
biny = biny + y_shift*bin_size;

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

% drawing objects
if opt.fon
    for object  = 2:size(ArenaAndObjects,2)
        plot(ArenaAndObjects(object).border_x, ArenaAndObjects(object).border_y, 'r', 'LineWidth', 1);
        hold on;
    end
end

% drawing trajectory
if opt.trackp
    plot(x_track/x_kcorr,y_track, 'Color', [0 1 0 0.5],'LineWidth',1);
end

%draw spikes
if opt.spike_opt
    hold on;plot(x_track(spike_t_good)/x_kcorr,y_track(spike_t_good),'k*', 'MarkerSize',12, 'LineWidth',1);
end

%draw values
if opt.textl
    for j=1:size(N_time,2)
        for  i=1:size(N_time,1)
            if N_time(i,j)>=0
                text((x_shift+j+0.3)*bin_size/x_kcorr,(y_shift+i+0.5)*bin_size,sprintf('%2.1f',N_time(i,j)),'Color','white','FontSize',9);
            end
        end
    end
end

end
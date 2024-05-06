function DrawHeatMapMod (options, trackp, textl,scale, transp, fon,spike_opt, N_time, max_N_time,  x_track, y_track, bin_size, x_kcorr, spike_t_good)
%fon=1 for real cage image background else fon=0
%scale = 1 for Nan bins(for white colour)
% h=figure;
%DrawHeatMap3cups (0,1,1,0,0, L, 0, cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad, cup3_centr_x, cup3_centr_y, cup3_rad, x_arena, y_arena, x_int_sm, y_int_sm, bin_size_x, x_kcorr,cup1_line_ref,cup2_line_ref,cup3_line_ref,spike_t_good);
% trackp=0;textl=1;scale=1;transp=0;fon=0;
% N_time=N_time_sm;
% max_N_time=0;
% x1 = cup1_centr_x;
% y1 = cup1_centr_y;
% R1 = cup1_rad;
% x2 = cup2_centr_x;
% y2 = cup2_centr_y;
% R2 = cup2_rad;
% x_track = x_int_sm;
% y_track = y_int_sm;
% bin_size =bin_size_x;
% cup1_line = cup1_line_ref;
% cup2_line = cup2_line_ref;
% spike_opt = 0;

if fon 
    imshow(options.GoodVideoFrame);
    hold on;
end

if scale  
    N_time(find(N_time == 0)) = NaN;
end

   
x_ind = fix(x_track/bin_size);
y_ind = fix(y_track/bin_size);
max_x_ind = max(x_ind);
min_x_ind = min(x_ind);
max_y_ind = max(y_ind);
min_y_ind = min(y_ind);
SizeMY = (max_y_ind-min_y_ind)+1;
SizeMX = (max_x_ind-min_x_ind)+1;
x_shift = min_x_ind-1;
y_shift = min_y_ind-1;
x_ind = x_ind-x_shift;
y_ind = y_ind-y_shift;

x_shift_coord = -bin_size*x_shift; 
y_shift_coord = -bin_size*y_shift;
% x1 = x1+x_shift_coord;
% x2 = x2+x_shift_coord;
% x3 = x3+x_shift_coord;
% y1 = y1+y_shift_coord;
% y2 = y2+y_shift_coord;
% y3 = y3+y_shift_coord;
% x_arena = x_arena+x_shift_coord;
% y_arena = y_arena+y_shift_coord;
% !!!
% x_track = x_track+x_shift_coord;
% y_track = y_track+y_shift_coord;

    k=1;
%     for j=min_y_ind:max_biny
%         for  i=min_x_ind:max_binx
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
    
%     
binx = binx + x_shift*bin_size;
biny = biny + y_shift*bin_size;
%     %good
%     n_colore = (max_biny-min_y_ind+1)*(max_binx-min_x_ind+1);    
%     c = linspace(1/n_colore,1,n_colore);

    N_time_res = N_time;
    c = reshape(N_time_res.',1,[]); 
    
    c(length(c)+1) = max_N_time;
    
if transp
    if max_N_time>0
        patch(binx,biny,c./max_N_time,'FaceAlpha',.5);
    else
        patch(binx,biny,c./max(c),'FaceAlpha',.5);
    end    
else
    if max_N_time>0
        patch(binx,biny,c./max_N_time);
    else
        patch(binx,biny,c./max(c));
    end    
end
%     colorbar
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
%     clb

      
    %draw cobjects


    if trackp
        plot(x_track/x_kcorr,y_track, 'Color', [0 1 0 0.5],'LineWidth',1);
    end
    
    %draw values
      if textl             
        for j=1:size(N_time,2)
            for  i=1:size(N_time,1)
                if N_time(i,j)>=0
                    text((x_shift+j+0.3)*bin_size/x_kcorr,(y_shift+i+0.5)*bin_size,sprintf('%2.1f',N_time(i,j)),'Color','white','FontSize',14);
                end
            end
        end
      end
      
     %draw spikes 
     if spike_opt
        hold on;plot(x_track(spike_t_good)/x_kcorr,y_track(spike_t_good),'k*', 'MarkerSize',20, 'LineWidth',2);
     end      
end
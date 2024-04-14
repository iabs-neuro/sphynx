function [Cell_IC] = RandomShiftMod(spike_t_good, x_ind, y_ind, mask_s, mask_t, N_time_sm, N_shift, shift, S_sigma, TimeRate, FrameRate)
%heatmap for spikes and firing rate
% 05.12.22 added MinRate and FrameRate

%     mkdir(path, 'Shift_Heatmap_Spike');
%     mkdir(path, 'Shift_Heatmap_Spike_Smooth');
%     mkdir(path, 'Shift_Heatmap_FiringRate');

%creating time shift
IC_shift = zeros(2,N_shift+1);
Time_Sum = sum(sum(N_time_sm)); %overall time in minutes/seconds
N_time_occup = N_time_sm/Time_Sum;
for k=2:N_shift+1
    IC_shift(1,k) = rand*Time_Sum*shift;
end

for i=1:N_shift+1

    spike_t_shift = round(mod(spike_t_good+round(IC_shift(1,i)*FrameRate*TimeRate), Time_Sum*FrameRate*TimeRate));

    N = zeros(size(N_time_sm,1),size(N_time_sm,2));
    for k=1:length(spike_t_shift)
        if spike_t_shift(k) == 0
            spike_t_shift(k) = 1;
        end
        N(y_ind(spike_t_shift(k)),x_ind(spike_t_shift(k)))=N(y_ind(spike_t_shift(k)),x_ind(spike_t_shift(k)))+1;

    end
    [N_sm, ~] = ConvBorderFix(N,mask_t);
%         N_freq_bad = N_sm./N_time_sm;%         
%         [N_freq, ~] = ConvBorderFix(N_freq_bad,mask_t);

%         hs = fspecial('gaussian', 3, 1.5);
%         N_sm = conv2(N, single(hs), 'same'); 
%         N_sm = N_sm.*mask_s;
    N_freq = N_sm./N_time_sm;         

%         N_sm = N.*mask_s;
%         N_freq = N_sm./N_time_sm; 

    N_freq(find(isnan(N_freq))) = 0;
    N_freq(find(isinf(N_freq))) = 0;

    %IC calculation        
    for ii = 1:size(N_time_sm,1)
        for jj = 1:size(N_time_sm,2)
            if N_freq(ii,jj)>0                   
                IC_shift(2,i) = IC_shift(2,i)+N_time_occup(ii,jj)*N_freq(ii,jj)/(sum(sum(N_sm))/Time_Sum)*log2(N_freq(ii,jj)/(sum(sum(N_sm))/Time_Sum));
            end
        end
    end

%     %plot all
%     if i==1
%         max_N = max(max(N));
%         max_N_sm = max(max(N_sm));
%         max_N_freq = max(max(N_freq));
%     end
%  
%      h = figure('Position', get(0, 'Screensize'));              
%      DrawHeatMapMod (0,1,1,1,0,0,1, N_freq, max_N_freq, cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad,cup3_centr_x, cup3_centr_y, cup3_rad,  x_arena, y_arena, x_int_sm, y_int_sm, bin_size, x_kcorr,cup1_line_ref,cup2_line_ref, cup3_line_ref,spike_t_shift);
%      title(sprintf('Firing rate of cell(#/min), shift=%d minutes, IC=%f',round(IC_shift(1,i)),IC_shift(2,i)), 'FontSize', 20);
%      F = getframe(h);
%      imwrite(F.cdata, sprintf('%s\\Shift_Heatmap_FiringRate\\Shift_Heatmap_FiringRate_%d.png', path,i));         
%      delete(h); 
% 
%      h = figure('Position', get(0, 'Screensize')); 
%      DrawHeatMapMod (0,1,1,1,0,0,1, N, max_N, cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad,cup3_centr_x, cup3_centr_y, cup3_rad,  x_arena, y_arena, x_int_sm, y_int_sm, bin_size, x_kcorr,cup1_line_ref,cup2_line_ref, cup3_line_ref,spike_t_shift);
%      title(sprintf('Spikes number of cell, shift=%d minutes, IC=%f',round(IC_shift(1,i)),IC_shift(2,i)), 'FontSize', 20);
%      F = getframe(h);
%      imwrite(F.cdata, sprintf('%s\\Shift_Heatmap_Spike\\Shift_Heatmap_Spike_%d.png', path,i));         
%      delete(h);
% 
%      h = figure('Position', get(0, 'Screensize')); 
%      DrawHeatMapMod (0,1,1,1,0,0,1, N_sm, max_N_sm, cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad,cup3_centr_x, cup3_centr_y, cup3_rad,  x_arena, y_arena, x_int_sm, y_int_sm, bin_size, x_kcorr,cup1_line_ref,cup2_line_ref, cup3_line_ref,spike_t_shift);
%      title(sprintf('Spikes number of cell(smoothed), shift=%d minutes, IC=%f',round(IC_shift(1,i)),IC_shift(2,i)), 'FontSize', 20);
%      F = getframe(h);
%      imwrite(F.cdata, sprintf('%s\\Shift_Heatmap_Spike_Smooth\\Shift_Heatmap_Spike_sm_%d.png', path,i));         
%      delete(h);

end
[~,MU,SIGMA] = zscore(IC_shift(2,2:N_shift+1));

if IC_shift(2,1) >MU+S_sigma*SIGMA
    Cell_IC(1,1) = 1;
    Cell_IC(1,2) = IC_shift(2,1);
    Cell_IC(1,3) = MU;
    Cell_IC(1,4) = SIGMA;
else
    Cell_IC(1,1) = 0;
    Cell_IC(1,2) = IC_shift(2,1);
    Cell_IC(1,3) = MU;
    Cell_IC(1,4) = SIGMA;
end    
end

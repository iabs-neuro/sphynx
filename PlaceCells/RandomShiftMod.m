function [Cell_IC] = RandomShiftMod(smooth_freq_mode,spike_t,velcam,x_ind,y_ind,mask_t,N_time_sm,N_shift,shift,S_sigma,TimeRate,FrameRate,kernel_opt)
%heatmap for spikes and firing rate
% 05.12.22 added MinRate and FrameRate
% 06.05.24 added velcam mode

MinTime = 60; %seconds in 1 minutes

%% debugging plots

% mkdir(mouse.params_paths.pathOut, 'Shift_Heatmap_Spike');
% mkdir(mouse.params_paths.pathOut, 'Shift_Heatmap_Spike_Smooth');
% mkdir(mouse.params_paths.pathOut, 'Shift_Heatmap_FiringRate');
% 
% smooth_freq_mode = mouse.params_main.smooth_freq_mode;
% spike_t = cellmaps(ncell).spikes;
% velcam = mouse.velcam;
% x_ind = mouse.x_ind;
% y_ind = mouse.y_ind;
% mask_t = mouse.mask_t;
% N_time_sm = mouse.ocuppancy_map.time_smoothed;
% N_shift = mouse.params_main.N_shift;
% shift = mouse.params_main.shift;
% S_sigma = mouse.params_main.S_sigma;
% TimeRate = mouse.params_main.TimeRate;
% FrameRate = mouse.framerate;
% kernel_opt = mouse.params_main.kernel_opt;

%% creating time shift
Time_total = length(velcam)/FrameRate; % total session time for correct time shift
IC_shift = zeros(2,N_shift+1);
Time_Sum = sum(sum(N_time_sm)); %overall time in minutes/seconds for occupancy map even threshold velocity mode is on
N_time_occup = N_time_sm/Time_Sum;
for k=2:N_shift+1
    IC_shift(1,k) = (rand*shift+(1 - shift)/2)*Time_total;
end

%% main part
for i=1:N_shift+1
    
    spike_t_shift = round(mod(spike_t+round(IC_shift(1,i)*FrameRate*TimeRate), Time_total*FrameRate*TimeRate));
    spike_t_shift(spike_t_shift==0) = 1;
    
    spike_t_good = []; % only in movement
    for spike = 1:length(spike_t_shift)
        if velcam(spike_t_shift(spike))
            spike_t_good = [spike_t_good; spike_t_shift(spike)];
        end
    end
    
    N = zeros(size(N_time_sm,1),size(N_time_sm,2));
    for k=1:length(spike_t_good)
        N(y_ind(spike_t_good(k)),x_ind(spike_t_good(k))) = N(y_ind(spike_t_good(k)),x_ind(spike_t_good(k))) + 1;        
    end
    [N_sm, ~] = convolution_with_holes(N,mask_t,kernel_opt.small.size,kernel_opt.small.sigma);
    
    N_freq = N_sm./N_time_sm*MinTime;
    N_freq(isnan(N_freq)) = 0;
    N_freq(isinf(N_freq)) = 0;
    
    if smooth_freq_mode
        [N_freq_sm, ~] = convolution_with_holes(N_freq,mask_t,kernel_opt.big.size,kernel_opt.big.sigma);
    else
        N_freq_sm = N_freq;
    end
    
    %MI calculation
    for ii = 1:size(N_time_sm,1)
        for jj = 1:size(N_time_sm,2)
            if N_freq_sm(ii,jj)>0
                IC_shift(2,i) = IC_shift(2,i)+N_time_occup(ii,jj)*N_freq_sm(ii,jj)/(sum(sum(N_sm))/Time_Sum*MinTime)*log2(N_freq_sm(ii,jj)/(sum(sum(N_sm))/Time_Sum*MinTime));
            end
        end
    end
    
%     % debugging plots
%     h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
%     DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq,0,x_int_sm,y_int_sm,bin_size,x_kcorr,spike_t_good);
%     title(sprintf('Firing rate of cell, shift=%d seconds, IC=%.2f',round(IC_shift(1,i)),IC_shift(2,i)), 'FontSize', 20);
%     saveas(h, sprintf('%s\\Shift_Heatmap_FiringRate\\%s_Shift_Heatmap_FiringRate_%d.png', path, FilenameOut,i));
%     delete(h);
%     
%     h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
%     DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N,0,x_int_sm,y_int_sm,bin_size,x_kcorr,spike_t_good);
%     title(sprintf('Spikes number of cell, shift=%d seconds, IC=%.2f',round(IC_shift(1,i)),IC_shift(2,i)), 'FontSize', 20);
%     saveas(h, sprintf('%s\\Shift_Heatmap_Spike\\%s_Shift_Heatmap_Spike_%d.png', path, FilenameOut,i));
%     delete(h);
%     
%     h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
%     DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_sm,0,x_int_sm,y_int_sm,bin_size,x_kcorr,spike_t_good);
%     title(sprintf('Spikes number of cell(smoothed), shift=%d seconds, IC=%.2f',round(IC_shift(1,i)),IC_shift(2,i)), 'FontSize', 20);
%     saveas(h, sprintf('%s\\Shift_Heatmap_Spike_Smooth\\%s_Shift_Heatmap_Spike_sm_%d.png', path, FilenameOut,i));
%     delete(h);
    
end

%%
[~,MU,SIGMA] = zscore(IC_shift(2,2:N_shift+1));

if IC_shift(2,1) > MU+S_sigma*SIGMA
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

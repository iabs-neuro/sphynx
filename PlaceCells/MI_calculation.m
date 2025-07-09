function [Cell_IC] = MI_calculation(mouse, spikes)
% Viktor Plusnin
% MI calculation of firing rate map
% 12.22 added MinRate and FrameRate
% 05.24 added velcam mode
% 06.25 mouse struct added

%% debugging options
% mkdir(mouse.params_paths.pathOut, 'Shift_Heatmap_FiringRate');
% spikes = cellmaps(ncell).spikes;

% local variables
velcam = mouse.velcam;
x_ind = mouse.x_ind;
y_ind = mouse.y_ind;
mask_t = mouse.mask_t;
size_map = mouse.size_map;
time_smoothed = mouse.occupancy_map.time_smoothed_min;

N_shift = mouse.params_main.N_shift;
shift = mouse.params_main.shift;
S_sigma = mouse.params_main.S_sigma;

framerate = mouse.framerate;

firing_opt = mouse.params_main.activity_map_opt.mi;
kernel_opt = mouse.params_main.kernel_opt;

%% creating time shift

total_time = sum(time_smoothed(:));          	% total session time in minutes (even threshold velocity mode is on)
MI_shuffle = zeros(2, N_shift+1);               % MI calculations for shuffled set
P = time_smoothed/total_time;                   % Normalize occupancy to probability (P_i)

for k = 2:N_shift+1
    MI_shuffle(1,k) = round((rand*shift+(1 - shift)/2)*total_time*mouse.params_main.MinTime);
end

%% main part
for i = 1:N_shift+1
    
    % correction frames of spikes for shift. Locomotion mode operate only with locomotion track
    ts_spikes = zeros(1,mouse.duration_frames);
    ts_spikes(spikes) = 1;
    ts_spikes_corrected = ts_spikes(logical(velcam));
    spikes_corrected = find(ts_spikes_corrected)';
    x_ind_corrected = x_ind(logical(velcam));
    y_ind_corrected = y_ind(logical(velcam));
    
    spikes_shift = round(mod(spikes_corrected+round(MI_shuffle(1,i)*framerate), total_time*mouse.params_main.MinTime*framerate));
    spikes_shift(spikes_shift==0) = 1;
    
    % spike and firing rate maps calculations
    
    [~, ~, ~, ~, ~, ~, firing_rate_map, ~, ~] = calculate_firing_rate_maps(spikes_shift, x_ind_corrected, y_ind_corrected, ...
        size_map, mask_t, time_smoothed, ...
        firing_opt, kernel_opt);
    
    %MI calculation
    
    % Mean firing rate (R̄)
    R = sum(sum(P .* firing_rate_map));
    
    % Avoid log(0) and division by 0
    mask = P > 0 & firing_rate_map > 0;
    
    % Calculate spatial info: ∑ P_i * (R_i / R) * log2(R_i / R)
    Ri = firing_rate_map(mask);
    Pi = P(mask);
    ratio = Ri / R;
    infoTerms = Pi .* ratio .* log2(ratio);
    
    infoPerSpike = sum(infoTerms);
    infoPerTime = infoPerSpike * R;
    
    MI_shuffle(2,i) = infoPerSpike;
    MI_shuffle(3,i) = infoPerTime;
    
    % debugging plots
    
%     draw_heatmap( ...
%         mouse.behav_opt.rgb_image, ...
%         mouse.params_main.heatmap_opt.spike, ...
%         firing_rate_map, ...
%         0, ...
%         mouse.x_track(logical(velcam)), ...
%         mouse.y_track(logical(velcam)), ...
%         mouse.shift, ...
%         mouse.behav_opt.x_kcorr, ...
%         mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
%         spikes_shift ...
%         );
%     
%     title(sprintf('Firing rate, smoothed, refined, of cell %d. Ca2+ ev: %d. shift #%d = %d seconds. MI = %.2f', ...
%         ncell, ...
%         length(spikes_shift), ...
%         i, ...
%         round(MI_shuffle(1,i)), ...
%         MI_shuffle(2,i)), ...
%         'FontSize', mouse.params_main.FontSizeTitle);
%     saveas(gcf, sprintf('%s\\Shift_Heatmap_FiringRate\\%s_FiringRate_sm_ref_cell_%d_shift_%d.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut, ncell,i));
%     clf; close;
    
end

%% stats

[~,MU,SIGMA] = zscore(MI_shuffle(2,2:N_shift+1));           % calculate MU and SIGMA on shuffled data

if MI_shuffle(2,1) > MU+S_sigma*SIGMA                       % criteria for imformative cells
    Cell_IC(1,1) = 1;
else
    Cell_IC(1,1) = 0;
end

Cell_IC(1,2) = MI_shuffle(2,1);                             % original MI (bit/Ca2+)
Cell_IC(1,4) = MI_shuffle(3,1);                             % original MI (bit/min)
Cell_IC(1,5) = length(spikes_shift);                        % count of Ca2+ events
Cell_IC(1,6) = MU;                                          % MU of shuffled data (bit/Ca2+)
Cell_IC(1,7) = SIGMA;                                       % SIGMA of shuffled data (bit/Ca2+)
Cell_IC(1,3) = (Cell_IC(1,2)-Cell_IC(1,6))/Cell_IC(1,7);    % z-scored(MI)

end

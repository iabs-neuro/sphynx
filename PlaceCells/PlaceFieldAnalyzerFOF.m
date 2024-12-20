function [FieldsIC] = PlaceFieldAnalyzerFOF(params_paths, params_main)
% 17.12.2020 added separate matrices for all plots(for correct gauss filtering)
% 24.12 IC criteria
% 26.04 good fitting of ellipse
% 26.10 fields geometry added
% 04.12.22 different place field method added, n_objects==0 added,
% FilenameCut added, CorrectionTrackMode, TimeMode added
% 24.04.24 spikes only in movement added
% 18.12.24 params, cellInfo, mouse and session structs added

%% manual defining parameters section
if ~exist('params_paths', 'var') || isempty(params_paths)
    
    params_paths.PathOut = uigetdir('w:\Projects\FOF\ActivityData\PlaceCells\', 'Please specify the path to save the data');
    
    %loading videotracking
    [params_paths.filenameWS, params_paths.pathWS]  = uigetfile('*.mat','Please specify the mat-file from behavior analysis','w:\Projects\FOF\ActivityData\Behav_mat\');
    
    %loading spike file
    [params_paths.filenameNV, params_paths.pathNV]  = uigetfile('*.csv','Please specify the file with spikes','w:\Projects\FOF\ActivityData\Spikes\');
    
    %loading trace file
    [params_paths.filenameTR, params_paths.pathTR]  = uigetfile('*.csv','Please specify the file with traces','w:\Projects\FOF\ActivityData\Traces\');
    
    %loading preset file
    [params_paths.filenamePR, params_paths.pathPR]  = uigetfile('*.mat','Please specify the preset file','w:\Projects\FOF\ActivityData\Presets\');
    
end

if ~exist('params_main', 'var') || isempty(params_main)
    
    params_main = struct(...
        'snr_params', struct('percentile', 50),...      % percent of signal to identify noise
        'test_mode', 10,...                             % 0 for all cells analysis else number of n first cells
        'start_frame', 1,...                            % frame of the first frame for analysis
        'app_frame', 1,...                              % frame of the first frame "mouse in cage" (at last paradigm od analysis - is the same frame like a srart
        'end_frame', 0,...                              % frame of the last frame for analysis
        'PC_criterion', 'IC_orig',...                   % method for criterion of Place Cells: 'Peak' - schuffled peak of activity, 'MI_vanila' - Mutual Information for cells,  'MI_vanila_fields' - Mutual Information for fields
        'vel_opt', 0,...                                % all maps calculate with respond to velocity threshold        
        'CorrectionTrackMode', 'Bonsai',...             % different modes for correction syncronization of behavior and calcium data {'NVista', 'FC', 'Bonsai', 'none'}
        'TimeMode', 's',...                             % 's' for 3-20 min duration of session, 'min' - for 30-60 min duration of session
        'coordinates_correction', 0,...                 % 1 if you need in interpolation and smoothing of videotracking data
        'SmoothWindowS', 0.5,...                        % smoothing window in seconds for behavior analysis (in case non-smoothed data)
        'time_smooth', 1,...                            % flag for smoothing of time map(occupancy map)
        'spike_smooth', 1,...                           % flag for smoothing of spikes map
        'thres_spike', 0.3,...                          % threshold for spike map after smoothing
        'thres_firing', 0.3,...                         % threshold for activity map after smoothing
        'length_line_sec', 0.5,...                      % min time for acts (in area of fields or velocity binary timeseries)
        'pxl2cm', 1,...                                 % pixels in сm. 1 if coordinates are in сm
        'bin_size_cm', 8,...                            % size of bins in cm
        'min_spike', 5,...                              % minimum number of spikes for active cell
        'min_spike_field', 3,...                        % minimum number of spikes for place field
        'kernel_opt', struct(...
        'small', struct('size', 3, 'sigma', 1.5),...
        'big', struct('size', 5, 'sigma', 1.5)),...     % gaussian kernel for maps smoothing
        'vel_border', 5,...                             % velocity threshold in cm/s
        'N_shift', 1000,...                             % number of shift for random distribution
        'shift', 0.9,...                                % percent of all time occupancy for random shift
        'S_sigma', 2.29,...                             % criteria for informative place cell(1.65 for p = 0.05, 2.29 for p = 0.01)
        'smooth_freq_mode', 1,...                       % 1 for smoothing activity map during MI calculation
        ...                                             % SUPPORTING PLOTS PARAMETERS
        'plot_opt',1,...                                % main plot parameters, 0 - no one plots, 1 - basic plots, 2 - all plots
        'Screensize', get(0, 'Screensize'),...          % screensize for all plotting
        'axes_step', 1,...                              % in cm
        'opt', struct('track', struct('trackp', 1, 'textl', 1, 'scale', 1, 'transp', 1, 'fon', 1, 'spike_opt', 0),...
        'spike', struct('trackp', 0, 'textl', 1, 'scale', 1, 'transp', 1, 'fon', 1, 'spike_opt', 1)),... % opts for plot activity map
        'LineWidthSpikes', 2,...
        'MarksizeSpikes', 10,...
        'MarksizeSpikesAll', 5,...
        'FontSizeTitle', 20,...
        'FontSizeLabel', 20,...
        'verbose',1 ...                                 % additional messages
    );                                   
    
end

%% Unpack varargin parameters

% ToDo: change everywhere separate params to struct params
pathWS = params_paths.pathWS;
filenameWS = params_paths.filenameWS;
pathTR = params_paths.pathTR;
filenameTR = params_paths.filenameTR;
pathNV = params_paths.pathNV;
filenameNV = params_paths.filenameNV;
pathPR = params_paths.pathPR;
filenamePR = params_paths.filenamePR;
% ToDo: need to change everywhere 'path' on 'pathout'
path = params_paths.PathOut;

snr_params = params_main.snr_params;
test_mode = params_main.test_mode;
start_frame = params_main.start_frame;
app_frame = params_main.app_frame;
end_frame = params_main.end_frame;
PC_criterion = params_main.PC_criterion;
vel_opt = params_main.vel_opt;
CorrectionTrackMode = params_main.CorrectionTrackMode;
TimeMode = params_main.TimeMode;
coordinates_correction = params_main.coordinates_correction;
SmoothWindowS = params_main.SmoothWindowS;
time_smooth = params_main.time_smooth;
spike_smooth = params_main.spike_smooth;
thres_spike = params_main.thres_spike;
thres_firing = params_main.thres_firing;
length_line_sec = params_main.length_line_sec;
pxl2cm = params_main.pxl2cm;
bin_size_cm = params_main.bin_size_cm;
min_spike = params_main.min_spike;
min_spike_field = params_main.min_spike_field;
kernel_opt = params_main.kernel_opt;
vel_border = params_main.vel_border;
N_shift = params_main.N_shift;
shift = params_main.shift;
S_sigma = params_main.S_sigma;
smooth_freq_mode = params_main.smooth_freq_mode;
plot_opt = params_main.plot_opt;
Screensize = params_main.Screensize;
axes_step = params_main.axes_step;
opt = params_main.opt;
LineWidthSpikes = params_main.LineWidthSpikes;
MarksizeSpikes = params_main.MarksizeSpikes;
MarksizeSpikesAll = params_main.MarksizeSpikesAll;
FontSizeTitle = params_main.FontSizeTitle;
FontSizeLabel = params_main.FontSizeLabel;
verbose = params_main.verbose;

FilenameOut = filenameNV(1:find(filenameNV == '_', 1, 'last') - 1);

%% defining all main structs for analysis

% struct MOUSE:
% 'exp'                         - experiment identifier (e.g. FOF, NOF, 3DM)
% 'id'                          - mouse identifier (e.g. F01, H39)
% 'day'                         - day number of registration (e.g. 1D, 6D)
% 'trial'                       - trial number of registration (e.g. 1T, 6T)
% 'duration_s'                  - session duration in seconds 
% 'cells_count'                 - count of all registered cells
% 'cells_active_count'          - count of all active cells
% 'cells_informative_count'     - count of all informative cells
% 'bin_size_cm'                 - size of bin for Heatmaps and MI calculations in cm
% 'bin_size'                    - size of bin for Heatmaps and MI calculations in pixels
% 
% TBA
% 
% 

mouse = struct('exp', '', 'id', '', 'day', '', 'trial', '', 'duration_s', [], 'cells_count', [], 'cells_active_count', [], 'cells_informative_count', []);

[mouse] = identificator_unpuck(mouse, FilenameOut, verbose);
mouse.bin_size_cm = bin_size_cm;
mouse.bin_size = pxl2cm*bin_size_cm;

%% defining internal parameters

MinTime = 60;                               % seconds in 1 minutes :)
FrameRateTrackFreezChamber = 30;            % FrameRate of Freezing chamber videos
t_kcorr = 4000;                             % correction coefficient for VT and NV time distortion for 'NVista' (1 frame on t_kcorr frames screwing)

Screensize(3) = Screensize(4);              % for square arena

switch TimeMode
    case 's'
        TimeRate = 1;                       % for total time in seconds
    case 'min'
        TimeRate = 60;                      % for total time in minutes
end

% parameters for another criteria of PC (oldest version of criterion PC)
% min_good_line = 5;                        % minimum number of line with spikes inside a field
% k_pp = 0;                                 % percentage of good entries for field candidate

plot_opts = struct(...
    'Plot_Single_Spike', 0,...
    'Plot_Spike', 0,...
    'Plot_Spike_Smooth', 0,...
    'Plot_FiringRate', 0,...
    'Plot_FiringRate_Smooth', 0,...
    'Plot_FiringRate_Smooth_Thres', 0,...
    'Plot_FiringRate_Fields', 0,...
    'Plot_FiringRate_Fields_Corrected', 0,...
    'Plot_WaterShed', 0,...
    'Plot_WaterShedField', 0,...
    'Plot_Field', 0);

if plot_opt > 0
    plot_opts.Plot_Single_Spike = 1;
    plot_opts.Plot_FiringRate_Smooth = 1;
    plot_opts.Plot_FiringRate_Fields_Corrected = 1;
end

if plot_opt > 1
    plot_opts.Plot_Spike = 1;
    plot_opts.Plot_Spike_Smooth = 1;
    plot_opts.Plot_FiringRate = 1;
    plot_opts.Plot_FiringRate_Fields = 1;
    plot_opts.Plot_FiringRate_Smooth_Thres = 1;
    plot_opts.Plot_WaterShed = 1;
    plot_opts.Plot_WaterShedField = 1;
end

%% loading data

% spikes
file_NV_orig = readtable(sprintf('%s%s', pathNV, filenameNV));
file_NV_orig = table2array(file_NV_orig(2:end,2:end));

% traces
file_TR_orig = readtable(sprintf('%s%s', pathTR, filenameTR));
file_TR_orig = table2array(file_TR_orig(2:end,2:end));

compareMatrixDimensions(file_TR_orig, file_TR_orig);

% presets
load(sprintf('%s%s',pathPR,filenamePR),'Options','ArenaAndObjects');

% features (video tracking)
load(sprintf('%s%s', pathWS, filenameWS),'Features');
file = [Features.Table.x Features.Table.y];

% creating main and sub folders
path_folder = sprintf('%s_%s', FilenameOut, date);
num_dir = 1;
while isfolder(sprintf('%s\\%s_%d', path, path_folder, num_dir))
    num_dir = num_dir+1;
end
[s, ~, ~] = mkdir(path,sprintf('%s_%d', path_folder, num_dir));
while ~s
    [s, ~, ~] = mkdir(path,sprintf('%s_%d', path_folder, num_dir));
end
path = sprintf('%s\\%s_%d', path, path_folder, num_dir);

if plot_opts.Plot_Single_Spike
    mkdir(path, 'Spikes');
end
if plot_opts.Plot_Spike
    mkdir(path, 'Heatmap_Spike');
end
if plot_opts.Plot_Spike_Smooth
    mkdir(path, 'Heatmap_Spike_Smooth');
end
if plot_opts.Plot_FiringRate
    mkdir(path, 'Heatmap_FiringRate_Informative');
    mkdir(path, 'Heatmap_FiringRate_NOT_Informative');
end
if plot_opts.Plot_FiringRate_Smooth
    mkdir(path, 'Heatmap_FiringRate_Smooth');
end
if plot_opts.Plot_FiringRate_Smooth_Thres
    mkdir(path, 'Heatmap_FiringRate_Smooth_Thres_NOT_Informative');
    mkdir(path, 'Heatmap_FiringRate_Smooth_Thres_Informative');
end
if plot_opts.Plot_FiringRate_Fields
    mkdir(path, 'Heatmap_FiringRate_Fields');
end
if plot_opts.Plot_FiringRate_Fields_Corrected
    mkdir(path, 'Heatmap_FiringRate_Fields_Corrected_NOT_Inform');
    mkdir(path, 'Heatmap_FiringRate_Fields_Corrected_Inform');
end

if plot_opts.Plot_WaterShed
    mkdir(path, 'WaterShed');
end
if plot_opts.Plot_WaterShedField
    mkdir(path, 'WaterShedFields');
end

if plot_opts.Plot_Field
    mkdir(path, 'Heatmap_Fields_Real');
    mkdir(path, 'Heatmap_Fields_NOT_Real');
end

%% Preparing data

% defining session struct: duration and framerate information
session = struct('duration_time_s', [], 'duration_time_min', [], 'duration_frames', [], 'framerate', [], 'time', []);

if end_frame == 0
    end_track = size(file,1);
else
    end_track = end_frame;
end

% x_orig = file(app_frame:end_track, 1)*Options.x_kcorr; % if you load data
% not from features. In features you have corrected data

x_orig = file(app_frame:end_track, 1);
y_orig = file(app_frame:end_track, 2);

% correction of time distortion NV and VT
switch CorrectionTrackMode
    case 'Bonsai'        
        % session.duration_time_s = 720;
        session.duration_time_s = round(end_track/29.9764,2);
        session.duration_time_min = round(session.duration_time_s/MinTime,2);        
        TimeLine.Track = (0:session.duration_time_s/(size(file,1)-1):session.duration_time_s);
        TimeLine.Calcium = (0:session.duration_time_s/(size(file_NV_orig,1)-1):session.duration_time_s);
        Indexes = [];
        for fname = 1:length(TimeLine.Calcium)
            TempArray = abs(TimeLine.Track - TimeLine.Calcium(fname));
            [~, ind] = min(TempArray);
            Indexes = [Indexes ind];
        end
        x_bad = x_orig(Indexes);
        y_bad = y_orig(Indexes);
        Features.TableCorrected = Features.Table(Indexes, :);
        session.framerate = length(x_bad)/session.duration_time_s;        
        fprintf('Количество кадров видеотрекинга и кальция %d %d \n',length(x_bad),size(file_NV_orig,1));
    case 'NVista'
        k = 1;x_bad = [];y_bad = [];
        for i=1:length(x_orig)
            if mod(i, t_kcorr) ~= 0
                x_bad(k) = x_orig(i);
                y_bad(k) = y_orig(i);
                k=k+1;
            end
        end
    case 'FC'
        end_spike = size(file_NV_orig,1);
        session.framerate  = end_spike/(end_track/FrameRateTrackFreezChamber);
        x_bad = zeros(1,end_spike);
        y_bad = zeros(1,end_spike);
        for i=1:end_spike
            x_bad(i) = x_orig(round(i*(FrameRateTrackFreezChamber/session.framerate)));
            y_bad(i) = y_orig(round(i*(FrameRateTrackFreezChamber/session.framerate)));
        end
    case 'none'
        session.framerate = size(file_NV_orig,1)/file_NV_orig(end,1);
        x_bad = x_orig;
        y_bad = y_orig;
end

length_line = round(session.framerate*length_line_sec);                     % length in frames of period in place field
SmoothWindow = round(SmoothWindowS*session.framerate);                      % smoothing window in frames for behavior analysis (in case non-smoothed data)

session.duration_frames = length(x_bad);                                    % session duration in frames
session.time = (1:session.duration_frames)/session.framerate/TimeRate;      % timeline od session in seconds or minutes
mouse.duration_s = session.duration_time_s;
mouse.duration_min = session.duration_time_min;

time_min = 0.5;
% TimeTotal = session.duration_frames/session.framerate/TimeRate;           % total time in minutes/seconds
% time_min = 0.00045*TimeTotal;                                             % time in minutes/seconds for minimum summary time in sectors

NV_start = app_frame-start_frame+1;

file_NV = file_NV_orig(NV_start:NV_start+session.duration_frames-1,:);
file_TR = file_TR_orig(NV_start:NV_start+session.duration_frames-1,:);

mouse.cells_count = size(file_NV, 2);

if test_mode == 0
    n_cells_for_analysis = mouse.cells_count;
else
    n_cells_for_analysis = min(test_mode, mouse.cells_count);
end

if coordinates_correction
    x_nan = isnan(x_bad); y_nan = isnan(y_bad);
    x = x_bad; y = y_bad;
    x(x_nan) = 0; y(y_nan) = 0;
    x_zero = find(x==0); y_zero = find(y==0);
    x_int=interpolation_VP(x,x_zero);
    y_int=interpolation_VP(y,y_zero);
    x_int_sm = smooth(x_int,SmoothWindow);
    y_int_sm = smooth(y_int,SmoothWindow);
else
    x_int_sm = x_bad;
    y_int_sm = y_bad;
end


h=figure;plot(session.time,x_bad); hold on;plot(session.time,x_int_sm,'r');
title('X vs x smooth','FontSize', FontSizeLabel);
xlabel(sprintf('Time, %s', TimeMode),'FontSize', FontSizeLabel);ylabel('X coordinate, cm','FontSize', FontSizeLabel);
legend({'Original','Interpolated and Smoothed'});
saveas(h, sprintf('%s\\%s_x_coordinate.png',path,FilenameOut));
delete(h);

h=figure;plot(session.time,y_bad); hold on;plot(session.time,y_int_sm,'r');
title('Y vs y smooth','FontSize', FontSizeLabel);
xlabel(sprintf('Time, %s', TimeMode),'FontSize', FontSizeLabel);ylabel('Y coordinate, cm','FontSize', FontSizeLabel);
legend({'Original','Interpolated and Smoothed'});
saveas(h, sprintf('%s\\%s_y_coordinate.png',path,FilenameOut));
delete(h);


% velocity calculation
if isempty(Features.TableCorrected.speed) || isempty(Features.TableCorrected.locomotion)
    vel = zeros(1, session.duration_frames);
    for i=2:session.duration_frames
        vel(i)= sqrt((x_int_sm(i)-x_int_sm(i-1))^2+(y_int_sm(i)-y_int_sm(i-1))^2)/pxl2cm*session.framerate;
    end
    vel(1) = vel(2);
    vel_sm = smooth(vel,SmoothWindow);
    vel_sm_line = zeros(1, session.duration_frames);
    for i=1:session.duration_frames
        if vel_sm(i) >= vel_border
            vel_sm_line(i) = 1;
        end
    end
    [vel_ref, ~, ~,~,~,~] = RefineLine(vel_sm_line, length_line, length_line);
else
    vel = Features.TableCorrected.speed;
    vel_ref = Features.TableCorrected.locomotion;
end

h=figure;
plot(session.time,vel);hold on;plot(session.time,vel_sm,'r');hold on;
plot(session.time,vel_ref*vel_border,'g');
title('V vs v smooth','FontSize', FontSizeLabel);
xlabel(sprintf('Time, %s', TimeMode),'FontSize', FontSizeLabel);ylabel('Velocity, cm/s','FontSize', FontSizeLabel);
saveas(h, sprintf('%s\\%s_velocity.png',path,FilenameOut));
saveas(h, sprintf('%s\\%s_velocity.fig',path,FilenameOut));
delete(h);

ax_xy(2) = max(max(x_int_sm))+axes_step;
ax_xy(1) = min(min(x_int_sm))-axes_step;
ax_xy(4) = max(max(y_int_sm))+axes_step;
ax_xy(3) = min(min(y_int_sm))-axes_step;

velcam = ones(1, session.duration_frames);
x_vel_b = x_int_sm;
y_vel_b = y_int_sm;
if vel_opt
    velcam = vel_ref;
end

%% calculation and plotting CELLS spikes

% main struct for all stats of cell
CellInfo = struct(...
    'exp_id', [], 'group_id', [], 'mouse_id', [], 'day_id', [], 'trial_id', [], 'cell_id', [], 'trace', [], 'SNR_baseline', [], 'SNR_peak', [], 'criterion_activity', [], 'criterion_MI', [], ...  
    'spikes_all_count', [], 'spikes_all_frames', [], 'spikes_all_frequency', [], 'spikes_all_mean_amplitude', [], 'spikes_all_peak_amplitude', [], ...
    'spikes_in_mov_count', [],'spikes_in_mov_frames', [], 'spikes_in_mov_frequency', [],'spikes_in_mov_mean_amplitude', [], 'spikes_in_mov_peak_amplitude', [], ...
    'spikes_in_rest_count', [], 'spikes_in_rest_frames', [], 'spikes_in_rest_frequency', [], 'spikes_in_rest_mean_amplitude', [], 'spikes_in_rest_peak_amplitude', [], ... 
    'MI_bit', [], 'MI_zscore', [], 'MI_mean_shuffles', [], 'MI_std_shuffles', [] ...  
    );


for cell=1:n_cells_for_analysis
    
    % defining all parameters of cell
    CellInfo(cell).exp_id = mouse.exp;                                                                          % experiment identifier (e.g. FOF, NOF, 3DM)
    CellInfo(cell).mouse_id = mouse.id;                                                                         % mouse identifier (e.g. F01, H39)
    CellInfo(cell).day_id = mouse.day;                                                                          % day of registration (e.g. 1D, 6D)
    CellInfo(cell).trial_id = mouse.trial;                                                                      % trial of registration (e.g. 1T, 6T)
    CellInfo(cell).cell_id = cell;                                                                              % cell number (same order in trace or spike table)
    CellInfo(cell).trace = file_TR(:,cell);                                                                     % raw cell activity signal from CaImAn   
    CellInfo(cell).SNR_baseline = snr_calculation(CellInfo(cell).trace, 'baseline', snr_params);                % signal-to-noise ratio in dB calculation on raw signal Baseline-Based Method
    CellInfo(cell).SNR_peak = snr_calculation(CellInfo(cell).trace, 'peak', snr_params);                        % signal-to-noise ratio in dB calculation on raw signal Peak Method (PSNR)
    
    CellInfo(cell).spikes_all_frames = find(file_NV(:,cell));                                                   % timestamps of Ca2+ events ('1' in spikes table)
    CellInfo(cell).spikes_all_count = length(CellInfo(cell).spikes_all_frames);                                 % Ca2+ events number
    CellInfo(cell).spikes_all_frequency = round(CellInfo(cell).spikes_all_count/mouse.duration_min,1);          % frequency of Ca2+ events during all session (Ca2+/min)
%     CellInfo(cell).spikes_all_mean_amplitude = 
%     CellInfo(cell).spikes_all_peak_amplitude = 

    CellInfo(cell).spikes_in_mov_frames = find(file_NV(:,cell).*velcam);                                        % timestamps of Ca2+ events ('1' in spikes table)
    CellInfo(cell).spikes_in_mov_count = length(CellInfo(cell).spikes_in_mov_frames);                           % Ca2+ events number
    CellInfo(cell).spikes_in_mov_frequency = round(CellInfo(cell).spikes_in_mov_count/mouse.duration_min,1);    % frequency of Ca2+ events during all session (Ca2+/min)
%     CellInfo(cell).spikes_in_mov_mean_amplitude = 
%     CellInfo(cell).spikes_in_mov_peak_amplitude = 

    CellInfo(cell).spikes_in_rest_frames = find(file_NV(:,cell).*double(1-velcam));                             % timestamps of Ca2+ events ('1' in spikes table)
    CellInfo(cell).spikes_in_rest_count = length(CellInfo(cell).spikes_in_rest_frames);                         % Ca2+ events number
    CellInfo(cell).spikes_in_rest_frequency = round(CellInfo(cell).spikes_in_rest_count/mouse.duration_min,1);  % frequency of Ca2+ events during all session (Ca2+/min)
%     CellInfo(cell).spikes_in_mov_mean_amplitude = 
%     CellInfo(cell).spikes_in_mov_peak_amplitude = 

    if plot_opts.Plot_Single_Spike
        h = figure('Position', Screensize);
        axis([ax_xy(1) ax_xy(2) ax_xy(3) ax_xy(4)]);
        title(sprintf('Trajectory of mouse with n = %d (%d) Ca2+ events (in mov, red) of cell #%d', CellInfo(cell).spikes_all_count,CellInfo(cell).spikes_in_mov_count, cell), 'FontSize', FontSizeTitle);
        xlabel('X coordinate, cm','FontSize', FontSizeLabel);ylabel('Y coordinate, cm','FontSize', FontSizeLabel);
        hold on;plot(x_int_sm,y_int_sm, 'b');
        hold on;DrawLine(x_int_sm, y_int_sm, velcam, 1, 'g', 0, 1);
        hold on;plot(x_vel_b(CellInfo(cell).spikes_all_frames),y_vel_b(CellInfo(cell).spikes_all_frames),'k*', 'MarkerSize',round(MarksizeSpikes/2), 'LineWidth',round(LineWidthSpikes/2));
        hold on;plot(x_vel_b(CellInfo(cell).spikes_in_mov_frames),y_vel_b(CellInfo(cell).spikes_in_mov_frames),'r*', 'MarkerSize',MarksizeSpikes, 'LineWidth',LineWidthSpikes);
        set(gca, 'FontSize', FontSizeLabel);
        saveas(h, sprintf('%s\\Spikes\\%s_Spikes_Cell_%d.png',path,FilenameOut,cell));
        delete(h);
    end
end

% all spike on one figure
h = figure('Position', Screensize);
axis([ax_xy(1) ax_xy(2) ax_xy(3) ax_xy(4)]);
title('Trajectory of mouse with all Ca2+ events', 'FontSize', FontSizeTitle);
xlabel('X coordinate, cm', 'FontSize', FontSizeLabel);
ylabel('Y coordinate, cm', 'FontSize', FontSizeLabel);
set(gca, 'FontSize', FontSizeLabel);
hold on;plot(x_int_sm,y_int_sm, 'b');
hold on;DrawLine(x_int_sm, y_int_sm, velcam, 1, 'g', 0, 1);

percent_spikes_in_mov = zeros(1,n_cells_for_analysis);
for cell=1:n_cells_for_analysis
    percent_spikes_in_mov(cell) = (CellInfo(cell).spikes_in_mov_count/CellInfo(cell).spikes_all_count*100);
    hold on;plot(x_vel_b(CellInfo(cell).spikes_all_frames),y_vel_b(CellInfo(cell).spikes_all_frames),'k*', 'MarkerSize',round(MarksizeSpikesAll/2), 'LineWidth',round(LineWidthSpikes/2));
    hold on;plot(x_vel_b(CellInfo(cell).spikes_in_mov_frames),y_vel_b(CellInfo(cell).spikes_in_mov_frames),'r*', 'MarkerSize',MarksizeSpikesAll, 'LineWidth',LineWidthSpikes);
end
saveas(h, sprintf('%s\\%s_spike_all_plot.png',path,FilenameOut));
delete(h);

h = figure;
histogram(percent_spikes_in_mov);
title('Percent of spikes in movement', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_percent_spikes_in_movement.png',path,FilenameOut));
delete(h);

save(sprintf('%s\\WorkSpace_%s.mat',path, FilenameOut));

plot([CellInfo.spikes_all_count], [CellInfo.SNR_baseline], 'k.');



%% bin's division
x_ind = fix(x_int_sm/mouse.bin_size);
y_ind = fix(y_int_sm/mouse.bin_size);
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

N_frame_orig = zeros(SizeMY,SizeMX);
for d=1:session.duration_frames
    N_frame_orig(y_ind(d),x_ind(d)) = N_frame_orig(y_ind(d),x_ind(d))+1*velcam(d);
end

N_time_orig = N_frame_orig/session.framerate/TimeRate; %in minutes/seconds

N_time_with_min = N_time_orig;
N_time_with_min(N_time_orig<time_min) = 0;

if ~time_smooth
    N_time_sm = N_time_with_min;
else
    [N_time_sm,mask_t] = ConvBorderFix(N_time_with_min,0,kernel_opt.small.size,kernel_opt.small.sigma);
end

mask_s = double(mask_t == 0);

%heatmap for occupancy map
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx (Options,ArenaAndObjects,opt.track,N_time_sm,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
title(sprintf('Occupancy map smoothed (%s)',TimeMode), 'FontSize', FontSizeTitle);
saveas(h,sprintf('%s\\%s_Heatmap_time_sm.png', path, FilenameOut));
delete(h);

save(sprintf('%s\\WorkSpace_%s.mat',path, FilenameOut));

%% searching mean and max of CELLS HeatMaps
max_N = 0;
max_N_sm = 0;
max_N_freq = 0;
max_N_freq_filt = 0;
max_N_freq_filt_norm_thres = 0;
Cell_IC = zeros(2,n_cells_for_analysis);
Cell_IC(1,1:n_cells_for_analysis)=linspace(1,n_cells_for_analysis,n_cells_for_analysis);
mean_N_freq_filt = [];

h = waitbar(1/n_cells_for_analysis, sprintf('IC calculation, cell %d of %d', 0,  n_cells_for_analysis));
for i = 1:n_cells_for_analysis
    h = waitbar(i/n_cells_for_analysis,h, sprintf('IC calculation, cell %d of %d', i,  n_cells_for_analysis));
    spike_t = find(file_NV(:,i));
    spike_t_good = find(file_NV(:,i).*velcam');
    if length(spike_t_good) >= min_spike
        
        N = zeros(SizeMY,SizeMX);
        for k = 1:length(spike_t_good)
            N(y_ind(spike_t_good(k)),x_ind(spike_t_good(k))) = N(y_ind(spike_t_good(k)),x_ind(spike_t_good(k))) + 1;
        end
        
        %smoothing of spike's number
        if spike_smooth
            [N_sm, ~] = ConvBorderFix(N,mask_t,kernel_opt.small.size,kernel_opt.small.sigma);  
        else
            N_sm = N;
        end
        
        N_thres = N_sm;
        N_thres(N_sm < thres_spike * max(N_sm(:))) = 0;
        
        N_freq = N_thres./N_time_sm*MinTime;
        N_freq(isnan(N_freq)) = 0;
        N_freq(isinf(N_freq)) = 0;
        
        [N_freq_filt, ~] = ConvBorderFix(N_freq,mask_t,kernel_opt.big.size,kernel_opt.big.sigma);
        max_TR = max(max(N_freq_filt));
        
        N_freq_filt_norm = N_freq_filt;        
        N_freq_filt_norm_thres = N_freq_filt_norm;
        N_freq_filt_norm_thres(N_freq_filt_norm < thres_firing * max_TR) = 0;

        mean_N_freq_filt(i) = mean(N_freq_filt(N_freq_filt>0));
        
        if max_N<max(max(N))
            max_N = max(max(N));
        end
        if max_N_sm<max(max(N_sm))
            max_N_sm = max(max(N_sm));
        end
        if max_N_freq<max(max(N_freq))
            max_N_freq = max(max(N_freq));
        end
        if max_N_freq_filt<max(max(N_freq_filt))
            max_N_freq_filt = max(max(N_freq_filt));
        end
        if max_N_freq_filt_norm_thres<max(max(N_freq_filt_norm_thres))
            max_N_freq_filt_norm_thres = max(max(N_freq_filt_norm_thres));
        end
        
        %IC calculation
        Cell_IC(2:5,i) = RandomShiftMod(smooth_freq_mode,spike_t,velcam,x_ind,y_ind,mask_t,N_time_sm,N_shift,shift,S_sigma,TimeRate,session.framerate,kernel_opt);
        Cell_IC(6,i) = (Cell_IC(3,i)-Cell_IC(4,i))/Cell_IC(5,i);
        Cell_IC(7,i) = length(spike_t_good);
    else
        Cell_IC(2,i) = -1;
    end
end
delete(h);

if ~isempty(mean_N_freq_filt)
    h = figure;
    histogram(mean_N_freq_filt(mean_N_freq_filt>0),50);
    title('Histogram of mean firing rate(#/min)', 'FontSize', FontSizeTitle);
    saveas(h, sprintf('%s\\%s_Histogram_FiringRate.png', path,FilenameOut));
    delete(h);
    csvwrite(sprintf('%s\\%s_Mean_FiringRate.csv',path,FilenameOut), mean_N_freq_filt);
end

if ~isempty(Cell_IC)
    h = figure;
    histogram(Cell_IC(6,:),ceil(sqrt(length(Cell_IC(6,:)))+1));
    title('Histogram of cell''s IC', 'FontSize', FontSizeTitle);
    saveas(h, sprintf('%s\\%s_Histogram_IC.png', path,FilenameOut));
    delete(h);
    writematrix(Cell_IC, sprintf('%s\\%s_IC.csv',path,FilenameOut));
end

save(sprintf('%s\\WorkSpace_%s.mat',path, FilenameOut));

%% Calculation and plotting CELLS HeatMaps

g_cell = find(Cell_IC(2,:)>=0);                         % indexes of cells with more than min_spike spikes
if isempty(g_cell)
    disp('Not enough spikes. No neurons with at least min_spike spikes');
    return;
end

N_sum = zeros(SizeMY,SizeMX);                           % HeatMap of all spikes from all cells
N_freq_filt_sum = zeros(SizeMY,SizeMX);                 % HeatMap of all activity map
N_freq_filt_norm_sum = zeros(SizeMY,SizeMX);            % HeatMap of all normalized activity map

MapCells = zeros(SizeMY,SizeMX,n_cells_for_analysis);   % thresholded activity maps for all cells

for i = g_cell
    spike_t_good = find(file_NV(:,i).*velcam');
    
    % creation of Spike's number HeatMap
    N = zeros(SizeMY,SizeMX); 
    for k=1:length(spike_t_good)
        N(y_ind(spike_t_good(k)),x_ind(spike_t_good(k)))=N(y_ind(spike_t_good(k)),x_ind(spike_t_good(k)))+1;
    end
    N_sum = N_sum+N;   

    if spike_smooth
        [N_sm, ~] = ConvBorderFix(N,mask_t,kernel_opt.small.size,kernel_opt.small.sigma);
    else
        N_sm = N;
    end
    N_thres = N_sm;
    N_thres(N_sm < thres_spike * max(N_sm(:))) = 0;
    
    % creation of Activity HeatMap    
    N_freq = N_thres./N_time_sm*MinTime;    
    N_freq(isnan(N_freq)) = 0;
    N_freq(isinf(N_freq)) = 0;
    [N_freq_filt, ~] = ConvBorderFix(N_freq,mask_t,kernel_opt.big.size,kernel_opt.big.sigma);
    max_TR = max(max(N_freq_filt));    
    
    N_freq_filt_norm = N_freq_filt;
    N_freq_filt_norm_thres = N_freq_filt_norm;
    N_freq_filt_norm_thres(N_freq_filt_norm < thres_firing * max_TR) = 0;    
    
    max_TR_t = max(max(N_freq_filt_norm_thres));
    min_TR_t = min(min(N_freq_filt_norm_thres));
    N_freq_filt_norm_sum = (N_freq_filt_norm_thres-min_TR_t)/(max_TR_t-min_TR_t)+N_freq_filt_norm_sum;
    N_freq_filt_sum = N_freq_filt_norm_thres+N_freq_filt_sum;
    
    MapCells(:,:,i) = N_freq_filt_norm_thres; 
    
    if plot_opts.Plot_Spike
        h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        DrawHeatMapModSphynx (Options,ArenaAndObjects,opt.spike,N,max_N,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
        title(sprintf('Spike''s map of cell #%d. Spikes: %d',i, length(spike_t_good)), 'FontSize', FontSizeTitle);
        saveas(h, sprintf('%s\\Heatmap_Spike\\%s_Heatmap_Spike_%d.png', path,FilenameOut,i));
        delete(h);
    end
    
    if plot_opts.Plot_Spike_Smooth
        h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_sm,max_N_sm,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
        title(sprintf('Spikes number of cell %d (smoothed). Spikes: %d',i, length(spike_t_good)), 'FontSize', FontSizeTitle);
        saveas(h, sprintf('%s\\Heatmap_Spike_Smooth\\%s_Heatmap_Spike_sm_%d.png', path,FilenameOut,i));
        delete(h);
    end
    
    if plot_opts.Plot_FiringRate
        if Cell_IC(2,i)
            h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
            DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
            title(sprintf('Firing rate of informative cell %d (#/min)', i), 'FontSize', FontSizeTitle);
            saveas(h, sprintf('%s\\Heatmap_FiringRate_Informative\\%s_Heatmap_FiringRate_Informative_%d.png', path, FilenameOut,i));
            delete(h);
        else
            h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
            DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
            title(sprintf('Firing rate of NOT informative cell %d (#/min)', i), 'FontSize', FontSizeTitle);
            saveas(h, sprintf('%s\\Heatmap_FiringRate_NOT_Informative\\%s_Heatmap_FiringRate_NOT_Informative_%d.png', path, FilenameOut,i));
            delete(h);
        end
    end
    
    if plot_opts.Plot_FiringRate_Smooth
        h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq_filt,max_N_freq_filt,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
        title(sprintf('Firing rate, smoothed, of cell %d (#/min). Ca2+ events: %d\n MI = %.2f, MU\\_shuffle = %.3f, SIGMA\\_shuffle = %.3f, MI\\_Zscore = %.1f', i, length(spike_t_good), Cell_IC(3:6,i)), 'FontSize', 10);
        saveas(h, sprintf('%s\\Heatmap_FiringRate_Smooth\\%s_Heatmap_FiringRate_Smoothed_Cell_%d.png', path,FilenameOut,i));
        delete(h);
    end
    
    if plot_opts.Plot_FiringRate_Smooth_Thres
        if Cell_IC(2,i)
            h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
            DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq_filt_norm_thres,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
            title(sprintf('Firing rate of informative cell %d (smoothed and thresholded)(#/min)',i), 'FontSize', FontSizeTitle);
            saveas(h, sprintf('%s\\Heatmap_FiringRate_Smooth_Thres_Informative\\%s_Heatmap_FiringRate_sm_thres_Informative_%d.png', path,FilenameOut,i));
            delete(h);
        else
            h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
            DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq_filt_norm_thres,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
            title(sprintf('Firing rate of NOT informative cell %d (smoothed and thresholded)(#/min)',i), 'FontSize', FontSizeTitle);
            saveas(h, sprintf('%s\\Heatmap_FiringRate_Smooth_Thres_NOT_Informative\\%s_Heatmap_FiringRate_sm_thres_NOT_Informative_%d.png', path,FilenameOut,i));
            delete(h);
        end
    end
end

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,N_sum,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
title('Sum of spikes map', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllCells_spikes.png', path, FilenameOut));
delete(h);

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,N_freq_filt_sum,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
title('Firing rate for all cells(#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllCells_FiringRate.png', path, FilenameOut));
delete(h);

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,N_freq_filt_norm_sum,0,x_int_sm,y_int_sm,mouse.bin_size,Options.x_kcorr,spike_t_good);
title('Firing rate for all cells normalized (#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllCells_Normalized_FiringRate.png', path, FilenameOut));
delete(h);

save(sprintf('%s\\WorkSpace_%s.mat',path, FilenameOut));

%% calculation and plotting separate fields from activity maps

% SpikeFieldsN_sum = zeros(SizeMY,SizeMX,1); %sum of activity maps of all cell

Field_thres_sum = zeros(SizeMY,SizeMX); % sum of corrected activity map
Field_thres_norm_sum = zeros(SizeMY,SizeMX); % sum of corrected normalized activity map
Field_thres_sum_IC = zeros(SizeMY,SizeMX); % sum of inform corrected activity map
Field_thres_sum_NOT_IC = zeros(SizeMY,SizeMX); % sum of NOT inform corrected activity map
Field_thres_norm_sum_IC = zeros(SizeMY,SizeMX); % sum of inform corrected normalized activity map
Field_thres_norm_sum_NOT_IC = zeros(SizeMY,SizeMX); % sum of NOT inform corrected normalized activity map

Fields(1:8,1)=0;
MapFields = zeros(SizeMY,SizeMX,1); %activity map of all fields made from freq_filt
MapFieldsCorrected = zeros(SizeMY,SizeMX,1); %activity map of all fields corrected after watershed

wfields=0; %number of fields from all cells
for map = g_cell
    spike_t_good = find(file_NV(:,map).*velcam');
    
    % watershed transform
    N_water = -MapCells(:,:,map);
    N_freq_filt2 = MapCells(:,:,map);
    L = watershed(N_water);
    [n_wfield,mask_wfield, spike_in_field] = WaterShedFieldVovaMod(L, spike_t_good, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,x_shift,y_shift);
    
    wfields = wfields+n_wfield;
    for mask_field=1:n_wfield
        Fields(1,wfields-n_wfield+mask_field) = map;
        Fields(2,wfields-n_wfield+mask_field) = mask_field;
        Fields(8,wfields-n_wfield+mask_field) = length([spike_in_field{mask_field,:}]);
        
        switch PC_criterion
            case 'Peak'
                orig_peaks = [];
                for mask_field=1:n_wfield
                    orig_peaks = [orig_peaks max(max(N_freq_filt2.*mask_wfield(:,:,mask_field)/max(max(mask_wfield(:,:,mask_field)))))];
                end
                [true_fields, mu_fields, sigma_fields, Nsig_fields] = PeakShift(spike_t_good, mask_t, N_time_sm, x_ind, y_ind, orig_peaks, N_shift, shift, S_sigma);
                Fields(3,wfields-n_wfield+mask_field) = true_fields(mask_field);
                Fields(4,wfields-n_wfield+mask_field) = orig_peaks(mask_field);
                Fields(5,wfields-n_wfield+mask_field) = mu_fields;
                Fields(6,wfields-n_wfield+mask_field) = sigma_fields;
                Fields(7,wfields-n_wfield+mask_field) = Nsig_fields(mask_field);
                Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
            case 'MI_vanila'
                Fields(3:7,wfields-n_wfield+mask_field) = Cell_IC(2:6,map);
                Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
            case 'MI_vanila_fields'
                Fields(3:6,wfields-n_wfield+mask_field) = RandomShiftMod(smooth_freq_mode,[spike_in_field{mask_field,:}],x_ind,y_ind,N_time_sm,N_shift,shift,S_sigma,TimeRate,session.framerate,kernel_opt);
                Fields(7,wfields-n_wfield+mask_field) = (Fields(4,wfields-n_wfield+mask_field)-Fields(5,wfields-n_wfield+mask_field))/Fields(6,wfields-n_wfield+mask_field);
                Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
        end
        
        % calculation separate field
        N_freq_filt_true = N_freq_filt2.*mask_wfield(:,:,mask_field)/max(max(mask_wfield(:,:,mask_field)));
        MapFields(:,:,wfields-n_wfield+mask_field) = N_freq_filt_true;
        
        if plot_opts.Plot_FiringRate_Fields
            h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
            DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq_filt_true, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,[spike_in_field{mask_field,:}]);
            title(sprintf('Firing rate of cell %d field %d Crit= %d \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f', map, mask_field,Fields(3:7,wfields-n_wfield+mask_field)), 'FontSize', 10);
            saveas(h, sprintf('%s\\Heatmap_FiringRate_Fields\\%s_FiringRateFields_Cell_%d_Field_%d.png',path,FilenameOut,map,mask_field));
            delete(h);
        end
        
        %calculating activity map for separated fields
        N = zeros(SizeMY,SizeMX);
        N_thres = zeros(SizeMY,SizeMX);        
        for k=1:length([spike_in_field{mask_field,:}])
            N(y_ind([spike_in_field{mask_field,k}]),x_ind([spike_in_field{mask_field,k}]))=N(y_ind([spike_in_field{mask_field,k}]),x_ind([spike_in_field{mask_field,k}]))+1;
        end
        
        %smoothing of spike's number
        if spike_smooth
            [N_sm, ~] = ConvBorderFix(N,mask_t,kernel_opt.small.size,kernel_opt.small.sigma);
            for ii=1:SizeMY
                for jj=1:SizeMX
                    if N_sm(ii,jj)>=thres_spike*max(max(N_sm))
                        N_thres(ii,jj) = N_sm(ii,jj);
                    end
                end
            end
            N_freq = N_thres./N_time_sm*MinTime;
        else
            N_freq = N./N_time*MinTime;
        end
        
        N_freq(isnan(N_freq)) = 0;
        N_freq(isinf(N_freq)) = 0;
        [N_freq_filt, ~] = ConvBorderFix(N_freq,mask_t,kernel_opt.big.size,kernel_opt.big.sigma);
        max_TR = max(max(N_freq_filt));
        N_freq_filt_norm = N_freq_filt;
        
        N_freq_filt_norm_thres = N_freq_filt_norm;
        N_freq_filt_norm_thres(N_freq_filt_norm < thres_firing * max_TR) = 0;
        
        max_TR_t = max(max(N_freq_filt_norm_thres));
        min_TR_t = min(min(N_freq_filt_norm_thres));
        
        Field_thres_sum = Field_thres_sum + N_freq_filt_norm_thres;
        Field_thres_norm_sum = (N_freq_filt_norm_thres-min_TR_t)/(max_TR_t-min_TR_t)+Field_thres_norm_sum;
        
        if Fields(9,wfields-n_wfield+mask_field)
            Field_thres_sum_IC = Field_thres_sum_IC + N_freq_filt_norm_thres;
            Field_thres_norm_sum_IC = Field_thres_norm_sum_IC + (N_freq_filt_norm_thres-min_TR_t)/(max_TR_t-min_TR_t);
        else
            Field_thres_sum_NOT_IC = Field_thres_sum_NOT_IC + N_freq_filt_norm_thres;
            Field_thres_norm_sum_NOT_IC = Field_thres_norm_sum_NOT_IC + (N_freq_filt_norm_thres-min_TR_t)/(max_TR_t-min_TR_t);
        end
        
        MapFieldsCorrected(:,:,wfields-n_wfield+mask_field) = N_freq_filt_norm_thres;
        
        if plot_opts.Plot_FiringRate_Fields_Corrected
            if Fields(9,wfields-n_wfield+mask_field)
                h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
                DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq_filt_norm_thres, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
                title(sprintf('Firing rate of informative field %d of cell %d (smoothed and thresholded)(#/min) \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f',mask_field,map,Fields(4:7,wfields-n_wfield+mask_field)), 'FontSize', 10);
                saveas(h, sprintf('%s\\Heatmap_FiringRate_Fields_Corrected_Inform\\%s_FiringRate_Fields_Corrected_Inform_Cell_%d_Field_%d.png',path,FilenameOut,map,mask_field));
                delete(h);
            else
%                 h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
%                 DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,N_freq_filt_norm_thres, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
%                 title(sprintf('Firing rate of NOT informative field %d of cell %d (smoothed and thresholded)(#/min) \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f',mask_field,map,Fields(4:7,wfields-n_wfield+mask_field)), 'FontSize', 10);
%                 saveas(h, sprintf('%s\\Heatmap_FiringRate_Fields_Corrected_NOT_Inform\\%s_FiringRate_Fields_Corrected_NOT_Inform_%d.png', path,FilenameOut,wfields-n_wfield+mask_field));
%                 delete(h);
            end
        end
        
        if plot_opts.Plot_WaterShedField
            h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
            DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,double(mask_wfield(:,:,mask_field)), 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
            title(sprintf('WaterShed Transform of cell %d field %d ICcrit= %d \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f', map, mask_field,Fields(3:7,wfields-n_wfield+mask_field)), 'FontSize', FontSizeTitle);
            saveas(h, sprintf('%s\\WaterShedFields\\%s_WaterShedField_%d.png', path,FilenameOut,wfields-n_wfield+mask_field));
            delete(h);
        end
    end
    
    %watershed plot
    if plot_opts.Plot_WaterShed
        h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.spike,double(L), 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
        title(sprintf('WaterShed Transform of cell %d Crit= %d \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f', map, Cell_IC(2:6,map)), 'FontSize', FontSizeTitle);
        saveas(h, sprintf('%s\\WaterShed\\%s_WaterShed_%d.png', path,FilenameOut,map));
        delete(h);
    end
end

% FiringRate plots
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,Field_thres_sum, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
title('Firing rate for all corrected fields(#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRate.png', path, FilenameOut));
delete(h);
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,Field_thres_norm_sum, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
title('Firing rate for all corrected fields (normalized) (#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRate_Normalized.png', path, FilenameOut));
delete(h);

% FiringRate Informative plots
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,Field_thres_sum_IC, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
title('Firing rate for all INFORM corrected fields(#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateInform.png', path, FilenameOut));
delete(h);
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,Field_thres_norm_sum_IC, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
title('Firing rate for all INFORM corrected fields (normalized)(#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateInform_Normalized.png', path, FilenameOut));
delete(h);

% FiringRate NOT Informative plots
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,Field_thres_sum_NOT_IC, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
title('Firing rate for all NOT inform corrected fields (#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateNOTInform.png', path, FilenameOut));
delete(h);
h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
DrawHeatMapModSphynx(Options,ArenaAndObjects,opt.track,Field_thres_norm_sum_NOT_IC, 0, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
title('Firing rate for all NOT inform corrected fields (normalized)(#/min)', 'FontSize', FontSizeTitle);
saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateNOTInform_Normalized.png', path, FilenameOut));
delete(h);

if length(Fields(7,:))>2
    h = figure;
    histogram(Fields(7,:),round(length(Fields(7,:))/5));
    title('Histogram of z-scored IC distribution for fields', 'FontSize', FontSizeLabel);
    saveas(h, sprintf('%s\\%s_Histogram_IC_fields_normalized.png', path,FilenameOut));
    delete(h);
end

if length(Cell_IC(1,:))>2
    h = figure;
    histogram(Cell_IC(6,Cell_IC(2,:)>=0),round(length(Cell_IC(6,:))/5));
    title('Histogram of z-scored IC distribution for cells', 'FontSize', FontSizeLabel);
    saveas(h, sprintf('%s\\%s_Histogram_IC_cells_normalized.png', path,FilenameOut));
    delete(h);
end

save(sprintf('%s\\WorkSpace_%s.mat',path,FilenameOut));

%% searching of real Place Fields

N_inf=1;
N_not_inf=1;
MapFieldsIC = [];
FieldsIC = [];
for i=1:length(Fields(9,:))
    if Fields(9,i)
        MapFieldsIC(:,:,N_inf) = MapFieldsCorrected(:,:,i); %only informative fields
        FieldsIC(:,N_inf) = Fields(:,i);
        N_inf=N_inf+1;
    else
        MapFieldsNotIC(:,:,N_not_inf) = MapFieldsCorrected(:,:,i); %only not informative fields
        N_not_inf=N_not_inf+1;
    end
end

if ~isempty(MapFieldsIC)
    %     SpikeFieldsStruct = struct('cell',[],'fields',[],'inform',[],'crit',[], 'x_mass',[], 'y_mass',[], 'n_entries_field',[], 'time_field',[], 'n_spikes_zone', [], 'n_good_line', []);
    SpikeFieldsStruct = struct('cell',[],'fields',[],'inform',[],'x_mass',[],'y_mass',[]);
    n_field=1;
    for cell=1:size(MapFieldsIC,3)
        IMG = MapFieldsIC(:,:,cell);
        [L,n_segments] = bwlabel(IMG);
        RegionsInMask(n_field) = n_segments;
        mask = zeros(SizeMY,SizeMX,n_segments);
        for i=1:n_segments
            for ii=1:SizeMY
                for jj=1:SizeMX
                    if L(ii, jj) == i
                        mask(ii,jj,i)=1;
                    end
                end
            end
        end
        IMG_mask = mask;
        for i=1:n_segments
            IMG_mask(:,:,i) = IMG.*mask(:,:,i);
        end
        %must be fixed!!!
        n_segments=1;
        
        %searching of centre of mass
        for i=1:n_segments
            SUM = IMG_mask(:,:,i);
            tot_mass = sum(SUM(:));
            [ii,jj] = ndgrid(1:size(SUM,1),1:size(SUM,2));
            SpikeFieldsStruct(n_field).cell = FieldsIC(1,cell);
            SpikeFieldsStruct(n_field).fields = FieldsIC(2,cell);
            SpikeFieldsStruct(n_field).inform = FieldsIC(9,cell);
            %             SpikeFieldsStruct(n_field).crit = 0;
            SpikeFieldsStruct(n_field).x_mass = sum(jj(:).*SUM(:))/tot_mass;
            SpikeFieldsStruct(n_field).y_mass = sum(ii(:).*SUM(:))/tot_mass;
            n_field=n_field+1;
        end
    end
    
    if sum(RegionsInMask)==length(RegionsInMask)
        fprintf('All fields are correct\n');
    else
        fprintf('WARNING! Not all fields are correct, but its okay\n');
    end
    %
    %     %searching real field, spike model
    %     SpikeFieldsReal = struct('cell',[],'fields',[], 'x_mass',[], 'y_mass',[], 'n_entries_field',[], 'time_field',[], 'n_spikes_zone', [], 'n_good_line', []);
    %     %     Fields_geometry = struct('crit', [], 'center_x',[],'center_y',[], 'long_axe',[], 'short_axe',[], 'angle',[]);
    %
    %     real_field=1;
    %     not_real_field=1;
    %     SpikeFieldsSeparateNotReal = [];
    %     SpikeFieldsSeparateReal = [];
    %     for field = 1:length(SpikeFieldsStruct)
    %         %         Big_MatrixN = MapFieldsIC(:,:,field)./MapFieldsIC(:,:,field);
    %         %         Big_MatrixN(isnan(Big_MatrixN)) = 0;
    %         %         Big_Matrix = Big_MatrixN;
    %         %         for i=1:size(Big_MatrixN,1)
    %         %             for j=1:size(Big_MatrixN,2)
    %         %                 if Big_MatrixN(i,j) == 0 && sum(sum(Big_MatrixN(max(i-1,1):min(i+1,size(Big_MatrixN,1)),max(j-1,1):min(j+1,size(Big_MatrixN,2))))) > 0
    %         %                     Big_Matrix(i,j) = 1;
    %         %                 end
    %         %             end
    %         %         end
    %         %
    %         %     %     Big_Matrix = zeros(SizeMY*mouse.bin_size,SizeMX*mouse.bin_size);
    %         %     %     for i=1:size(MapFieldsIC(:,:,1),1)
    %         %     %         for j=1:size(MapFieldsIC(:,:,1),2)
    %         %     %             if MapFieldsIC(i,j,field)>0
    %         %     % %                 Big_Matrix((i+y_shift)*mouse.bin_size:(i+y_shift+1)*mouse.bin_size,(j+x_shift)*mouse.bin_size:(j+x_shift+1)*mouse.bin_size)=1;
    %         %     %                 Big_Matrix((i-1)*mouse.bin_size+1:(i)*mouse.bin_size,(j-1)*mouse.bin_size+1:(j)*mouse.bin_size)=1;
    %         %     %             end
    %         %     %         end
    %         %     %     end
    %         %
    %         %     %     if length(find(MapFieldsIC(:,:,field)))>=6
    %         %         BWd = bwperim(Big_Matrix, 4);
    %         %     %     B = bwboundaries(Big_Matrix,4);
    %         %         [row_ellipse,column_ellipse] = find(BWd);
    %
    %         %fitting ellipse
    %         %         ellipse = my_fit_ellipse(row_ellipse,column_ellipse);
    %         %         Fields_geometry(field).center_x = ellipse.Y0_in;
    %         %         Fields_geometry(field).center_y = ellipse.X0_in;
    %         %         Fields_geometry(field).long_axe = ellipse.long_axis/2;
    %         %         Fields_geometry(field).short_axe = ellipse.short_axis/2;
    %         %         Fields_geometry(field).angle = ellipse.phi;
    %         %         Fields_geometry(field).crit = 0;
    %         %         theta_r = linspace(0,2*pi,10000);
    %
    %         %     x_field_s = ellipse.Y0_in+(ellipse.b)*cos(theta_r)*cos(ellipse.phi)-(ellipse.a)*sin(theta_r)*sin(ellipse.phi)+mouse.bin_size;
    %         %     y_field_s = ellipse.X0_in+(ellipse.b)*cos(theta_r)*sin(ellipse.phi)+(ellipse.a)*sin(theta_r)*cos(ellipse.phi)+mouse.bin_size;
    %         %
    %         %         x_field_s = ellipse.Y0_in+(ellipse.b)*cos(theta_r)*cos(ellipse.phi)-(ellipse.a)*sin(theta_r)*sin(ellipse.phi);
    %         %         y_field_s = ellipse.X0_in+(ellipse.b)*cos(theta_r)*sin(ellipse.phi)+(ellipse.a)*sin(theta_r)*cos(ellipse.phi);
    %         %
    %         %         x_field = mouse.bin_size*x_field_s+mouse.bin_size*x_shift;
    %         %         y_field = mouse.bin_size*y_field_s+mouse.bin_size*y_shift;
    %
    %         %         field_line = zeros(1,session.duration_frames);
    %         %         max_xe = max(x_field);min_xe = min(x_field);
    %         %         for i=1:session.duration_frames
    %         %             if x_int_sm(i)>max_xe || x_int_sm(i)<min_xe
    %         %                 continue
    %         %             else
    %         %                 elip_per = [];
    %         %                 elip_per = y_field(find(abs((x_field-x_int_sm(i)))<1));
    %         %                 if y_int_sm(i)<=max(elip_per) && y_int_sm(i)>=min(elip_per)
    %         %                     field_line(i) = 1;
    %         %                 end
    %         %             end
    %         %         end
    %
    %         %         %test for interpolation ellipse
    %         %         h = figure;
    %         %         plot(x_int_sm, y_int_sm, 'b', 'MarkerSize',20);hold on;
    %         %         plot(x_field,y_field, 'g'); hold on;
    %         %         plot(x_int_sm(find(field_line)),y_int_sm(find(field_line)), 'r');
    %         %         hold on; DrawLine(x_int_sm*Options.x_kcorr, y_int_sm, field_line, Options.x_kcorr, 'b', 1, 1);
    %
    %         %         [field_line_ref, n_entries_field, time_field, field_time, frame_in, frame_out] = RefineLine(field_line, length_line, length_line);
    %
    %         %         field_good = zeros(1,session.duration_frames);
    %         spike_t = find(file_NV(:,SpikeFieldsStruct(field).cell));
    %         spike_t_good = round(spike_t);
    %         %         good_line = zeros(1,length(field_time));
    %         %         for i=1:length(field_time)
    %         %             for j=1:length(spike_t_good)
    %         %                 if spike_t_good(j) >= frame_in(i) && spike_t_good(j) <= frame_out(i)
    %         %                     good_line(i) = good_line(i)+1;
    %         %                     for k=1:field_time(i)
    %         %                         field_good(frame_in(i)+k-1) = 1;
    %         %                     end
    %         %                 end
    %         %             end
    %         %         end
    % %         SpikeFieldsStruct(field).n_entries_field = n_entries_field;
    % %         SpikeFieldsStruct(field).time_field = time_field/session.framerate;
    % %         SpikeFieldsStruct(field).n_good_line = nnz(good_line);
    % %         SpikeFieldsStruct(field).n_spikes_zone = sum(good_line);
    % %         if nnz(good_line) >= min_good_line && nnz(good_line)>= n_entries_field*k_pp
    % %             SpikeFieldsStruct(field).crit = 1;
    % %             Fields_geometry(field).crit = 1;
    % %         end
    %
    %         if SpikeFieldsStruct(field).crit == 1 && SpikeFieldsStruct(field).inform == 1
    %             SpikeFieldsReal(real_field).cell = SpikeFieldsStruct(field).cell;
    %             SpikeFieldsReal(real_field).fields = SpikeFieldsStruct(field).fields;
    %             SpikeFieldsReal(real_field).x_mass = SpikeFieldsStruct(field).x_mass;
    %             SpikeFieldsReal(real_field).y_mass = SpikeFieldsStruct(field).y_mass;
    %             SpikeFieldsReal(real_field).n_entries_field = n_entries_field;
    %             SpikeFieldsReal(real_field).time_field = time_field/session.framerate;
    %             SpikeFieldsReal(real_field).n_spikes_zone = sum(good_line);
    %             SpikeFieldsReal(real_field).n_good_line = nnz(good_line);
    %             SpikeFieldsSeparateReal(:,:,real_field) = MapFieldsIC(:,:,field);
    %             real_field=real_field+1;
    %         else
    %             SpikeFieldsSeparateNotReal(:,:,not_real_field) = MapFieldsIC(:,:,field);
    %             not_real_field = not_real_field+1;
    %         end
    %
    %         % plot for every field
    %         x_field = x_field-mouse.bin_size*(x_shift);
    %         y_field = y_field-mouse.bin_size*(y_shift);
    %         if plot_opts.Plot_Field
    %             h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
    %             DrawHeatMapModSphynx(Options,1,1,1,0,0,0, MapFieldsIC(:,:,field),max_N_freq_filt_norm_thres, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,spike_t_good);
    %             title(sprintf('Activity of %d cell, field %d \n inform %d, crit %d (all entries: %d, entries with Ca2+: %d)',SpikeFieldsStruct(field).cell,SpikeFieldsStruct(field).fields,SpikeFieldsStruct(field).inform,SpikeFieldsStruct(field).crit,SpikeFieldsStruct(field).n_entries_field,SpikeFieldsStruct(field).n_good_line), 'FontSize', FontSizeTitle);
    %             %             for xx=1:length(x_field)
    %             %                 if x_field(xx)< x_arena(1) || x_field(xx)> x_arena(2)
    %             %                     x_field(xx)=NaN;
    %             %                     y_field(xx)=NaN;
    %             %                 end
    %             %                 if y_field(xx) > y_arena(4)|| y_field(xx) < y_arena(2)
    %             %                     x_field(xx)=NaN;
    %             %                     y_field(xx)=NaN;
    %             %                 end
    %             %             end
    %
    %             %             hold on; plot((x_field)/Options.x_kcorr,y_field, 'b', 'LineWidth',3);
    %             hold on; plot((x_field)/Options.x_kcorr,y_field, 'b', 'LineWidth',3);
    %             hold on; DrawLine(x_int_sm-mouse.bin_size*x_shift, y_int_sm-mouse.bin_size*y_shift, field_line_ref, Options.x_kcorr, 'b', 1, 1);
    %             hold on; DrawLine(x_int_sm-mouse.bin_size*x_shift, y_int_sm-mouse.bin_size*y_shift, field_good, Options.x_kcorr, 'b', 1, 2);
    %             hold on; plot((x_int_sm(spike_t_good)-mouse.bin_size*x_shift)/Options.x_kcorr,y_int_sm(spike_t_good)-mouse.bin_size*y_shift,'k*','MarkerSize',MarksizeSpikes,'LineWidth',LineWidthSpikes);
    %
    %             F = getframe(h);
    %             if SpikeFieldsStruct(field).inform && SpikeFieldsStruct(field).crit
    %                 saveas(h, sprintf('%s\\Heatmap_Fields_Real\\%s_Heatmap_Field_Real_%d.png', path,FilenameOut,field));
    %             else
    %                 saveas(h, sprintf('%s\\Heatmap_Fields_NOT_Real\\%s_Heatmap_Field_NOT_Real_%d.png', path,FilenameOut,field));
    %             end
    %             delete(h);
    %         end
    %     end
    
    SpikeFieldsStruct1 = SpikeFieldsStruct;
    %     SpikeFieldsReal1 = SpikeFieldsReal;
    for i=1:length(SpikeFieldsStruct)
        SpikeFieldsStruct1(i).x_mass = round(SpikeFieldsStruct(i).x_mass);
        SpikeFieldsStruct1(i).y_mass = round(SpikeFieldsStruct(i).y_mass);
        %         SpikeFieldsStruct1(i).time_field = round(SpikeFieldsStruct(i).time_field*10)/10;
    end
    %     for i=1:length(SpikeFieldsReal)
    %         SpikeFieldsReal1(i).x_mass = round(SpikeFieldsReal(i).x_mass);
    %         SpikeFieldsReal1(i).y_mass = round(SpikeFieldsReal(i).y_mass);
    %         SpikeFieldsReal1(i).time_field = round(SpikeFieldsReal(i).time_field*10)/10;
    %     end
    
    %saving fields content
    writetable(struct2table(SpikeFieldsStruct1), sprintf('%s\\%s_Fields_IC.csv',path,FilenameOut));
    %     writetable(struct2table(SpikeFieldsReal1), sprintf('%s\\%s_Fields_Real.csv',path,FilenameOut));
    
    % !!!
    SpikeFieldsReal = SpikeFieldsStruct;
    % !!!
    
    %ploting all good field on one figure
    xrealms = zeros(1,length(SpikeFieldsReal));
    yrealms = zeros(1,length(SpikeFieldsReal));
    if ~isempty(SpikeFieldsReal(1).cell)
        for i=1:length(SpikeFieldsReal)
            xrealms(i) = SpikeFieldsReal(i).x_mass+x_shift;
            yrealms(i) = SpikeFieldsReal(i).y_mass+y_shift;
            SpikeFieldsReal(i).x_mass_real = (xrealms(i)+0.5)*mouse.bin_size;
            SpikeFieldsReal(i).y_mass_real = (yrealms(i)+0.5)*mouse.bin_size;
        end
        
        h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        axis([ax_xy(1) ax_xy(2) ax_xy(3) ax_xy(4)]);hold on;
        plot(x_int_sm,y_int_sm, 'b');
        title('All real fields', 'FontSize', FontSizeTitle);
        shift_center = 0.5;
        hold on;plot((xrealms+shift_center)*mouse.bin_size,(yrealms+shift_center)*mouse.bin_size,'k*','MarkerSize',5,'LineWidth',LineWidthSpikes);
        saveas(h, sprintf('%s\\%s_Fields_Real_Centers.png', path, FilenameOut));
        delete(h);
        
        %         %plot heatmap for all real fields activity map(and not real)
        %         N_real_fields_sum = size(SizeMY,SizeMX);
        %         N_not_real_fields_sum = size(SizeMY,SizeMX);
        %
        %         for i=1:size(SpikeFieldsSeparateReal,3)
        %             max_TR_t_real = max(max(SpikeFieldsSeparateReal(:,:,i)));
        %             min_TR_t_real = min(min(SpikeFieldsSeparateReal(:,:,i)));
        %             N_real_fields_sum = (SpikeFieldsSeparateReal(:,:,i)-min_TR_t_real)/(max_TR_t_real-min_TR_t_real)+N_real_fields_sum;
        %         end
        %
        %         for i=1:size(MapFieldsNotIC,3)
        %             max_TR_t_not_real = max(max(MapFieldsNotIC(:,:,i)));
        %             min_TR_t_not_real = min(min(MapFieldsNotIC(:,:,i)));
        %             N_not_real_fields_sum = (MapFieldsNotIC(:,:,i)-min_TR_t_not_real)/(max_TR_t_not_real-min_TR_t_not_real)+N_not_real_fields_sum;
        %         end
        %
        %         if ~isempty(SpikeFieldsSeparateNotReal)
        %             for i=1:size(SpikeFieldsSeparateNotReal,3)
        %                 max_TR_t_not_real = max(max(SpikeFieldsSeparateNotReal(:,:,i)));
        %                 min_TR_t_not_real = min(min(SpikeFieldsSeparateNotReal(:,:,i)));
        %                 N_not_real_fields_sum = (SpikeFieldsSeparateNotReal(:,:,i)-min_TR_t_not_real)/(max_TR_t_not_real-min_TR_t_not_real)+N_not_real_fields_sum;
        %             end
        %         end
        
        %         h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        %         DrawHeatMapModSphynx(Options,n_objects,1,1,1,0,0,0, N_real_fields_sum, 0, cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad, cup3_centr_x, cup3_centr_y, cup3_rad, x_arena, y_arena, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,cup1_line_ref,cup2_line_ref,cup3_line_ref, spike_t_good);
        %         title('Firing rate for all real fields(normalized)', 'FontSize', FontSizeTitle);
        %         F = getframe(h);
        %         saveas(h, sprintf('%s\\%s_Heatmap_AllRealFields.png', path, FilenameOut));
        %         delete(h);
        %
        %         h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
        %         DrawHeatMapModSphynx(Options,n_objects,1,1,1,0,0,0, N_not_real_fields_sum, 0, cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad, cup3_centr_x, cup3_centr_y, cup3_rad, x_arena, y_arena, x_int_sm, y_int_sm, mouse.bin_size, Options.x_kcorr,cup1_line_ref,cup2_line_ref,cup3_line_ref, spike_t_good);
        %         title('Firing rate for all not real fields(normalized)', 'FontSize', FontSizeTitle);
        %         F = getframe(h);
        %         saveas(h, sprintf('%s\\%s_Heatmap_AllNotRealFields.png', path, FilenameOut));
        %         delete(h);
        
        %searching cup fields spike model
        %         cup1_field_s=0;
        %         cup2_field_s=0;
        %         cup3_field_s=0;
        %         for i=1:length(SpikeFieldsReal)
        %             if sqrt((cup1_centr_x-(SpikeFieldsReal(i).x_mass+x_shift)*mouse.bin_size)^2+(cup1_centr_y-(SpikeFieldsReal(i).y_mass+y_shift)*mouse.bin_size)^2) <cup1_rad*area_k
        %                 cup1_field_s = cup1_field_s+1;
        %             end
        %             if sqrt((cup2_centr_x-(SpikeFieldsReal(i).x_mass+x_shift)*mouse.bin_size)^2+(cup2_centr_y-(SpikeFieldsReal(i).y_mass+y_shift)*mouse.bin_size)^2) <cup2_rad*area_k
        %                 cup2_field_s = cup2_field_s+1;
        %             end
        %             if n_objects == 3
        %                 if sqrt((cup3_centr_x-(SpikeFieldsReal(i).x_mass+x_shift)*mouse.bin_size)^2+(cup3_centr_y-(SpikeFieldsReal(i).y_mass+y_shift)*mouse.bin_size)^2) <cup3_rad*area_k
        %                     cup3_field_s = cup3_field_s+1;
        %                 end
        %             end
        %         end
        
        %histogram of field's number
        test_zone4 = zeros(1,length(SpikeFieldsReal));
        for i=1:length(SpikeFieldsReal)
            test_zone4(i) = SpikeFieldsReal(i).cell;
        end
        
        test_zone5 = zeros(1,n_cells_for_analysis);
        for i=1:n_cells_for_analysis
            test_zone5(i) = length(find(test_zone4==i));
        end
        
        h = figure;
        histogram(test_zone5,max(test_zone5)+1);
        title('Histogram of fields number', 'FontSize', FontSizeTitle);
        saveas(h, sprintf('%s\\%s_Fields per cell distribution.png', path, FilenameOut));
        delete(h);        

        results(1) = size(SpikeFieldsStruct,2); %total candidate fields
        results(2) = size(SpikeFieldsReal,2); %total real fields
        r_results = round(results);
        
        %save results
        prmtr=fopen(sprintf('%s\\%s_FieldsCupStat.txt',path, FilenameOut),'w');
        fprintf(prmtr,'All fields Real fields\n');
        fprintf(prmtr, '%d %d\n',r_results(1), r_results(2));
        fclose(prmtr);
    end
end
save(sprintf('%s\\WorkSpace_%s.mat',path, FilenameOut));
end
function [FieldsIC] = PlaceFieldAnalyzerMSS(params_paths, params_main)
% Place Cells and Fields Analysis 
% Plusnin Viktor, Savelev Nikita 2025
% 
% Short history of commites:
% 12.20 added separate matrices for all plots(for correct gauss filtering)
% 04.21 fitting PF by ellipse, fields geometry added
% 12.22 different place cells criteria added
% 04.24 spikes only in movement added
% 12.24 structs params_paths, params_main, session, mouse and cell added


%% manual defining parameters section
if ~exist('params_paths', 'var')
    
    % define path for outputs
    params_paths.pathOut = uigetdir('w:\Projects\NOF\ActivityData\PlaceCells\', 'Please specify the path to save the data');
    
    %loading videotracking
    [params_paths.filenameWS, params_paths.pathWS]  = uigetfile('*.mat','Please specify the mat-file from behavior analysis','w:\Projects\NOF\ActivityData\MAT_behav\');
    
    %loading spike file
    [params_paths.filenameNV, params_paths.pathNV]  = uigetfile('*.csv','Please specify the file with spikes','w:\Projects\NOF\ActivityData\Spikes\');
    
    %loading trace file
    [params_paths.filenameTR, params_paths.pathTR]  = uigetfile('*.csv','Please specify the file with traces','w:\Projects\NOF\ActivityData\Traces\');
    
    %loading preset file
    [params_paths.filenamePR, params_paths.pathPR]  = uigetfile('*.mat','Please specify the preset file','w:\Projects\NOF\ActivityData\Presets\');
    
end

if ~exist('params_main', 'var') || isempty(params_main)
    
    params_main = struct(...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SYNCHRONIZATION OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'CorrectionTrackMode', 'Bonsai',...             % different modes for correction syncronization of behavior and calcium data {'NVista', 'FC', 'Bonsai', 'none'}
        'coordinates_correction', 0,...                 % 1 if you need in interpolation and smoothing of videotracking data
        'test_mode', 20,...                             % 0 for all cells analysis else number of n first cells
        'start_frame', 1,...                            % frame of the first frame for analysis
        'app_frame', 1,...                              % frame of the first frame "mouse in cage" (at last paradigm od analysis - is the same frame like a srart
        'end_frame', 0,...                              % frame of the last frame for analysis
        'TimeMode', 's',...                             % 's' for 3-20 min duration of session, 'min' - for 30-60 min duration of session
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DIFFERENT ANALYSIS MODES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'PC_criterion', 'MI_vanila',...                 % method for criterion of Place Cells: 'Peak' - schuffled peak of activity, 'MI_vanila' - Mutual Information for cells,  'MI_vanila_fields' - Mutual Information for fields
        'bin_size_cm', 4,...                            % size of bins in cm
        'heatmap_border', 1,...                         % additional bins number on the edges of the HeatMaps
        'S_sigma', 2.29,...                             % criteria for informative place cell(1.65 for p = 0.05, 2.29 for p = 0.01, 3,09 for p = 0.001)
        'N_shift', 1000,...                             % number of shift for random distribution
        'shift', 0.9,...                                % percent of all time occupancy for random shift
        'kernel_opt', struct(...
        'small', struct('size', 3, 'sigma', 1.5),...
        'big', struct('size', 5, 'sigma', 2)),...       % gaussian kernel for maps smoothing
        'smooth_freq_mode', 1,...                       % 1 for smoothing activity map during MI calculation
        ...
        'vel_opt', 0,...                                % 1 all maps and MI calculated with respond to velocity threshold
        'vel_border', 5,...                             % velocity threshold in cm/s
        ...
        'min_spike', 1,...                              % minimum number of spikes for active cell
        'min_spike_MI', 3,...                           % minimum number of spikes for MI calculation (not used right now)
        'min_spike_field', 3,...                        % minimum number of spikes for place field
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TEMPORAL PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'SmoothWindowS', 0.5,...                        % smoothing window in seconds for behavior analysis (in case non-smoothed data)
        'time_smooth', 1,...                            % flag for smoothing of occupancy map
        'spike_smooth', 1,...                           % flag for smoothing of spikes map
        'spike_threshold', 0.1,...                     	% threshold for spike map after smoothing (0 - no thresholding)
        'firing_threshold', 0.5,...                    	% threshold for activity map after smoothing (0 - no thresholding)
        'length_line_sec', 0.5,...                      % min time for acts (in area of fields or velocity binary timeseries)
        'snr_params', struct('percentile', 50),...      % percent of signal to identify noise lvl in neuron trace
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SUPPORTING PLOTS AND VERBOSE PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'verbose', 1,...                                % additional messages
        'plot_mode', 2,...                              % main plot parameters, 0 - no one plots, 1 - basic plots, 2 - all plots
        'Screensize', get(0, 'Screensize'),...          % screensize for all plotting 
        'axes_step', 1,...                              % in cm
        'heatmap_opt', struct('track', struct('trackp', 1, 'textl', 1, 'scale', 1, 'transp', 1, 'fon', 1, 'spike_opt', 0),...
        'spike', struct('trackp', 0, 'textl', 1, 'scale', 1, 'transp', 1, 'fon', 1, 'spike_opt', 1)),...
        ...                                             % opts for plot activity map
        'LineWidthSpikes', 2,...                        % line width for spikes plots
        'MarksizeSpikes', 10,...                        % size of calcium event mark on spikes plots
        'MarksizeSpikesAll', 5,...                      % size of calcium event mark on all_spikes plots
        'FontSizeTitle', 20,...                         % title size on plots
        'FontSizeLabel', 20 ...                         % axes text size on plots
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 'PARAMETERS FOR OLDER VERSION OF CRITERION PC' %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        ... % 'min_good_line', 5, ...                   % minimum count of entries with spikes into place field
        ... % 'k_pp', 0 ...                             % minimum percentage of entries with spikes into place field
        );
    
end

%% description and defining main struct MOUSE

mouse = struct(...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MOUSE INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'exp', '', ...                          % experiment identifier (e.g. 'FOF', 'NOF', '3DM')
'group', '', ...                        % experimental group of animal (e.g. 'Control', 'FAD')
'id', '', ...                           % mouse identifier (e.g. 'F01', 'H39')
'day', '', ...                          % day number of registration (e.g. '1D', '6D')
'trial', '', ...                        % trial number of registration (e.g. '1T', '6T')
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SESSION INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'duration_s', [], ...                   % session duration in seconds
'duration_min', [], ...                 % session duration in minutes
'duration_frames', [], ...              % session duration in frames
'framerate', [], ...                    % session framerate in frames/second)
'time', [], ...                         % session timeline in seconds (or minutes if TimeMode = 'm')
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'params_main', [], ...                  % main PC analysis parameters
'params_paths', [], ...                 % paths and names PC analysis parameters
'behav_opt', [], ...                    % all behavior parameters form SPHYNX
'arena_opt', [], ...                    % arena spatial parameters form SPHYNX
'plot_opt', [], ...                     % main plots parameters
'axes', [], ...                         % axes parameters for maps plot
... % 'params_main.bin_size', [], ...         % size of bin for Heatmaps and MI calculations in pixels
...'behav_opt.arena_border', [], ...       % 4 extreme points of arena border (not edges)
...'behav_opt.arena_area', [], ...         % arena area in cm^2
...'behav_opt.point_origin', [], ...       % original point of arena-related frame of reference
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BEHAVIOR VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'TimeLine', [], ...                     % timeline track and calcium before synchronization
'x', [], ...                            % x coordinate of mouse trajectory in cm
'y', [], ...                            % y coordinate of mouse trajectory in cm
'x_ind', [], ...                        % x coordinate binarized of mouse trajectory (indexex of bins)
'y_ind', [], ...                        % y coordinate binarized of mouse trajectory (indexex of bins)
'x_bad', [], ...                        % original x coordinate of mouse trajectory (befor synchronization) 
'y_bad', [], ...                        % original y coordinate of mouse trajectory (befor synchronization) 
'x_track', [], ...                      % x coordinate, original (in pixels and without space distortion)
'y_track', [], ...                      % y coordinate, original (in pixels and without space distortion)
'x_transformed', [], ...                % x coordinate in arena-related frame of reference
'y_transformed', [], ...                % y coordinate in arena-related frame of reference
'shift', [], ...                        % shift in pixels of arena-related frame of reference
'velocity', [], ...                     % smoothed mouse velocity
'velocity_binary', [], ...              % binarized velocity - locomotions (vel_border as threshold)
'velcam', [], ...                       % label array, =ones if vel_opt = 0, =velocity_binary if vel_opt=1
'duration_locomotion_min', [], ...      % locomotion duration in minutes
'duration_rest_min', [], ...            % rest duration in minutes
'locomotion_percent', [], ...           % percent of session in locomotions
'space_explored', [], ...               % percent of explored area
'size_map', [], ...                     % size of all maps in analysis (occupancy, activity)
'ocuppancy_map', struct( ...            % struct for ocuppancy maps:
'frame', [], ...                        % ocuppancy map in frames
'time', [], ...                         % ocuppancy map in seconds (or minutes)
'time_restricted', [], ...              % ocuppancy map in seconds without very low bins
'time_smoothed', []), ...               % ocuppancy map, restricted ans smoothed 
'mask_t', [], ...                       % mask for all maps in related to unvisited bins
'max_bin', struct( ...                  % struct of maxima in bins of different maps:
'spike', 0, ...                         % maximum in bins of all spikes maps
'spike_refined', 0, ...                 % maximum in bins of all refined spikes maps
'firingrate', 0, ...                    % maximum in bins of all firing rate maps
'firingrate_refined', 0), ...           % maximum in bins of all refined firing rate maps
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL. GENERAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cells_indexes', [], ...                    % indexes of all cells
'cells_count_for_analysis', [], ...         % count of cells for analysis in test mode
'cells_count', [], ...                      % count of all cells
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL. ACTIVE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cells_active', [], ...                     % indexes of active cells
'cells_active_count', [], ...               % count of active cells
'cells_active_percent', [], ...             % percent of active cells (to cells_count)
'cells_active_firingrate', [], ...          % firing rate of active cells
'cells_active_firingrate_mean', [], ...     % mean firing rate of active cells
'cells_active_MI_bit', [], ...              % MI of active cells (in bit/Ca2+)
'cells_active_MI_bit_mean', [], ...         % mean MI of active cells (in bit/Ca2+)
'cells_active_MI_zscored', [], ...          % MI of active cells (zscored)
'cells_active_MI_zscored_mean', [], ...     % mean MI of active cells (zscored)
'activity_map_summary', struct( ...         % struct of summary activity maps
'firingrate', [], ...                       % summary of firing rate maps of active cells
'firingrate_normalized', []), ...           % summary of normalized firing rate maps of active cells
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL. INFORMATIVE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cells_informative', [], ...                % indexes of informative cells
'cells_informative_count', [], ...          % count of informative cells
'cells_informative_percent', [], ...        % percent of informative cells (to active cells)
'cells_informative_MI_bit', [], ...         % MI of informative cells (in bit/Ca2+)
'cells_informative_MI_bit_mean', [], ...    % mean MI of informative cells (in bit/Ca2+)
'cells_informative_MI_zscored', [], ...     % MI of informative cells (zscored)
'cells_informative_MI_zscored_mean', [] ... % mean MI of informative cells (zscored)
);

params_paths.filenameOut = params_paths.filenameNV(1:find(params_paths.filenameNV == '_', 1, 'last') - 1);
mouse.params_main = params_main;
mouse.params_paths = params_paths;

mouse = identificator_unpuck(mouse);

mouse.params_main.MinTime = 60;                                             % seconds in 1 minutes :)
mouse.params_main.FrameRateTrackFreezChamber = 30;                          % FrameRate of Freezing chamber videos
mouse.params_main.t_kcorr = 4000;                                           % correction coefficient for VT and NV time distortion for 'NVista' (1 frame on t_kcorr frames screwing)
mouse.params_main.Screensize(3) = mouse.params_main.Screensize(4);          % for square arena

switch mouse.params_main.TimeMode
    case 's'
        mouse.params_main.TimeRate = 1;                                     % for total time in seconds
    case 'min'
        mouse.params_main.TimeRate = 60;                                    % for total time in minutes
end

mouse.plot_opt = struct(...
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

if mouse.params_main.plot_mode > 0
    mouse.plot_opt.Plot_Single_Spike = 1;
    mouse.plot_opt.Plot_FiringRate_Smooth = 1;
    mouse.plot_opt.Plot_FiringRate_Fields_Corrected = 1;
end

if mouse.params_main.plot_mode > 1
    mouse.plot_opt.Plot_Spike = 1;
    mouse.plot_opt.Plot_Spike_Smooth = 1;
    mouse.plot_opt.Plot_FiringRate = 1;
    mouse.plot_opt.Plot_FiringRate_Fields = 1;
    mouse.plot_opt.Plot_FiringRate_Smooth_Thres = 1;
    mouse.plot_opt.Plot_WaterShed = 1;
    mouse.plot_opt.Plot_WaterShedField = 1;
    mouse.plot_opt.Plot_Field = 1;
end

disp(['Структура mouse для сессии ' mouse.params_paths.filenameOut ' создана']);
disp(['Эксперимент: ', mouse.exp]);
disp(['Группа: ', mouse.group]);
disp(['Животное: ', mouse.id]);
disp(['День: ', mouse.day]);
disp(['Попытка: ', mouse.trial]);

%% loading data

% spikes
file_NV_orig = readtable(sprintf('%s%s', mouse.params_paths.pathNV, mouse.params_paths.filenameNV));
file_NV_orig = table2array(file_NV_orig(2:end,2:end));
disp('Таблица со спайками загружена');

% traces
file_TR_orig = readtable(sprintf('%s%s', mouse.params_paths.pathTR, mouse.params_paths.filenameTR));
file_TR_orig = table2array(file_TR_orig(2:end,2:end));
disp('Таблица с трейсами загружена');

% checking synchronization
compareMatrixDimensions(file_TR_orig, file_TR_orig);

% presets
load(sprintf('%s%s',mouse.params_paths.pathPR,mouse.params_paths.filenamePR),'Options','ArenaAndObjects');
disp('Пространственная разметка арены загружена');

% features (video tracking)
load(sprintf('%s%s', mouse.params_paths.pathWS, mouse.params_paths.filenameWS),'Features');
file_VT = [Features.Table.x Features.Table.y];
disp('Разметка поведения загружена');

% creating main and sub folders
mouse = createOutputDirectories(mouse);

%% Preparing data

% adding parameters from behavior in main struct MOUSE
mouse.behav_opt = Options;
mouse.arena_opt = ArenaAndObjects;
mouse.params_main.bin_size = mouse.behav_opt.pxl2sm*mouse.params_main.bin_size_cm;

% defining session struct: duration and framerate information
session = struct('duration_s', [], 'duration_min', [], 'duration_frames', [], 'framerate', [], 'time', []);

if mouse.params_main.end_frame == 0
    mouse.params_main.end_frame = size(file_VT,1);
end

% x_orig = file_VT(params_main.app_frame:end_track, 1)*Options.x_kcorr; % if you load data
% not from features. In features you have corrected data

x_orig = file_VT(mouse.params_main.app_frame:mouse.params_main.end_frame, 1);
y_orig = file_VT(mouse.params_main.app_frame:mouse.params_main.end_frame, 2);

% correction of time distortion NV and VT
switch mouse.params_main.CorrectionTrackMode
    case 'Bonsai'
        % session.duration_time_s = 720;
        % !!! change 30
        session.duration_s = round(mouse.params_main.end_frame/30,2);
        session.duration_min = round(session.duration_s/mouse.params_main.MinTime,2);        
%         mouse.TimeLine.Track = (0:session.duration_s/(size(file_VT,1)-1):session.duration_s);
        mouse.TimeLine.Track = (0:session.duration_s/(length(x_orig)-1):session.duration_s);
        mouse.TimeLine.Calcium = (0:session.duration_s/(size(file_NV_orig,1)-1):session.duration_s);
        Indexes = [];
        for frame = 1:length(mouse.TimeLine.Calcium)
            TempArray = abs(mouse.TimeLine.Track - mouse.TimeLine.Calcium(frame));
            [~, ind] = min(TempArray);
            Indexes = [Indexes ind];
        end
        mouse.x_bad = x_orig(Indexes);
        mouse.y_bad = y_orig(Indexes);
        Features.TableCorrected = Features.Table(Indexes, :);
        session.framerate = length(mouse.x_bad)/session.duration_s;        
        fprintf('Количество кадров видеотрекинга и кальция %d %d \n',length(mouse.x_bad),size(file_NV_orig,1));
        clear 'Indexes' 'ind' 'TempArray'
    case 'NVista'
        k = 1;mouse.x_bad = [];mouse.y_bad = [];
        for frame=1:length(x_orig)
            if mod(frame, mouse.params_main.t_kcorr) ~= 0
                mouse.x_bad(k) = x_orig(frame);
                mouse.y_bad(k) = y_orig(frame);
                k=k+1;
            end
        end
    case 'FC'
        end_spike = size(file_NV_orig,1);
        session.framerate  = end_spike/(mouse.params_main.end_frame/mouse.params_main.FrameRateTrackFreezChamber);
        mouse.x_bad = zeros(1,end_spike);
        mouse.y_bad = zeros(1,end_spike);
        for frame=1:end_spike
            mouse.x_bad(frame) = x_orig(round(frame*(mouse.params_main.FrameRateTrackFreezChamber/session.framerate)));
            mouse.y_bad(frame) = y_orig(round(frame*(mouse.params_main.FrameRateTrackFreezChamber/session.framerate)));
        end
    case 'none'
        session.framerate = size(file_NV_orig,1)/file_NV_orig(end,1);
        mouse.x_bad = x_orig;
        mouse.y_bad = y_orig;
end
clear 'y_orig' 'x_orig'

mouse.params_main.length_line = round(session.framerate*mouse.params_main.length_line_sec);         % length in frames of period in place field
mouse.params_main.SmoothWindow = round(mouse.params_main.SmoothWindowS*session.framerate);          % smoothing window in frames for behavior analysis (in case non-smoothed data)

session.duration_frames = length(mouse.x_bad);                                                      % session duration in frames
session.time = (1:session.duration_frames)/session.framerate/mouse.params_main.TimeRate;            % timeline of session in seconds or minutes

mouse.params_main.time_min = 0.25;                                                                  % minimum time in bins in seconds
% mouse.params_main.time_min = 0.00045*TimeTotal;                                           

mouse = mergeStructures(mouse,session);

NV_start = mouse.params_main.app_frame-mouse.params_main.start_frame+1;

file_NV = file_NV_orig(NV_start:NV_start+session.duration_frames-1,:);
file_TR = file_TR_orig(NV_start:NV_start+session.duration_frames-1,:);
clear 'NV_start'

mouse.cells_count = size(file_NV, 2);
mouse.cells_indexes = 1:mouse.cells_count;

if mouse.params_main.test_mode == 0
    mouse.cells_count_for_analysis = mouse.cells_count;
else
    mouse.cells_count_for_analysis = min(mouse.params_main.test_mode, mouse.cells_count);
end

if mouse.params_main.coordinates_correction
    x_nan = isnan(mouse.x_bad); y_nan = isnan(mouse.y_bad);
    x = mouse.x_bad; y = mouse.y_bad;
    x(x_nan) = 0; y(y_nan) = 0;
    x_zero = find(x==0); y_zero = find(y==0);
    x_int=interpolation_VP(x,x_zero);
    y_int=interpolation_VP(y,y_zero);
    mouse.x = smooth(x_int,mouse.params_main.SmoothWindow);
    mouse.y = smooth(y_int,mouse.params_main.SmoothWindow);
else
    mouse.x = mouse.x_bad;
    mouse.y = mouse.y_bad;
end

mouse.x_track = mouse.x*mouse.behav_opt.pxl2sm/mouse.behav_opt.x_kcorr;
mouse.y_track = mouse.y*mouse.behav_opt.pxl2sm;

% plot for coordinates
PlotPC(mouse, 'coordinate');

% velocity calculation
if isempty(Features.TableCorrected.speed) || isempty(Features.TableCorrected.locomotion)
    [mouse] = calculate_velocity(mouse);
else
    mouse.velocity = Features.TableCorrected.speed;
    mouse.velocity_binary = Features.TableCorrected.locomotion;
end

% velocity label for analysis
mouse.velcam = ones(1,mouse.duration_frames);
if mouse.params_main.vel_opt
    mouse.velcam = mouse.velocity_binary;
end

mouse.duration_locomotion_min = sum(mouse.velocity_binary)/mouse.framerate/mouse.params_main.MinTime;
mouse.duration_rest_min = sum(1-mouse.velocity_binary)/mouse.framerate/mouse.params_main.MinTime;
mouse.locomotion_percent = round(mouse.duration_locomotion_min/mouse.duration_min*100,2);

% plot for velocity
PlotPC(mouse, 'velocity');

% define axes and border pixels of arena for defining binarization independent to trajectory
mouse = find_arena_features(mouse);
mouse = define_axes(mouse);

% calculation rgb image
if ~isfield(mouse.behav_opt, 'GoodVideoFrameGray')  
    mouse.behav_opt.GoodVideoFrameGray = mouse.behav_opt.GoodVideoFrame;
end

if numel(size(mouse.behav_opt.GoodVideoFrameGray)) == 3
    mouse.behav_opt.rgb_image = mouse.behav_opt.GoodVideoFrameGray;
else
    mouse.behav_opt.rgb_image = ind2rgb(mouse.behav_opt.GoodVideoFrameGray, gray(256));
end

if mouse.behav_opt.ExperimentType  == "Freezing Track"
    mouse.behav_opt.rgb_image = mouse.behav_opt.GoodVideoFrame;   
end

% plot for arena and trajectory
PlotPC(mouse, 'arena_and_track');

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));

%% description and defining struct CELLS

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MOUSE INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'exp'                         - experiment identifier (e.g. 'FOF', 'NOF', '3DM' 'MSS')
% 'group'                       - experimental group of animal (e.g. 'Control', 'FAD')
% 'id'                          - mouse identifier (e.g. 'F01', 'H39')
% 'day'                         - day number of registration (e.g. '1D', '6D')
% 'trial'                       - trial number of registration (e.g. '1T', '6T')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAIN CELL INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'cell'                        - cell number (same order in trace or spike table)
% 'trace'                       - raw cell activity signal from CaImAn
% 'SNR_baseline'                - signal-to-noise ratio in dB calculated on raw signal Baseline-Based Method
% 'SNR_peak'                    - signal-to-noise ratio in dB calculated on raw signal Peak Method (PSNR)
% 'SNR'                         - average signal-to-noise ratio in dB calculated on raw signal
% 'criterion_activity'          - 1 - if cell passed activity criteria
% 'criterion_MI'                - 1 - if cell passed information criteria

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SPIKES STATISTICS %%%%%%%%%%%%%%%%%%%%%%%%
% 'spikes_all_count'            - count of all Ca2+ events
% 'spikes_all_frames'           - timestamps of all Ca2+ events ('1' in spikes table)
% 'spikes_all_frequency'        - frequency of all Ca2+ events during session (Ca2+/min)
% 'spikes_all_amplitude'        - all Ca2+ events amplitude 
% 'spikes_all_mean_amplitude'   - mean all Ca2+ events amplitude 
% 'spikes_all_peak_amplitude'   - maximum amplitude of Ca2+ events
% 
% 'spikes_in_mov-//-'           - the same statistics as 'all' but during locomotion
% 'spikes_in_rest-//-'          - the same statistics as 'all' but during rest
% 'frequency_ratio_mov_rest'    - ratio of 'spikes_in_mov_frequency'/'spikes_in_rest_frequency'

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MUTUAL INFORMATION %%%%%%%%%%%%%%%%%%%%%%%
% 'MI_bit'                      -
% 'MI_zscore'                   -
% 'MI_mean_shuffles'            -
% 'MI_std_shuffles'             -
% 


cells = struct(...
    'exp', '', 'group', '', 'id', '', 'day', '', 'trial', '', ...
    'cell', [], 'trace', [], 'SNR', [], 'SNR_baseline', [], 'SNR_peak', [], 'criterion_activity', [], 'criterion_MI', [], ...  
    'spikes_all_count', [], 'spikes_all_frames', [], 'spikes_all_frequency', [], 'spikes_all_mean_amplitude', [], 'spikes_all_peak_amplitude', [], ...
    'spikes_in_mov_count', [],'spikes_in_mov_frames', [], 'spikes_in_mov_frequency', [],'spikes_in_mov_mean_amplitude', [], 'spikes_in_mov_peak_amplitude', [], ...
    'spikes_in_rest_count', [], 'spikes_in_rest_frames', [], 'spikes_in_rest_frequency', [], 'spikes_in_rest_mean_amplitude', [], 'spikes_in_rest_peak_amplitude', [], ... 
    'frequency_ratio_mov_rest', [], ...
    'MI_bit', [], 'MI_zscore', [], 'MI_mean_shuffles', [], 'MI_std_shuffles', [] ...  
    );

for ncell=1:mouse.cells_count_for_analysis
    
    cells(ncell).exp = mouse.exp;
    cells(ncell).id = mouse.id;
    cells(ncell).day = mouse.day;
    cells(ncell).trial = mouse.trial;
    cells(ncell).cell = ncell;
    cells(ncell).trace = file_TR(:,ncell);
    cells(ncell).SNR_baseline = snr_calculation(cells(ncell).trace, 'baseline', mouse.params_main.snr_params);
    cells(ncell).SNR_peak = snr_calculation(cells(ncell).trace, 'peak', mouse.params_main.snr_params);
    cells(ncell).SNR = mean([cells(ncell).SNR_baseline cells(ncell).SNR_peak]);
    
    cells(ncell).spikes_all_frames = find(file_NV(:,ncell));
    cells(ncell).spikes_all_count = length(cells(ncell).spikes_all_frames);
    cells(ncell).spikes_all_frequency = round(cells(ncell).spikes_all_count/mouse.duration_min,1);
%     cells(ncell).spikes_all_amplitude = file_TR(cells(ncell).spikes_all_frames,ncell);
%     cells(ncell).spikes_all_peak_amplitude = 
%     cells(ncell).spikes_all_mean_amplitude = 
    
    cells(ncell).spikes_in_mov_frames = find(file_NV(:,ncell).*mouse.velocity_binary);
    cells(ncell).spikes_in_mov_count = length(cells(ncell).spikes_in_mov_frames);
    cells(ncell).spikes_in_mov_frequency = round(cells(ncell).spikes_in_mov_count/mouse.duration_locomotion_min,1);
%     cell(ncell).spikes_in_mov_mean_amplitude = 
%     cell(ncell).spikes_in_mov_peak_amplitude = 
    
    cells(ncell).spikes_in_rest_frames = find(file_NV(:,ncell).*double(1-mouse.velocity_binary));
    cells(ncell).spikes_in_rest_count = length(cells(ncell).spikes_in_rest_frames);
    cells(ncell).spikes_in_rest_frequency = round(cells(ncell).spikes_in_rest_count/mouse.duration_rest_min,1);
%     cell(ncell).spikes_in_mov_mean_amplitude = 
%     cell(ncell).spikes_in_mov_peak_amplitude = 
    
    cells(ncell).frequency_ratio_mov_rest = round(cells(ncell).spikes_in_mov_frequency/cells(ncell).spikes_in_rest_frequency,2);
    
    cells(ncell).criterion_activity = double((cells(ncell).spikes_all_count >= mouse.params_main.min_spike));
    
end

% defining stats for cell count
mouse.cells_active = find([cells.criterion_activity]);
mouse.cells_active_count = sum([cells.criterion_activity]);
mouse.cells_active_percent = round(mouse.cells_active_count/mouse.cells_count*100, 2);
mouse.cells_active_firingrate = [cells(mouse.cells_active).spikes_all_frequency];
mouse.cells_active_firingrate_mean = round(mean(mouse.cells_active_firingrate),2);
mouse.cells_active_not = find(~[cells.criterion_activity]);

if isempty(mouse.cells_active)
    disp('Not enough spikes. No neurons with at least mouse.params_main.min_spike spikes');
    return;
end

% map of Ca2+ events of cells
if mouse.plot_opt.Plot_Single_Spike
    PlotPC(mouse, 'single_spike', cells);
end

% all Ca2+ events from all cells on one figure plot
PlotPC(mouse, 'all_spikes', cells);

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));

%% bin's division

% transform real coordinates to bins indexes. Now you can use mouse.x_ind, mouse.y_ind
mouse = calculate_binarized_indexes(mouse);

% calculate ocuppancy_map.frame time spent in bins in frames 
mouse.ocuppancy_map.frame = zeros(mouse.size_map);
for d=1:mouse.duration_frames
    mouse.ocuppancy_map.frame(mouse.y_ind(d),mouse.x_ind(d)) = mouse.ocuppancy_map.frame(mouse.y_ind(d),mouse.x_ind(d))+1*mouse.velcam(d);
end

% calculate ocuppancy_map.time time spent in bins in minutes/seconds
mouse.ocuppancy_map.time = mouse.ocuppancy_map.frame/mouse.framerate/mouse.params_main.TimeRate;

% calculate ocuppancy_map.time_restricted time spent in bins in
% minutes/seconds, excluded not enough occupied 
mouse.ocuppancy_map.time_restricted = mouse.ocuppancy_map.time;
mouse.ocuppancy_map.time_restricted(mouse.ocuppancy_map.time<mouse.params_main.time_min) = 0;

% calculate ocuppancy_map.time_smoothed time spent in bins in minutes/seconds, smoothed
mouse.ocuppancy_map.time_smoothed = mouse.ocuppancy_map.time_restricted;
if mouse.params_main.time_smooth
    [mouse.ocuppancy_map.time_smoothed,mouse.mask_t] = convolution_with_holes(mouse.ocuppancy_map.time_smoothed,0,mouse.params_main.kernel_opt.small.size,mouse.params_main.kernel_opt.small.sigma);
end

% define explored space. Correction if % > 100
mouse.space_explored = min(100, round(length(find(mouse.ocuppancy_map.time_smoothed>0))*mouse.params_main.bin_size_cm^2/mouse.behav_opt.arena_area*100,1));

%heatmap for occupancy map
PlotPC(mouse, 'occupancy');

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));

%% Maps for cell activity defining, MI calculation

% description and defining struct CELLMAPS

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MOUSE INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'exp'                         - experiment identifier (e.g. 'FOF', 'NOF', '3DM' 'MSS')
% 'group'                       - experimental group of animal (e.g. 'Control', 'FAD')
% 'id'                          - mouse identifier (e.g. 'F01', 'H39')
% 'day'                         - day number of registration (e.g. '1D', '6D')
% 'trial'                       - trial number of registration (e.g. '1T', '6T')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SPIKE AND FIRINGRATE MAPS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'cell'                                          	- index of cell
% 'spikes'                                          - timestamps of relevant Ca2+ events
% 'spikes_count'                                    - count of relevant Ca2+ events
% 'spike'                                           - spike map, original:          count of Ca2+ events
% 'spike_smoothed'                                  - spike map, smoothed:          convolution with gauss kernel
% 'spike_refined'                                   - spike map, refined:           spike_smoothed thresholded
% 'spike_normalized'                                - spike map, normalized:        spike_refined normalized to [0,1]
% 'firingrate'                                      - firing rate map, original:    count Ca2+ events per time unit
% 'firingrate_smoothed'                             - firing rate map, smoothed:    convolution with gauss kernel
% 'firingrate_refined'                              - firing rate map, refined:     firingrate_smoothed thresholded
% 'firingrate_normalized'                           - firing rate map, normalized:  firingrate_refined normalized to [0,1]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAXIMA OF MAPS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'max_bin_spike'                                   - maximum value of spike map
% 'max_bin_spike_refined'                          	- maximum value of spike map, smoothed and refined
% 'max_bin_firingrate'                            	- maximum value of firing rate map
% 'max_bin_firingrate_refined                     	- maximum value of firing rate map, smoothed and refined

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TRACE MAPS (IN DEVELOPMENT) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'trace'                                           - trace map, original:                  raw Ca2+ activity map
% 'trace_smoothed'                                 	- trace map, smoothed:                  convolution with gauss kernel
% 'trace_refined'                                  	- trace map, refined:                   trace_smoothed thresholded
% 'trace_normalized'                               	- trace map, normalized:                trace_refined normalized to [0,1]
% 'trace_firingrate'                               	- trace firing rate map, original:      raw Ca2+ activity per time unit
% 'trace_firingrate_smoothed'                      	- trace firing rate map, smoothed:      convolution with gauss kernel
% 'trace_firingrate_refined'                       	- trace firing rate map, refined:       trace_firingrate_smoothed restricted
% 'trace_firingrate_normalized'                    	- trace firing rate map, normalized:    trace_firingrate_refined normalized to [0,1]

cellmaps = struct(...
    'exp', '', 'group', '', 'id', '', 'day', '', 'trial', '', ...
    'cell', [], 'spikes', [], 'spikes_count', [], ...
    'spike', [], 'spike_smoothed', [], 'spike_refined', [], 'spike_normalized', [], ...
    'firingrate', [], 'firingrate_smoothed', [], 'firingrate_refined', [], 'firingrate_normalized', [], ...
    'max_bin_spike', [], 'max_bin_spike_refined', [], 'max_bin_firingrate', [], 'max_bin_firingrate_refined', [] ...
    );

mouse.activity_map_summary.firingrate = zeros(mouse.size_map);                  % HeatMap of all activity map
mouse.activity_map_summary.firingrate_normalized = zeros(mouse.size_map);       % HeatMap of all normalized activity map

% MI table
cells_MI = zeros(7,mouse.cells_count_for_analysis);
cells_MI(1,1:mouse.cells_count_for_analysis)=linspace(1,mouse.cells_count_for_analysis,mouse.cells_count_for_analysis);

h = waitbar(1/mouse.cells_count_for_analysis, sprintf('MI calculation, cell %d of %d', 0,  mouse.cells_count_for_analysis));
for ncell = mouse.cells_active
    h = waitbar(ncell/mouse.cells_count_for_analysis,h, sprintf('MI calculation, cell %d of %d', ncell,  mouse.cells_count_for_analysis));
    
    % main mouse info
    cellmaps(ncell).exp = mouse.exp;
    cellmaps(ncell).id = mouse.id;
    cellmaps(ncell).day = mouse.day;
    cellmaps(ncell).trial = mouse.trial;
    cellmaps(ncell).cell = ncell;
    
    % spikes of cell info
    if mouse.params_main.vel_opt
        cellmaps(ncell).spikes = cells(ncell).spikes_in_mov_frames;
    else
        cellmaps(ncell).spikes = cells(ncell).spikes_all_frames;
    end
    cellmaps(ncell).spikes_count = length(cellmaps(ncell).spikes);
    
    % spike map calculation, original
    cellmaps(ncell).spike = zeros(mouse.size_map);
    for k = 1:cellmaps(ncell).spikes_count
        cellmaps(ncell).spike(mouse.y_ind(cellmaps(ncell).spikes(k)),mouse.x_ind(cellmaps(ncell).spikes(k))) = cellmaps(ncell).spike(mouse.y_ind(cellmaps(ncell).spikes(k)),mouse.x_ind(cellmaps(ncell).spikes(k))) + 1;
    end
    cellmaps(ncell).max_bin_spike = max(cellmaps(ncell).spike(:));
    
    % spike map calculation, smoothed
    if mouse.params_main.spike_smooth
        [cellmaps(ncell).spike_smoothed, ~] = convolution_with_holes(cellmaps(ncell).spike,mouse.mask_t,mouse.params_main.kernel_opt.small.size,mouse.params_main.kernel_opt.small.sigma);
    else
        cellmaps(ncell).spike_smoothed = cellmaps(ncell).spike;
    end    
    cellmaps(ncell).max_bin_spike_refined = max(cellmaps(ncell).spike_smoothed(:));
    
    % spike map calculation, refined
    cellmaps(ncell).spike_refined = cellmaps(ncell).spike_smoothed;
    if mouse.params_main.spike_threshold        
        cellmaps(ncell).spike_refined(cellmaps(ncell).spike_refined < mouse.params_main.spike_threshold * cellmaps(ncell).max_bin_spike_refined) = 0;
    end    
    
    % spike map calculation, normalized
    cellmaps(ncell).spike_normalized = cellmaps(ncell).spike_refined/cellmaps(ncell).max_bin_spike_refined;
    
    % spike map calculation, maximum value update    
    if mouse.max_bin.spike < cellmaps(ncell).max_bin_spike
        mouse.max_bin.spike =  cellmaps(ncell).max_bin_spike;
    end    
    if mouse.max_bin.spike_refined < cellmaps(ncell).max_bin_spike_refined
        mouse.max_bin.spike_refined = cellmaps(ncell).max_bin_spike_refined;
    end
    
%     % trace map calculation (IN DEVELOPMENT)
%     cellmaps(ncell).trace = zeros(mouse.size_map);
%     for frame = 1:mouse.duration_frames
%         cellmaps(ncell).trace(mouse.y_ind(frame), mouse.x_ind(frame)) = ...
%             cellmaps(ncell).trace(mouse.y_ind(frame), mouse.x_ind(frame)) + cells(ncell).trace(frame);
%     end
%     cellmaps(ncell).trace_firingrate = cellmaps(ncell).trace./mouse.ocuppancy_map.time_smoothed*mouse.params_main.MinTime;
%     cellmaps(ncell).trace_firingrate(isnan(cellmaps(ncell).trace_firingrate)) = 0;
%     cellmaps(ncell).trace_firingrate(isinf(cellmaps(ncell).trace_firingrate)) = 0;
    
    % firing rate map calculation, original
    cellmaps(ncell).firingrate = cellmaps(ncell).spike_refined./mouse.ocuppancy_map.time_smoothed*mouse.params_main.MinTime;
    cellmaps(ncell).firingrate(isnan(cellmaps(ncell).firingrate)) = 0;
    cellmaps(ncell).firingrate(isinf(cellmaps(ncell).firingrate)) = 0;    
    cellmaps(ncell).max_bin_firingrate = max(cellmaps(ncell).firingrate(:));
    
    % firing rate map calculation, smoothed
    [cellmaps(ncell).firingrate_smoothed, ~] = convolution_with_holes(cellmaps(ncell).firingrate,mouse.mask_t,mouse.params_main.kernel_opt.big.size,mouse.params_main.kernel_opt.big.sigma);
    cellmaps(ncell).max_bin_firingrate_refined = max(cellmaps(ncell).firingrate_smoothed(:));
    
  	% firing rate map calculation, tresholded
    cellmaps(ncell).firingrate_refined = cellmaps(ncell).firingrate_smoothed;
    if mouse.params_main.firing_threshold
        cellmaps(ncell).firingrate_refined(cellmaps(ncell).firingrate_refined < mouse.params_main.firing_threshold * cellmaps(ncell).max_bin_firingrate_refined) = 0;
    end
    
    % firing rate map calculation, normalized
    cellmaps(ncell).firingrate_normalized = cellmaps(ncell).firingrate_refined/cellmaps(ncell).max_bin_firingrate_refined;
    
    % firing rate map calculation, maximum value update       
    if mouse.max_bin.firingrate < cellmaps(ncell).max_bin_firingrate
        mouse.max_bin.firingrate =  cellmaps(ncell).max_bin_firingrate;
    end
    if mouse.max_bin.firingrate_refined < cellmaps(ncell).max_bin_firingrate_refined
        mouse.max_bin.firingrate_refined =  cellmaps(ncell).max_bin_firingrate_refined;
    end
    
    mouse.activity_map_summary.firingrate = mouse.activity_map_summary.firingrate + cellmaps(ncell).firingrate_refined;
    mouse.activity_map_summary.firingrate_normalized = mouse.activity_map_summary.firingrate_normalized + cellmaps(ncell).firingrate_normalized;
    
    %MI calculation
    cells_MI(2:5,ncell) = RandomShiftMod( ...
        mouse.params_main.smooth_freq_mode, ...
        cellmaps(ncell).spikes, ...
        mouse.velcam, ...
        mouse.x_ind, ...
        mouse.y_ind, ...
        mouse.mask_t, ...
        mouse.ocuppancy_map.time_smoothed, ...
        mouse.params_main.N_shift, ...
        mouse.params_main.shift, ...
        mouse.params_main.S_sigma, ...
        mouse.params_main.TimeRate, ...
        mouse.framerate, ...
        mouse.params_main.kernel_opt ...
        );
    
    
    cells_MI(6,ncell) = (cells_MI(3,ncell)-cells_MI(4,ncell))/cells_MI(5,ncell);
    cells_MI(7,ncell) = cellmaps(ncell).spikes_count;    
    
    cells(ncell).criterion_MI = cells_MI(2,ncell);
    cells(ncell).MI_bit = cells_MI(3,ncell);
    cells(ncell).MI_zscore = cells_MI(6,ncell);
    cells(ncell).MI_mean_shuffles = cells_MI(4,ncell);
    cells(ncell).MI_std_shuffles = cells_MI(5,ncell);

end
delete(h);

% stat data of informative and active (all not artifactual) cells
% MI for non active cells is 0
for i = mouse.cells_active_not
    cells(i).criterion_MI = 0;
end

mouse.cells_informative = find([cells.criterion_MI]);
mouse.cells_informative_count = length(mouse.cells_informative);
mouse.cells_informative_percent = round(mouse.cells_informative_count/mouse.cells_active_count*100,2);
mouse.cells_informative_MI_bit = [cells(mouse.cells_informative).MI_bit];
mouse.cells_informative_MI_bit_mean = round(mean(mouse.cells_informative_MI_bit),2);
mouse.cells_informative_MI_zscored = [cells(mouse.cells_informative).MI_zscore];
mouse.cells_informative_MI_zscored_mean = round(mean(mouse.cells_informative_MI_zscored),2);

mouse.cells_active_MI_bit = [cells(mouse.cells_active).MI_bit];
mouse.cells_active_MI_bit_mean = round(mean(mouse.cells_active_MI_bit),2);
mouse.cells_active_MI_zscored = [cells(mouse.cells_active).MI_zscore];
mouse.cells_active_MI_zscored_mean = round(mean(mouse.cells_active_MI_zscored),2);

if ~isempty(cells_MI)
    h = figure;
    histogram(cells_MI(6,:),ceil(sqrt(length(cells_MI(6,:)))+1));
    title('Histogram of cell''s MI', 'FontSize', mouse.params_main.FontSizeTitle);
    saveas(h, sprintf('%s\\%s_Histogram_MI.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
    delete(h);
end

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));

%heatmap for occupancy map
if mouse.plot_opt.Plot_FiringRate_Smooth
    PlotPC(mouse, 'firing rate', cells, cellmaps);
end

PlotPC(mouse, 'firing rate summary', cells, cellmaps);

%% calculation and plotting separate fields from activity maps

% SpikeFieldsN_sum = zeros(mouse.size_map(1),mouse.size_map(2),1); %sum of activity maps of all cell

% Field_thres_sum = zeros(mouse.size_map(1),mouse.size_map(2)); % sum of corrected activity map
% Field_thres_norm_sum = zeros(mouse.size_map(1),mouse.size_map(2)); % sum of corrected normalized activity map
% Field_thres_sum_IC = zeros(mouse.size_map(1),mouse.size_map(2)); % sum of inform corrected activity map
% Field_thres_sum_NOT_IC = zeros(mouse.size_map(1),mouse.size_map(2)); % sum of NOT inform corrected activity map
% Field_thres_norm_sum_IC = zeros(mouse.size_map(1),mouse.size_map(2)); % sum of inform corrected normalized activity map
% Field_thres_norm_sum_NOT_IC = zeros(mouse.size_map(1),mouse.size_map(2)); % sum of NOT inform corrected normalized activity map

Fields(1:9,1)=0;
MapFields = zeros(mouse.size_map(1),mouse.size_map(2),1); %activity map of all fields made from freq_filt

wfields = 0; %number of fields from all cells
for map = mouse.cells_informative
% a = [mouse.cells_informative(1:33)];
% %   for map = a
%       for map = 93
    if mouse.params_main.vel_opt
        spike_t_good = cells(map).spikes_in_mov_frames;
    else
        spike_t_good = cells(map).spikes_all_frames;
    end
    
    % watershed transform
    N_water = -cellmaps(map).firingrate_refined;
    L = watershed(N_water);
    
    [n_wfield,mask_wfield, spike_in_field] = WaterShedField(L, spike_t_good, mouse.x*mouse.behav_opt.pxl2sm, mouse.y*mouse.behav_opt.pxl2sm, mouse.params_main.bin_size);
    
    wfields = wfields+n_wfield;
%     disp(wfields);
    for mask_field=1:n_wfield
        Fields(1,wfields-n_wfield+mask_field) = map;
        Fields(2,wfields-n_wfield+mask_field) = mask_field;
        Fields(8,wfields-n_wfield+mask_field) = length([spike_in_field{mask_field,:}]);
        
        switch mouse.params_main.PC_criterion
%             case 'Peak'
%                 orig_peaks = [];
%                 for mask_field=1:n_wfield
%                     orig_peaks = [orig_peaks max(max(cellmaps(ncell).firingrate_refined2.*mask_wfield(:,:,mask_field)/max(max(mask_wfield(:,:,mask_field)))))];
%                 end
%                 [true_fields, mu_fields, sigma_fields, Nsig_fields] = PeakShift(spike_t_good, mouse.mask_t, N_time_sm, mouse.x_ind, mouse.y_ind, orig_peaks, mouse.params_main.N_shift, mouse.params_main.shift, mouse.params_main.S_sigma);
%                 Fields(3,wfields-n_wfield+mask_field) = true_fields(mask_field);
%                 Fields(4,wfields-n_wfield+mask_field) = orig_peaks(mask_field);
%                 Fields(5,wfields-n_wfield+mask_field) = mu_fields;
%                 Fields(6,wfields-n_wfield+mask_field) = sigma_fields;
%                 Fields(7,wfields-n_wfield+mask_field) = Nsig_fields(mask_field);
%                 Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>params_main.min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
            case 'MI_vanila'
                Fields(3:7,wfields-n_wfield+mask_field) = cells_MI(2:6,map);
                Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>=params_main.min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
            case 'MI_vanila_fields'
                Fields(3:6,wfields-n_wfield+mask_field) = RandomShiftMod(params_main.smooth_freq_mode,[spike_in_field{mask_field,:}],mouse.x_ind,mouse.y_ind,N_time_sm,params_main.N_shift,params_main.shift,params_main.S_sigma,mouse.params_main.TimeRate,session.framerate,params_main.kernel_opt);
                Fields(7,wfields-n_wfield+mask_field) = (Fields(4,wfields-n_wfield+mask_field)-Fields(5,wfields-n_wfield+mask_field))/Fields(6,wfields-n_wfield+mask_field);
                Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>params_main.min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
        end
        
        % calculation separate field
        MapFields(:,:,wfields-n_wfield+mask_field) = cellmaps(map).firingrate_refined.*mask_wfield(:,:,mask_field)/max(max(mask_wfield(:,:,mask_field)));
        
%         if mouse.plot_opt.Plot_FiringRate_Fields
%             h = figure('Position', mouse.params_main.Screensize);
%             DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,MapFields(:,:,wfields-n_wfield+mask_field), 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,[spike_in_field{mask_field,:}]);
%             title(sprintf('Firing rate of cell %d field %d Crit= %d \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f', map, mask_field,Fields(3:7,wfields-n_wfield+mask_field)), 'FontSize', 10);
%             saveas(h, sprintf('%s\\Heatmap_FiringRate_Fields\\%s_FiringRateFields_Cell_%d_Field_%d.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut,map,mask_field));
%             delete(h);
%         end
        
%         %calculating activity map for separated fields
%         cellmaps(ncell).spike = zeros(mouse.size_map(1),mouse.size_map(2));
%         N_thres = zeros(mouse.size_map(1),mouse.size_map(2));        
%         for k=1:length([spike_in_field{mask_field,:}])
%             cellmaps(ncell).spike(mouse.y_ind([spike_in_field{mask_field,k}]),mouse.x_ind([spike_in_field{mask_field,k}]))=cellmaps(ncell).spike(mouse.y_ind([spike_in_field{mask_field,k}]),mouse.x_ind([spike_in_field{mask_field,k}]))+1;
%         end
%         
%         %smoothing of spike's number
%         if mouse.params_main.spike_smooth
%             [cellmaps(ncell).spike_refined, ~] = ConvBorderFix(cellmaps(ncell).spike,mouse.mask_t,params_main.kernel_opt.small.size,params_main.kernel_opt.small.sigma);
%             for ii=1:mouse.size_map(1)
%                 for jj=1:mouse.size_map(2)
%                     if cellmaps(ncell).spike_refined(ii,jj)>=params_main.thres_spike*max(max(cellmaps(ncell).spike_refined))
%                         N_thres(ii,jj) = cellmaps(ncell).spike_refined(ii,jj);
%                     end
%                 end
%             end
%             cellmaps(ncell).firingrate = N_thres./N_time_sm*mouse.params_main.MinTime;
%         else
%             cellmaps(ncell).firingrate = cellmaps(ncell).spike./N_time*mouse.params_main.MinTime;
%         end
%         
%         cellmaps(ncell).firingrate(isnan(cellmaps(ncell).firingrate)) = 0;
%         cellmaps(ncell).firingrate(isinf(cellmaps(ncell).firingrate)) = 0;
%         [cellmaps(ncell).firingrate_refined, ~] = ConvBorderFix(cellmaps(ncell).firingrate,mouse.mask_t,params_main.kernel_opt.big.size,params_main.kernel_opt.big.sigma);
%         max_TR = max(max(cellmaps(ncell).firingrate_refined));
%         cellmaps(ncell).firingrate_refined_norm = cellmaps(ncell).firingrate_refined;
%         
%         cellmaps(ncell).firingrate_refined_normalized = cellmaps(ncell).firingrate_refined_norm;
%         cellmaps(ncell).firingrate_refined_normalized(cellmaps(ncell).firingrate_refined_norm < mouse.params_main.thres_firing * max_TR) = 0;
%         
%         max_TR_t = max(max(cellmaps(ncell).firingrate_refined_normalized));
%         min_TR_t = min(min(cellmaps(ncell).firingrate_refined_normalized));
%         
%         Field_thres_sum = Field_thres_sum + cellmaps(ncell).firingrate_refined_normalized;
%         Field_thres_norm_sum = (cellmaps(ncell).firingrate_refined_normalized-min_TR_t)/(max_TR_t-min_TR_t)+Field_thres_norm_sum;
%         
%         if Fields(9,wfields-n_wfield+mask_field)
%             Field_thres_sum_IC = Field_thres_sum_IC + cellmaps(ncell).firingrate_refined_normalized;
%             Field_thres_norm_sum_IC = Field_thres_norm_sum_IC + (cellmaps(ncell).firingrate_refined_normalized-min_TR_t)/(max_TR_t-min_TR_t);
%         else
%             Field_thres_sum_NOT_IC = Field_thres_sum_NOT_IC + cellmaps(ncell).firingrate_refined_normalized;
%             Field_thres_norm_sum_NOT_IC = Field_thres_norm_sum_NOT_IC + (cellmaps(ncell).firingrate_refined_normalized-min_TR_t)/(max_TR_t-min_TR_t);
%         end
        
%         MapFieldsCorrected(:,:,wfields-n_wfield+mask_field) = cellmaps(ncell).firingrate_refined_normalized;
        
        if mouse.plot_opt.Plot_FiringRate_Fields_Corrected
            if Fields(9,wfields-n_wfield+mask_field)

                draw_heatmap( ...
                    mouse.behav_opt.rgb_image, ...
                    mouse.params_main.heatmap_opt.spike, ...
                    MapFields(:,:,wfields-n_wfield+mask_field), ...
                    cellmaps(map).max_bin_firingrate_refined, ...
                    mouse.x_track, ...
                    mouse.y_track, ...
                    mouse.shift, ...
                    mouse.behav_opt.x_kcorr, ...
                    mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
                    [spike_in_field{mask_field,:}] ...
                    );
                
                title(sprintf('Firing rate of informative field %d of cell %d (smoothed and thresholded)(#/min) \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f',mask_field,map,Fields(4:7,wfields-n_wfield+mask_field)), 'FontSize', mouse.params_main.FontSizeTitle);
                saveas(gcf, sprintf('%s\\Heatmap_FiringRate_Fields_Corrected_Inform\\%s_FiringRate_Fields_Corrected_Inform_Cell_%d_Field_%d.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut,map,mask_field));
                delete(gcf);
            else
%                 h = figure('Position', mouse.params_main.Screensize);
%                 DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).firingrate_refined_normalized, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
%                 title(sprintf('Firing rate of NOT informative field %d of cell %d (smoothed and thresholded)(#/min) \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f',mask_field,map,Fields(4:7,wfields-n_wfield+mask_field)), 'FontSize', 10);
%                 saveas(h, sprintf('%s\\Heatmap_FiringRate_Fields_Corrected_NOT_Inform\\%s_FiringRate_Fields_Corrected_NOT_Inform_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,wfields-n_wfield+mask_field));
%                 delete(h);
            end
        end
        
%         if mouse.plot_opt.Plot_WaterShedField
%             h = figure('Position', mouse.params_main.Screensize);
%             DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,double(mask_wfield(:,:,mask_field)), 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
%             title(sprintf('WaterShed Transform of cell %d field %d ICcrit= %d \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f', map, mask_field,Fields(3:7,wfields-n_wfield+mask_field)), 'FontSize', mouse.params_main.FontSizeTitle);
%             saveas(h, sprintf('%s\\WaterShedFields\\%s_WaterShedField_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,wfields-n_wfield+mask_field));
%             delete(h);
%         end
    end
    
    %watershed plot
%     if mouse.plot_opt.Plot_WaterShed
%         h = figure('Position', mouse.params_main.Screensize);
%         DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,double(L), 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr, [spike_in_field{mask_field,:}]);
%         title(sprintf('WaterShed Transform of cell %d Crit= %d \n IC = %.2f, MU = %.3f, SIGMA = %.3f, Nsig = %.1f', map, cells_MI(2:6,map)), 'FontSize', mouse.params_main.FontSizeTitle);
%         saveas(h, sprintf('%s\\WaterShed\\%s_WaterShed_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,map));
%         delete(h);
%     end
end


% % FiringRate plots
% h = figure('Position', mouse.params_main.Screensize);
% DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.track,Field_thres_sum, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,spike_t_good);
% title('Firing rate for all corrected fields(#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
% saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRate.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
% delete(h);
% 
% h = figure('Position', mouse.params_main.Screensize);
% DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.track,Field_thres_norm_sum, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,spike_t_good);
% title('Firing rate for all corrected fields (normalized) (#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
% saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRate_Normalized.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
% delete(h);

% % FiringRate Informative plots
% h = figure('Position', mouse.params_main.Screensize);
% DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.track,Field_thres_sum_IC, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,spike_t_good);
% title('Firing rate for all INFORM corrected fields(#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
% saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateInform.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
% delete(h);
% h = figure('Position', mouse.params_main.Screensize);
% DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.track,Field_thres_norm_sum_IC, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,spike_t_good);
% title('Firing rate for all INFORM corrected fields (normalized)(#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
% saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateInform_Normalized.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
% delete(h);

% % FiringRate NOT Informative plots
% h = figure('Position', mouse.params_main.Screensize);
% DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.track,Field_thres_sum_NOT_IC, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,spike_t_good);
% title('Firing rate for all NOT inform corrected fields (#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
% saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateNOTInform.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
% delete(h);
% h = figure('Position', mouse.params_main.Screensize);
% DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.track,Field_thres_norm_sum_NOT_IC, 0, mouse.x, mouse.y, mouse.bin_size, Options.x_kcorr,spike_t_good);
% title('Firing rate for all NOT inform corrected fields (normalized)(#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
% saveas(h, sprintf('%s\\%s_Heatmap_AllFields_FiringRateNOTInform_Normalized.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
% delete(h);

% if length(Fields(7,:))>2
%     h = figure;
%     histogram(Fields(7,:),round(length(Fields(7,:))/5));
%     title('Histogram of z-scored IC distribution for fields', 'FontSize', mouse.params_main.FontSizeLabel);
%     saveas(h, sprintf('%s\\%s_Histogram_IC_fields_normalized.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
%     delete(h);
% end

% if length(cells_MI(1,:))>2
%     h = figure;
%     histogram(cells_MI(6,cells_MI(2,:)>=0),round(length(cells_MI(6,:))/5));
%     title('Histogram of z-scored IC distribution for cells', 'FontSize', mouse.params_main.FontSizeLabel);
%     saveas(h, sprintf('%s\\%s_Histogram_IC_cells_normalized.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
%     delete(h);
% end

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));

%% searching of real Place Fields

N_inf=1;
% N_not_inf=1;
MapFieldsIC = [];
FieldsIC = [];
MapFieldsCorrected = MapFields;
for nfield=1:length(Fields(9,:))
    if Fields(9,nfield)
        MapFieldsIC(:,:,N_inf) = MapFieldsCorrected(:,:,nfield); %only informative fields
        FieldsIC(:,N_inf) = Fields(:,nfield);
        N_inf=N_inf+1;
    else
%         MapFieldsNotIC(:,:,N_not_inf) = MapFieldsCorrected(:,:,nfield); %only not informative fields
%         N_not_inf=N_not_inf+1;
    end
end

if ~isempty(MapFieldsIC)
   SpikeFieldsStruct = struct('cell',[],'fields',[],'inform',[],'x_mass',[],'y_mass',[]);
    n_field=1;
    for ncell=1:size(MapFieldsIC,3)
        IMG = MapFieldsIC(:,:,ncell);
        [L,n_segments] = bwlabel(IMG);
        RegionsInMask(n_field) = n_segments;
        mask = zeros(mouse.size_map(1),mouse.size_map(2),n_segments);
        for nfield=1:n_segments
            for ii=1:mouse.size_map(1)
                for jj=1:mouse.size_map(2)
                    if L(ii, jj) == nfield
                        mask(ii,jj,nfield)=1;
                    end
                end
            end
        end
        IMG_mask = mask;
        for nfield=1:n_segments
            IMG_mask(:,:,nfield) = IMG.*mask(:,:,nfield);
        end
        %must be fixed!!!
        n_segments=1;
        
        %searching of centre of mass
        for i=1:n_segments
            SUM = IMG_mask(:,:,i);
            tot_mass = sum(SUM(:));
            [ii,jj] = ndgrid(1:size(SUM,1),1:size(SUM,2));
            SpikeFieldsStruct(n_field).cell = FieldsIC(1,ncell);
            SpikeFieldsStruct(n_field).fields = FieldsIC(2,ncell);
            SpikeFieldsStruct(n_field).inform = FieldsIC(9,ncell);
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
    
    SpikeFieldsStruct1 = SpikeFieldsStruct;

    for i=1:length(SpikeFieldsStruct)
        SpikeFieldsStruct1(i).x_mass = round(SpikeFieldsStruct(i).x_mass);
        SpikeFieldsStruct1(i).y_mass = round(SpikeFieldsStruct(i).y_mass);
    end
    
    %saving fields content
%     writetable(struct2table(SpikeFieldsStruct1), sprintf('%s\\%s_Fields_IC.csv',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
    
    % !!!
    SpikeFieldsReal = SpikeFieldsStruct;
    % !!!
    
    x_shift = 0;
    y_shift = 0;
    
    %ploting all good field on one figure
    xrealms = zeros(1,length(SpikeFieldsReal));
    yrealms = zeros(1,length(SpikeFieldsReal));
    if ~isempty(SpikeFieldsReal(1).cell)
        for i=1:length(SpikeFieldsReal)
            xrealms(i) = SpikeFieldsReal(i).x_mass+x_shift;
            yrealms(i) = SpikeFieldsReal(i).y_mass+y_shift;
            SpikeFieldsReal(i).x_mass_real = (xrealms(i)+0.5)*mouse.params_main.bin_size;
            SpikeFieldsReal(i).y_mass_real = (yrealms(i)+0.5)*mouse.params_main.bin_size;
        end
%         
%         h = figure('Position', mouse.params_main.Screensize);
%         axis(mouse.axes); hold on;
%         plot(mouse.x, mouse.y, 'b');
%         title('All real fields', 'FontSize', mouse.params_main.FontSizeTitle);
%         shift_center = 0.5;
%         hold on;plot((xrealms+shift_center)*mouse.params_main.bin_size,(yrealms+shift_center)*mouse.params_main.bin_size,'k*','MarkerSize',5,'LineWidth',mouse.params_main.LineWidthSpikes);
%         saveas(h, sprintf('%s\\%s_Fields_Real_Centers.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
%         delete(h);  

        
        %histogram of field's number
        test_zone4 = zeros(1,length(SpikeFieldsReal));
        for i=1:length(SpikeFieldsReal)
            test_zone4(i) = SpikeFieldsReal(i).cell;
        end
        
        test_zone5 = zeros(1,mouse.cells_count_for_analysis);
        for i=1:mouse.cells_count_for_analysis
            test_zone5(i) = length(find(test_zone4==i));
        end
        
        h = figure;
        histogram(test_zone5,max(test_zone5)+1);
        title('Histogram of fields number', 'FontSize', mouse.params_main.FontSizeTitle);
        saveas(h, sprintf('%s\\%s_Fields per cell distribution.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
        delete(h);        

        results(1) = size(SpikeFieldsStruct,2); %total candidate fields
        results(2) = size(SpikeFieldsReal,2); %total real fields
        r_results = round(results);
        
        %save results
        prmtr=fopen(sprintf('%s\\%s_FieldsCupStat.txt',mouse.params_paths.pathOut, mouse.params_paths.filenameOut),'w');
        fprintf(prmtr,'All fields Real fields\n');
        fprintf(prmtr, '%d %d\n',r_results(1), r_results(2));
        fclose(prmtr);
    end
end

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
end
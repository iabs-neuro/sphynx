function PlaceMapsAnalyzer(params_paths, params_main)
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
    params_paths.pathOut = uigetdir('w:\Projects\MSS\ActivityData\PlaceCells\', 'Please specify the path to save the data');
    
    %loading videotracking
    [params_paths.filenameWS, params_paths.pathWS]  = uigetfile('*.mat','Please specify the mat-file from behavior analysis','w:\Projects\MSS\ActivityData\Behav_mat\');
    
    %loading spike file
    [params_paths.filenameNV, params_paths.pathNV]  = uigetfile('*.csv','Please specify the file with spikes','w:\Projects\MSS\ActivityData\Spikes\');
    
    %loading trace file
    [params_paths.filenameTR, params_paths.pathTR]  = uigetfile('*.csv','Please specify the file with traces','w:\Projects\MSS\ActivityData\Traces\');
    
    %loading preset file
    [params_paths.filenamePR, params_paths.pathPR]  = uigetfile('*.mat','Please specify the preset file','w:\Projects\MSS\ActivityData\Presets\');
    
end

if ~exist('params_main', 'var') || isempty(params_main)
    
    params_main = struct(...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SYNCHRONIZATION OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'CorrectionTrackMode', 'Bonsai',...             % different modes for correction syncronization of behavior and calcium data {'NVista', 'FC', 'Bonsai', 'none'}
        'coordinates_correction', 0,...                 % 1 if you need in interpolation and smoothing of videotracking data
        'test_mode', 10,...                             % 0 for all cells analysis else number of n first cells
        'start_frame', 1,...                            % frame of the first frame for analysis
        'app_frame', 1,...                              % frame of the first frame "mouse in cage" (at last paradigm od analysis - is the same frame like a srart
        'end_frame', 0,...                              % frame of the last frame for analysis
        'TimeMode', 's',...                             % 's' for 3-20 min duration of session, 'min' - for 30-60 min duration of session
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DIFFERENT ANALYSIS MODES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'MI_calculate', 1, ...                          % 1 - if you want calculate MI
        'PC_criterion', 'MI_vanila',...                 % method for criterion of Place Cells: 'Peak' - schuffled peak of activity, 'MI_vanila' - Mutual Information for cells,  'MI_vanila_fields' - Mutual Information for fields
        'bin_size_cm', 4,...                            % size of bins in cm
        'heatmap_border', 1,...                         % additional bins number on the edges of the HeatMaps
        'S_sigma', 2.29,...                             % criteria for informative place cell(1.65 for p = 0.05, 2.29 for p = 0.01, 3,09 for p = 0.001)
        'N_shift', 1000,...                             % number of shift for random distribution
        'shift', 0.9,...                                % percent of all time occupancy for random shift
        'kernel_opt', struct(...                        % gaussian kernel options for activity maps calculation
            'small', struct('size', 3, 'sigma', 1.0),...    % small size and sigma kernel, for spike maps
            'big', struct('size', 5, 'sigma', 1.0),...    	% bigger size and sigma kernel, for firing rate maps
            'trace', struct('size', 3, 'sigma', 1.0)),...  	% size and sigma kernel, for trace firing rate maps
        ...
        'activity_map_opt', struct(...                  % flags and parameters for activity maps calculation
            'visual', struct(...                        % for visualization of activity maps
                'spike',  struct('smooth', 1, 'threshold', 0.1), ...    % for spike maps calculation
                'firing', struct('smooth', 1, 'threshold', 0.5), ... 	% for firing rate maps calculation
                'trace', struct('smooth', 1, 'threshold', 0.2)), ...    % for trace maps calculation
            'mi', struct(...                            % for mi calculation of activity maps
                'spike',  struct('smooth', 1, 'threshold', 0.1), ...    % for spike maps calculation
                'firing', struct('smooth', 1, 'threshold', 0.1), ... 	% for firing rate maps calculation
                'trace', struct('smooth', 1, 'threshold', 0.1))), ...  	% for trace maps calculation
        'activity_map_split', 5, ...                    % if you want to create several FR maps
        'vel_opt', 0, ...                               % 1 - MI calculated with respond to velocity (only locomotion included)
        'vel_border', 5,...                             % velocity threshold in cm/s
        ...
        'min_spike', 1,...                              % minimum number of spikes for active cell
        'min_spike_MI', 3,...                           % minimum number of spikes for MI calculation (not used right now)
        'min_spike_field', 3,...                        % minimum number of spikes for place field (not used right now)
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TEMPORAL PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'SmoothWindowS', 0.5,...                        % smoothing window in seconds for behavior analysis (in case non-smoothed data)
        'time_smooth', 1,...                            % flag for smoothing of occupancy map
        'length_line_sec', 0.5,...                      % min time for acts (in area of fields or velocity binary timeseries)
        'snr_params', struct('percentile', 50),...      % percent of signal to identify noise lvl in neuron trace
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SUPPORTING PLOTS AND VERBOSE PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'verbose', 1,...                                % additional messages
        'plot_mode', 1,...                              % main plot parameters, 0 - no one plots, 1 - basic plots, 2 - all plots
        'plot_trace', 1, ...                             % plot trace maps
        'Screensize', get(0, 'Screensize'),...          % screensize for all plotting 
        'axes_step', 1,...                              % in cm
        'heatmap_opt', struct( ...
            'track', struct('trackp', 1, 'textl', 1, 'scale', 1, 'transp', 1, 'fon', 1, 'spike_opt', 0),...
            'spike', struct('trackp', 0, 'textl', 1, 'scale', 1, 'transp', 1, 'fon', 1, 'spike_opt', 1),...
            'trace', struct('trackp', 0, 'textl', 1, 'scale', 1, 'transp', 0.8, 'fon', 1, 'spike_opt', 1)), ...
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
'split_frames', [], ...                 % session timeline in frames for split mode
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'params_main', [], ...                  % main PC analysis parameters
'params_paths', [], ...                 % paths and names PC analysis parameters
'behav_opt', [], ...                    % all behavior parameters from SPHYNX
'arena_opt', [], ...                    % arena spatial parameters from SPHYNX
'plot_opt', [], ...                     % main plots parameters
'axes', [], ...                         % axes parameters for maps plot
...'params_main.bin_size', [], ...         % size of bin for Heatmaps and MI calculations in pixels
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
'rest_percent', [], ...                 % percent of session in rests
'space_explored', [], ...               % percent of explored area
'size_map', [], ...                     % size of all maps in analysis (occupancy, activity)
'occupancy_map', struct( ...            % struct for occupancy maps:
    'frame', [], ...                        % occupancy map in frames
    'time', [], ...                         % occupancy map in seconds (or minutes)
    'time_restricted', [], ...              % occupancy map in seconds without very low bins
    'time_smoothed', [], ...              	% occupancy map, restricted ans smoothed
   	'time_smoothed_min', [], ...            % occupancy map, restricted ans smoothed in minutes
    'frame_split', []), ...                 % occupancy splitted map in frames for split mode
'mask_t', [], ...                       % mask for all maps in related to unvisited bins
'max_bin', struct( ...                  % struct of maxima in bins of different maps:
    'spike', 0, ...                         % maximum in bins of all spikes maps
    'spike_refined', 0, ...                 % maximum in bins of all refined spikes maps
    'firingrate', 0, ...                    % maximum in bins of all firing rate maps
    'firingrate_refined', 0, ...            % maximum in bins of all refined firing rate maps
   	'trace', 0, ...                         % maximum in bins of all trace maps
    'trace_refined', 0), ...                % maximum in bins of all refined trace maps
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL. GENERAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cells_indexes', [], ...                    % indexes of all cells
'cells_count', [], ...                      % count of all cells
'cells_for_analysis_indexes', [], ...       % indexes of all cells for analysis in test mode
'cells_for_analysis_count', [], ...         % count of cells for analysis in test mode
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL. ACTIVE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cells_active', [], ...                     % indexes of active cells
'cells_active_not', [], ...                 % indexes of non active cells
'cells_active_count', [], ...               % count of active cells
'cells_active_percent', [], ...             % percent of active cells (to cells_count)
'cells_active_firingrate', [], ...          % firing rate of active cells
'cells_active_firingrate_mean', [], ...     % mean firing rate of active cells
'cells_active_MI_bit_event', [], ...       	% MI of active cells (in bit/Ca2+)
'cells_active_MI_bit_event_mean', [], ...  	% mean MI of active cells (in bit/Ca2+)
'cells_active_MI_bit_time', [], ...       	% MI of active cells (in bit/min)
'cells_active_MI_bit_time_mean', [], ...   	% mean MI of active cells (in bit/min)
'cells_active_MI_zscored', [], ...          % MI of active cells (zscored)
'cells_active_MI_zscored_mean', [], ...     % mean MI of active cells (zscored)
'activity_map_summary', struct( ...         % struct of summary activity maps
    'firingrate', [], ...                       % summary of firing rate maps of active cells
    'firingrate_normalized', [], ...            % summary of normalized firing rate maps of active cells
   	'trace_firingrate', [], ...                	% summary of trace maps of active cells
    'trace_firingrate_normalized', []), ...    	% summary of normalized trace maps of active cells
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CELL. INFORMATIVE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cells_informative', [], ...                    % indexes of informative cells
'cells_informative_count', [], ...              % count of informative cells
'cells_informative_percent', [], ...            % percent of informative cells (to active cells)
'cells_informative_firingrate', [], ...         % firing rate of active cells
'cells_informative_firingrate_mean', [], ...    % mean firing rate of informative cells
'cells_informative_MI_bit_event', [], ...       % MI of informative cells (in bit/Ca2+)
'cells_informative_MI_bit_event_mean', [], ...	% mean MI of informative cells (in bit/Ca2+)
'cells_informative_MI_bit_time', [], ...       	% MI of informative cells (in bit/min)
'cells_informative_MI_bit_time_mean', [], ...  	% mean MI of informative cells (in bit/min)
'cells_informative_MI_zscored', [], ...         % MI of informative cells (zscored)
'cells_informative_MI_zscored_mean', [] ...     % mean MI of informative cells (zscored)
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
%         session.duration_s = 600;
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
fprintf('Время сессии: %d секунд (%2.1f минут)\n', round(session.duration_s), session.duration_min);
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
    mouse.cells_for_analysis_count = mouse.cells_count;
    mouse.cells_for_analysis_indexes = mouse.cells_indexes;
else
    mouse.cells_for_analysis_count = min(mouse.params_main.test_mode, mouse.cells_count);
    mouse.cells_for_analysis_indexes = 1:mouse.cells_for_analysis_count;
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
mouse.rest_percent = 100 - mouse.locomotion_percent;

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

cells = struct(...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MOUSE INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'exp', '', ...                              - experiment identifier (e.g. 'FOF', 'NOF', '3DM' 'MSS')
'group', '', ...                            - experimental group of animal (e.g. 'Control', 'FAD')
'id', '', ...                               - mouse identifier (e.g. 'F01', 'H39')
'day', '', ...                              - day number of registration (e.g. '1D', '6D')
'trial', '', ...                            - trial number of registration (e.g. '1T', '6T')
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAIN CELL INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cell', [], ...                             - cell number (same order in trace or spike table)
'trace', [], ...                            - raw cell activity signal from CaImAn
'SNR_baseline', [], ...                     - signal-to-noise ratio in dB, Baseline-Based Method
'SNR_peak', [], ...                         - signal-to-noise ratio in dB, Peak Method
'SNR', [], ...                              - average signal-to-noise ratio in dB calculated on raw signal
'criterion_activity', [], ...               - 1 - if cell passed activity criteria
'criterion_MI', [], ...                     - 1 - if cell passed information criteria
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SPIKES STATISTICS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% all spikes %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'spikes_all_count', [], ...                 - count of all Ca2+ events
'spikes_all_frames', [], ...                - timestamps of all Ca2+ events ('1' in spikes table)
'spikes_all_frequency', [], ...             - frequency of all Ca2+ events during session (Ca2+/min)
'spikes_all_amplitude', [], ...             - all Ca2+ events amplitude 
'spikes_all_mean_amplitude', [], ...        - mean all Ca2+ events amplitude 
'spikes_all_peak_amplitude', [], ...        - maximum amplitude of Ca2+ events
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% in movements spikes %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'spikes_in_mov_count', [], ...              - count of all Ca2+ events
'spikes_in_mov_frames', [], ...             - timestamps of all Ca2+ events ('1' in spikes table)
'spikes_in_mov_frequency', [], ...          - frequency of all Ca2+ events during session (Ca2+/min)
'spikes_in_mov_amplitude', [], ...          - all Ca2+ events amplitude 
'spikes_in_mov_mean_amplitude', [], ...     - mean all Ca2+ events amplitude 
'spikes_in_mov_peak_amplitude', [], ...     - maximum amplitude of Ca2+ events
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% in rests spikes %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'spikes_in_rest_count', [], ...             - count of all Ca2+ events
'spikes_in_rest_frames', [], ...            - timestamps of all Ca2+ events ('1' in spikes table)
'spikes_in_rest_frequency', [], ...         - frequency of all Ca2+ events during session (Ca2+/min)
'spikes_in_rest_amplitude', [], ...         - all Ca2+ events amplitude 
'spikes_in_rest_mean_amplitude', [], ...    - mean all Ca2+ events amplitude 
'spikes_in_rest_peak_amplitude', [], ...    - maximum amplitude of Ca2+ events
'frequency_ratio_mov_rest', [], ...       	- ratio of 'spikes_in_mov_frequency'/'spikes_in_rest_frequency'
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MUTUAL INFORMATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'MI_bit_event', [], ...                     - original MI in bits/Ca2+
'MI_bit_time', [], ...                      - original MI in bits/minute
'MI_zscore', [], ...                        - z-scored MI
'MI_mean_shuffles', [], ...                 - mean MI on shuffled set
'MI_std_shuffles', [] ...                   - std MI on shuffled set
);

for ncell = mouse.cells_for_analysis_indexes
    
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
    
    if mouse.params_main.vel_opt  
        cells(ncell).criterion_activity = double((cells(ncell).spikes_in_mov_count >= mouse.params_main.min_spike));
    else
        cells(ncell).criterion_activity = double((cells(ncell).spikes_all_count >= mouse.params_main.min_spike));
    end
    
end

% defining stats for cell count
mouse.cells_active = find([cells.criterion_activity]);
mouse.cells_active_not = find(~[cells.criterion_activity]);
mouse.cells_active_count = sum([cells.criterion_activity]);
mouse.cells_active_percent = round(mouse.cells_active_count/mouse.cells_for_analysis_count*100, 2);
if mouse.params_main.vel_opt
    mouse.cells_active_firingrate = [cells(mouse.cells_active).spikes_in_mov_frequency];
else
    mouse.cells_active_firingrate = [cells(mouse.cells_active).spikes_all_frequency];    
end
mouse.cells_active_firingrate_mean = round(mean(mouse.cells_active_firingrate),2);

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

% calculate occupancy_map.frame time spent in bins in frames 
mouse.occupancy_map.frame = zeros(mouse.size_map);
for d=1:mouse.duration_frames
    mouse.occupancy_map.frame(mouse.y_ind(d),mouse.x_ind(d)) = mouse.occupancy_map.frame(mouse.y_ind(d),mouse.x_ind(d))+1*mouse.velcam(d);
end

% several occupancy maps for split mode
if mouse.params_main.activity_map_split
    mouse.split_frames = cell(1,mouse.params_main.activity_map_split);
    for split = 1 : mouse.params_main.activity_map_split
        mouse.split_frames{split} = (1+round((split-1)/mouse.params_main.activity_map_split*mouse.duration_frames):round(split/mouse.params_main.activity_map_split*mouse.duration_frames));
        mouse.occupancy_map.frame_split{split} = zeros(mouse.size_map);
        for d=mouse.split_frames{split}
            mouse.occupancy_map.frame_split{split}(mouse.y_ind(d),mouse.x_ind(d)) = mouse.occupancy_map.frame_split{split}(mouse.y_ind(d),mouse.x_ind(d))+1*mouse.velcam(d);
        end
    end
end

% calculate occupancy_map.time time spent in bins in minutes/seconds
mouse.occupancy_map.time = mouse.occupancy_map.frame/mouse.framerate/mouse.params_main.TimeRate;

% calculate occupancy_map.time_restricted time spent in bins in
% minutes/seconds, excluded not enough occupied 
mouse.occupancy_map.time_restricted = mouse.occupancy_map.time;
mouse.occupancy_map.time_restricted(mouse.occupancy_map.time<mouse.params_main.time_min/mouse.params_main.TimeRate) = 0;

% calculate occupancy_map.time_smoothed time spent in bins in minutes/seconds, smoothed
mouse.occupancy_map.time_smoothed = mouse.occupancy_map.time_restricted;
if mouse.params_main.time_smooth
    [mouse.occupancy_map.time_smoothed,mouse.mask_t] = convolution_with_holes(mouse.occupancy_map.time_smoothed,0,mouse.params_main.kernel_opt.small.size,mouse.params_main.kernel_opt.small.sigma);
end

% calculate occupancy map in minutes (for MI calculations)
mouse.occupancy_map.time_smoothed_min = mouse.occupancy_map.time_smoothed/mouse.params_main.MinTime;

% define explored space. Correction if % > 100
mouse.space_explored = min(100, round(length(find(mouse.occupancy_map.time_smoothed>0))*mouse.params_main.bin_size_cm^2/mouse.behav_opt.arena_area*100,1));

%heatmap for occupancy map
PlotPC(mouse, 'occupancy');

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));

%% Maps for cell activity defining, MI calculation

% description and defining struct CELLMAPS
cellmaps = struct(...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MOUSE INFO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'exp', '', ...                              - experiment identifier (e.g. 'FOF', 'NOF', '3DM' 'MSS')
'group', '', ...                            - experimental group of animal (e.g. 'Control', 'FAD')
'id', '', ...                               - mouse identifier (e.g. 'F01', 'H39')
'day', '', ...                              - day number of registration (e.g. '1D', '6D')
'trial', '', ...                            - trial number of registration (e.g. '1T', '6T')
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SPIKE AND FIRINGRATE MAPS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'cell', [], ...                           	- index of cell
'spikes', [], ...                          	- timestamps of relevant Ca2+ events
'spikes_count', [], ...                    	- count of relevant Ca2+ events
'spike', [], ...                           	- spike map, original:          count of Ca2+ events
'spike_smoothed', [], ...                  	- spike map, smoothed:          convolution with gauss kernel
'spike_refined', [], ...                   	- spike map, refined:           spike_smoothed thresholded
'spike_normalized', [], ...                	- spike map, normalized:        spike_refined normalized to [0,1]
'firingrate', [], ...                      	- firing rate map, original:    count Ca2+ events per time unit
'firingrate_smoothed', [], ...             	- firing rate map, smoothed:    convolution with gauss kernel
'firingrate_refined', [], ...              	- firing rate map, refined:     firingrate_smoothed thresholded
'firingrate_normalized', [], ...           	- firing rate map, normalized:  firingrate_refined normalized to [0,1]
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAXIMA OF MAPS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'max_bin', struct(...
    'spike', [], ...                           	- maximum value of spike map
    'spike_refined', [], ...                   	- maximum value of spike map, smoothed and refined
    'firingrate', [], ...                      	- maximum value of firing rate map
    'firingrate_refined', []), ...             	- maximum value of firing rate map, smoothed and refined
'max_bin_trace', struct(...
    'trace', [], ...                           	- maximum value of trace map
    'trace_refined', []), ...                  	- maximum value of trace map, smoothed and refined
...
...%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TRACE MAPS  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'trace', [], ...                           	- trace map, original:                  raw Ca2+ activity map
'trace_smoothed', [], ...                  	- trace map, smoothed:                  convolution with gauss kernel
'trace_refined', [], ...                   	- trace map, refined:                   trace_smoothed thresholded
'trace_normalized', [], ...                	- trace map, normalized:                trace_refined normalized to [0,1]
'trace_split_smoothed', [] ...              - array of split trace maps
... % 'trace_firingrate', [], ...                	- trace firing rate map, original:      raw Ca2+ activity per time unit
... % 'trace_firingrate_smoothed', [], ...       	- trace firing rate map, smoothed:      convolution with gauss kernel
... % 'trace_firingrate_refined', [], ...        	- trace firing rate map, refined:       trace_firingrate_smoothed restricted
... % 'trace_firingrate_normalized', [] ...      	- trace firing rate map, normalized:    trace_firingrate_refined normalized to [0,1]
);

mouse.activity_map_summary.firingrate = zeros(mouse.size_map);                      % HeatMap of all activity map
mouse.activity_map_summary.firingrate_normalized = zeros(mouse.size_map);           % HeatMap of all normalized activity map
mouse.activity_map_summary.trace_firingrate = zeros(mouse.size_map);                % HeatMap of all trace activity map
mouse.activity_map_summary.trace_firingrate_normalized = zeros(mouse.size_map);     % HeatMap of all normalized trace activity map

% MI table
cells_MI = zeros(8,mouse.cells_for_analysis_count);
cells_MI(1,1:mouse.cells_for_analysis_count)=linspace(1,mouse.cells_for_analysis_count,mouse.cells_for_analysis_count);

h = waitbar(1/mouse.cells_for_analysis_count, sprintf('MI calculation, cell %d of %d', 0,  mouse.cells_for_analysis_count));
for ncell = mouse.cells_active
    h = waitbar(ncell/mouse.cells_for_analysis_count,h, sprintf('MI calculation, cell %d of %d', ncell,  mouse.cells_for_analysis_count));
    
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
    
    % всегда строим карту активности по колву спайков в минуту, нормировано на объем
    [cellmaps(ncell).spike, cellmaps(ncell).spike_smoothed, cellmaps(ncell).spike_refined, cellmaps(ncell).spike_normalized, ...
        cellmaps(ncell).firingrate, cellmaps(ncell).firingrate_smoothed, cellmaps(ncell).firingrate_refined, cellmaps(ncell).firingrate_normalized, ...
        cellmaps(ncell).max_bin] = calculate_firing_rate_maps( ...
        cellmaps(ncell).spikes, mouse.x_ind, mouse.y_ind, ...
        mouse.size_map, mouse.mask_t, mouse.occupancy_map.time_smoothed_min, ...
        mouse.params_main.activity_map_opt.visual, mouse.params_main.kernel_opt);
    
    % maximum value update for all cells   
    if mouse.max_bin.spike < cellmaps(ncell).max_bin.spike
        mouse.max_bin.spike =  cellmaps(ncell).max_bin.spike;
    end
    if mouse.max_bin.spike_refined < cellmaps(ncell).max_bin.spike_refined
        mouse.max_bin.spike_refined = cellmaps(ncell).max_bin.spike_refined;
    end
    if mouse.max_bin.firingrate < cellmaps(ncell).max_bin.firingrate
        mouse.max_bin.firingrate =  cellmaps(ncell).max_bin.firingrate;
    end
    if mouse.max_bin.firingrate_refined < cellmaps(ncell).max_bin.firingrate_refined
        mouse.max_bin.firingrate_refined =  cellmaps(ncell).max_bin.firingrate_refined;
    end
    
    mouse.activity_map_summary.firingrate = mouse.activity_map_summary.firingrate + cellmaps(ncell).firingrate_refined;
    mouse.activity_map_summary.firingrate_normalized = mouse.activity_map_summary.firingrate_normalized + cellmaps(ncell).firingrate_normalized;
    
    % строим карту активности по всему сырому сигналу
    [cellmaps(ncell).trace, cellmaps(ncell).trace_smoothed, cellmaps(ncell).trace_refined, cellmaps(ncell).trace_normalized, cellmaps(ncell).max_bin_trace] = ...
    calculate_trace_maps(cells(ncell).trace, mouse.x_ind, mouse.y_ind, ...
    mouse.size_map, mouse.mask_t, mouse.occupancy_map.frame, ...
    mouse.params_main.activity_map_opt.mi, mouse.params_main.kernel_opt);

    % строим разбивку сессии на несколько карт активности    
    if mouse.params_main.activity_map_split
        for split = 1:mouse.params_main.activity_map_split
            [~, cellmaps(ncell).trace_split_smoothed{split}, ~, ~, ~] = calculate_trace_maps( ...
                cells(ncell).trace(mouse.split_frames{split}), ...
                mouse.x_ind(mouse.split_frames{split}), ...
                mouse.y_ind(mouse.split_frames{split}), ...
                mouse.size_map, mouse.mask_t, ...
                mouse.occupancy_map.frame_split{split}, ...
                mouse.params_main.activity_map_opt.mi, mouse.params_main.kernel_opt);
        end
    end
        
    % ===== GLOBAL MAXIMA UPDATE TRACE MAP=====
    if mouse.max_bin.trace < cellmaps(ncell).max_bin_trace.trace
        mouse.max_bin.trace = cellmaps(ncell).max_bin_trace.trace;
    end
    if mouse.max_bin.trace_refined < cellmaps(ncell).max_bin_trace.trace_refined
        mouse.max_bin.trace_refined = cellmaps(ncell).max_bin_trace.trace_refined;
    end

    % ===== SUMMARY MAPS UPDATE =====
    mouse.activity_map_summary.trace_firingrate = mouse.activity_map_summary.trace_firingrate + cellmaps(ncell).trace_refined;
    mouse.activity_map_summary.trace_firingrate_normalized = mouse.activity_map_summary.trace_firingrate_normalized + cellmaps(ncell).trace_normalized;
    
    %MI calculation
    if mouse.params_main.MI_calculate
        cells_MI(2:8,ncell) = MI_calculation(mouse, cellmaps(ncell).spikes);
    else
        cells_MI(2:8,ncell) = [0 0 0 0 0 0 0];
    end

%     [cells(ncell).criterion_MI, cells(ncell).MI_bit_event, cells(ncell).MI_zscore ,...
%     cells(ncell).MI_bit_time, ~, cells(ncell).MI_mean_shuffles, cells(ncell).MI_std_shuffles     
%     ] = MI_calculation(mouse, cellmaps(ncell).spikes);
    
    cells(ncell).criterion_MI = cells_MI(2,ncell);
    cells(ncell).MI_bit_event = cells_MI(3,ncell);
    cells(ncell).MI_zscore = cells_MI(4,ncell);
    cells(ncell).MI_bit_time = cells_MI(5,ncell);
    cells(ncell).MI_mean_shuffles = cells_MI(7,ncell);
    cells(ncell).MI_std_shuffles = cells_MI(8,ncell);

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

if mouse.params_main.vel_opt
    mouse.cells_informative_firingrate = [cells(mouse.cells_informative).spikes_in_mov_frequency];
else
    mouse.cells_informative_firingrate = [cells(mouse.cells_informative).spikes_all_frequency];    
end
mouse.cells_informative_firingrate_mean = round(mean(mouse.cells_informative_firingrate),2);

mouse.cells_informative_MI_bit_event = [cells(mouse.cells_informative).MI_bit_event];
mouse.cells_informative_MI_bit_event_mean = round(mean(mouse.cells_informative_MI_bit_event),2);
mouse.cells_informative_MI_bit_time = [cells(mouse.cells_informative).MI_bit_time];
mouse.cells_informative_MI_bit_time_mean = round(mean(mouse.cells_informative_MI_bit_time),2);
mouse.cells_informative_MI_zscored = [cells(mouse.cells_informative).MI_zscore];
mouse.cells_informative_MI_zscored_mean = round(mean(mouse.cells_informative_MI_zscored),2);

mouse.cells_active_MI_bit_event = [cells(mouse.cells_active).MI_bit_event];
mouse.cells_active_MI_bit_event_mean = round(mean(mouse.cells_active_MI_bit_event),2);
mouse.cells_active_MI_bit_time = [cells(mouse.cells_active).MI_bit_time];
mouse.cells_active_MI_bit_time_mean = round(mean(mouse.cells_active_MI_bit_time),2);
mouse.cells_active_MI_zscored = [cells(mouse.cells_active).MI_zscore];
mouse.cells_active_MI_zscored_mean = round(mean(mouse.cells_active_MI_zscored),2);

if mouse.plot_opt.Plot_FiringRate_Smooth
    PlotPC(mouse, 'firing rate', cells, cellmaps);
end

if mouse.params_main.plot_trace
    PlotPC(mouse, 'trace map', cells, cellmaps);
end

PlotPC(mouse, 'firing rate summary', cells, cellmaps);

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));

%% calculation and plotting separate fields from activity maps

Fields(1:11,1)=0;
MapFields = zeros([mouse.size_map 1]); %activity map of all fields

wfields = 0;
for map = mouse.cells_informative
    
    if mouse.params_main.vel_opt
        spike_t_good = cells(map).spikes_in_mov_frames;
    else
        spike_t_good = cells(map).spikes_all_frames;
    end
    
    % watershed transform
    N_water = -cellmaps(map).firingrate_smoothed;
    L = watershed(N_water);
    
    [n_wfield, mask_wfield, spike_in_field] = WaterShedField(L, spike_t_good, mouse.x*mouse.behav_opt.pxl2sm, mouse.y*mouse.behav_opt.pxl2sm, mouse.params_main.bin_size);
    
    wfields = wfields+n_wfield;
    for mask_field=1:n_wfield
        Fields(1,wfields-n_wfield+mask_field) = map;
        Fields(2,wfields-n_wfield+mask_field) = mask_field;
        Fields(10,wfields-n_wfield+mask_field) = length([spike_in_field{mask_field,:}]);
        
        switch mouse.params_main.PC_criterion
            case 'MI_vanila'
                Fields(3:9,wfields-n_wfield+mask_field) = cells_MI(2:8,map);
                Fields(11,wfields-n_wfield+mask_field) = (Fields(10,wfields-n_wfield+mask_field)>=mouse.params_main.min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
            case 'MI_vanila_fields'
%                 Fields(3:6,wfields-n_wfield+mask_field) = RandomShiftMod(params_main.smooth_freq_mode,[spike_in_field{mask_field,:}],mouse.x_ind,mouse.y_ind,N_time_sm,params_main.N_shift,params_main.shift,params_main.S_sigma,mouse.params_main.TimeRate,session.framerate,params_main.kernel_opt);
%                 Fields(7,wfields-n_wfield+mask_field) = (Fields(4,wfields-n_wfield+mask_field)-Fields(5,wfields-n_wfield+mask_field))/Fields(6,wfields-n_wfield+mask_field);
%                 Fields(9,wfields-n_wfield+mask_field) = (Fields(8,wfields-n_wfield+mask_field)>params_main.min_spike_field)*Fields(3,wfields-n_wfield+mask_field);
        end
        
        % calculation separate field
        MapFields(:,:,wfields-n_wfield+mask_field) = cellmaps(map).firingrate_smoothed.*mask_wfield(:,:,mask_field)/max(max(mask_wfield(:,:,mask_field)));
        
        
        if mouse.plot_opt.Plot_FiringRate_Fields_Corrected
            if Fields(11,wfields-n_wfield+mask_field)
                
                draw_heatmap( ...
                    mouse.behav_opt.rgb_image, ...
                    mouse.params_main.heatmap_opt.spike, ...
                    MapFields(:,:,wfields-n_wfield+mask_field), ...
                    0, ...
                    mouse.x_track, ...
                    mouse.y_track, ...
                    mouse.shift, ...
                    mouse.behav_opt.x_kcorr, ...
                    mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
                    [spike_in_field{mask_field,:}] ...
                    );
                
                title(sprintf('Firing rate of informative field %d of cell %d (smoothed and thresholded)(#/min) \n MI = %.2f, Zscore = %.1f',mask_field,map,Fields(4:5,wfields-n_wfield+mask_field)), 'FontSize', mouse.params_main.FontSizeTitle);
                saveas(gcf, sprintf('%s\\Heatmap_FiringRate_Fields_Corrected_Inform\\%s_FiringRate_Fields_Corrected_Inform_Cell_%d_Field_%d.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut,map,mask_field));
                delete(gcf);
            end
        end
        
    end
end

N_inf=1;
MapFieldsIC = [];
FieldsIC = [];
for nfield=1:length(Fields(11,:))
    if Fields(11,nfield)
        MapFieldsIC(:,:,N_inf) = MapFields(:,:,nfield); %only informative fields
        FieldsIC(:,N_inf) = Fields(:,nfield);
        N_inf=N_inf+1;
    end
end

save(sprintf('%s\\WorkSpace_%s.mat',mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
end
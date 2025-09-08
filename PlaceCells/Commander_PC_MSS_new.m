%% paths and names

ExpID = 'MSS';

% all sessions
FileNames = {
    'D01_1D_1T' 'D01_2D_1T' 'F01_1D_1T' 'F01_2D_1T' 'F01_3D_1T' 'F01_4D_1T' 'F01_5D_1T' 'F01_6D_1T' 'F04_1D_1T' 'F04_2D_1T'  ...
    'F04_3D_1T' 'F04_4D_1T' 'F04_5D_1T' 'F04_6D_1T' 'F05_1D_1T' 'F05_1D_2T' 'F05_1D_3T' 'F05_1D_4T' 'F05_1D_5T' 'F05_2D_1T'  ...
    'F06_1D_2T' 'F06_1D_3T' 'F06_1D_4T' 'F06_1D_5T' 'F06_2D_1T' 'F08_1D_1T' 'F08_2D_1T' 'F09_1D_1T' 'F09_2D_1T' 'F09_3D_1T'  ...
    'F09_4D_1T' 'F09_5D_1T' 'F09_6D_1T' 'F10_1D_1T' 'F10_2D_1T' 'F11_1D_1T' 'F11_2D_1T' 'F12_1D_1T' 'F12_2D_1T' 'F12_3D_1T'  ...
    'F12_4D_1T' 'F12_5D_1T' 'F12_6D_1T' 'F14_1D_1T' 'F14_2D_1T' 'F15_1D_1T' 'F15_1D_2T' 'F15_1D_3T' 'F15_1D_4T' 'F15_1D_5T'  ...
    'F15_2D_1T' 'F20_1D_1T' 'F20_1D_2T' 'F20_1D_3T' 'F20_1D_4T' 'F20_1D_5T' 'F20_2D_1T' 'F26_1D_1T' 'F26_2D_1T' 'F28_1D_1T'  ...
    'F28_2D_1T' 'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T' 'F29_6D_1T' 'F30_1D_1T' 'F30_1D_2T' 'F30_1D_3T'  ...
    'F30_1D_4T' 'F30_1D_5T' 'F30_2D_1T' 'F31_1D_1T' 'F31_2D_1T' 'F34_1D_1T' 'F34_1D_2T' 'F34_1D_3T' 'F34_1D_4T' 'F34_1D_5T'  ...
    'F34_2D_1T' 'F35_1D_1T' 'F35_2D_1T' 'F36_1D_1T' 'F36_2D_1T' 'F37_1D_1T' 'F37_2D_1T' 'F38_1D_1T' 'F38_2D_1T' 'F38_3D_1T'  ...
    'F38_4D_1T' 'F38_5D_1T' 'F38_6D_1T' 'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T' 'F40_6D_1T' 'F43_1D_1T'  ...
    'F43_1D_2T' 'F43_1D_3T' 'F43_1D_4T' 'F43_1D_5T' 'F43_2D_1T' 'F48_1D_1T' 'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T'  ...
    'F48_6D_1T' 'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T' 'F52_6D_1T' 'F53_1D_1T' 'F53_1D_2T' 'F53_1D_3T'  ...
    'F53_1D_4T' 'F53_1D_5T' 'F53_2D_1T' 'F54_1D_1T' 'F54_1D_2T' 'F54_1D_3T' 'F54_1D_4T' 'F54_1D_5T' 'F54_2D_1T' 'H26_1D_1T'  ...
    'H26_1D_2T' 'H26_1D_3T' 'H26_1D_4T' 'H26_1D_5T' 'H26_2D_1T' 'H27_1D_1T' 'H27_2D_1T' 'H27_3D_1T' 'H27_4D_1T' 'H27_5D_1T'  ...
    'H27_6D_1T' 'H31_1D_1T' 'H31_2D_1T' 'H32_1D_1T' 'H32_2D_1T' 'H32_3D_1T' 'H32_4D_1T' 'H32_5D_1T' 'H32_6D_1T' 'H33_1D_1T'  ...
    'H33_1D_2T' 'H33_1D_3T' 'H33_1D_4T' 'H33_1D_5T' 'H33_2D_1T' ...
    };

% massed group, TRAIN
massed_group = {
'F05_1D_1T' 'F05_1D_2T' 'F05_1D_3T' 'F05_1D_4T' 'F05_1D_5T' ...
'F06_1D_1T' 'F06_1D_2T' 'F06_1D_3T' 'F06_1D_4T' 'F06_1D_5T' ...
'F15_1D_1T' 'F15_1D_2T' 'F15_1D_3T' 'F15_1D_4T' 'F15_1D_5T' ...
'F20_1D_1T' 'F20_1D_2T' 'F20_1D_3T' 'F20_1D_4T' 'F20_1D_5T' ...
'F30_1D_1T' 'F30_1D_2T' 'F30_1D_3T' 'F30_1D_4T' 'F30_1D_5T' ...
'F34_1D_1T' 'F34_1D_2T' 'F34_1D_3T' 'F34_1D_4T' 'F34_1D_5T' ...
'F43_1D_1T' 'F43_1D_2T' 'F43_1D_3T' 'F43_1D_4T' 'F43_1D_5T' ...
'F53_1D_1T' 'F53_1D_2T' 'F53_1D_3T' 'F53_1D_4T' 'F53_1D_5T' ...
'F54_1D_1T' 'F54_1D_2T' 'F54_1D_3T' 'F54_1D_4T' 'F54_1D_5T' ...
'H26_1D_1T' 'H26_1D_2T' 'H26_1D_3T' 'H26_1D_4T' 'H26_1D_5T' ...
'H33_1D_1T' 'H33_1D_2T' 'H33_1D_3T' 'H33_1D_4T' 'H33_1D_5T' };

% spaced group, TRAIN
spaced_group = {
    'F01_1D_1T' 'F01_2D_1T' 'F01_3D_1T' 'F01_4D_1T' 'F01_5D_1T'...
    'F04_1D_1T' 'F04_2D_1T' 'F04_3D_1T' 'F04_4D_1T' 'F04_5D_1T'...
    'F09_1D_1T' 'F09_2D_1T' 'F09_3D_1T' 'F09_4D_1T' 'F09_5D_1T'...
    'F12_1D_1T' 'F12_2D_1T' 'F12_3D_1T' 'F12_4D_1T' 'F12_5D_1T'...
    'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T'...
    'F38_1D_1T' 'F38_2D_1T' 'F38_3D_1T' 'F38_4D_1T' 'F38_5D_1T'...
    'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T'...
    'F48_1D_1T' 'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T'...
    'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T'...
    'H27_1D_1T' 'H27_2D_1T' 'H27_3D_1T' 'H27_4D_1T' 'H27_5D_1T'...
    'H32_1D_1T' 'H32_2D_1T' 'H32_3D_1T' 'H32_4D_1T' 'H32_5D_1T' 
};

% single group, TRAIN
single_group = {
    'F08_1D_1T' 'F10_1D_1T' 'F11_1D_1T' 'F14_1D_1T' 'F26_1D_1T' 'F28_1D_1T' ...
    'F31_1D_1T' 'F35_1D_1T' 'F36_1D_1T' 'F37_1D_1T' 'H31_1D_1T' 'D01_1D_1T'};

PathTraces = 'w:\Projects\MSS\ActivityData\Traces\';
PathSpikes = 'w:\Projects\MSS\ActivityData\Spikes\';
PathWorkSpaces = 'w:\Projects\MSS\ActivityData\Behav_mat\';
PathPresets = 'w:\Projects\MSS\ActivityData\Presets\';

PathOut = 'w:\Projects\MSS\ActivityData\PlaceCells\';

%% all vital parameters

params_main = struct(...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SYNCHRONIZATION OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'CorrectionTrackMode', 'Bonsai',...             % different modes for correction syncronization of behavior and calcium data {'NVista', 'FC', 'Bonsai', 'none'}
        'coordinates_correction', 0,...                 % 1 if you need in interpolation and smoothing of videotracking data
        'test_mode', 0,...                             % 0 for all cells analysis else number of n first cells
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
        'activity_map_split', 0, ...                    % if you want to create several FR maps
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
        'plot_trace', 1, ...                           	% plot trace maps
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

%% main

for file = 61:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    % common params (Test days)
    params_main.MI_calculate = 1;
    params_main.activity_map_split = 0;
    params_main.plot_mode = 0;
    params_main.plot_trace = 0;
    
    % train of spaced and massed groups
    if any(strcmp(FileNames{file}, spaced_group)) || any(strcmp(FileNames{file}, massed_group))
        params_main.MI_calculate = 0;
        params_main.activity_map_split = 0;
        params_main.plot_mode = 0;
        params_main.plot_trace = 0;
    end
    
    % train of single group
    if any(strcmp(FileNames{file}, single_group))
        params_main.MI_calculate = 1;
        params_main.activity_map_split = 5;
        params_main.plot_mode = 0;
        params_main.plot_trace = 0;
    end
    
    FileNameWS = sprintf('%s_%s_WorkSpace.mat',ExpID, FileNames{file});
    FileNameTR = sprintf('%s_%s_traces.csv',ExpID, FileNames{file});
    FileNameSP = sprintf('%s_%s_spikes.csv',ExpID, FileNames{file});
    FileNamePR = sprintf('%s_%s_Preset.mat',ExpID, FileNames{file});
    
    params_paths = struct('pathWS', PathWorkSpaces, 'filenameWS', FileNameWS, ...
                'pathTR', PathTraces, 'filenameTR', FileNameTR, ...
                'pathNV', PathSpikes, 'filenameNV', FileNameSP, ...
                'pathPR', PathPresets, 'filenamePR', FileNamePR, ...
                'pathOut', PathOut);    
            
    if isfile(fullfile(PathTraces,FileNameTR))
        PlaceMapsAnalyzer(params_paths, params_main);
    end
    
    clear 'params_paths'
end
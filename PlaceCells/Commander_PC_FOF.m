%% paths and names

ExpID = 'FOF';

% FileNames = {
%     'F26_1D' 'F28_1D' 'F01_1D' 'F06_1D' 'F29_1D' 'F30_1D',...
%     'F20_1D' 'F08_1D' 'F34_1D' 'F36_1D' 'F38_1D' 'F40_1D',...
%     'F04_1D' 'F07_1D' 'F37_1D' 'F12_1D' 'F14_1D' 'F09_1D',...
%     'F48_1D' 'F05_1D' 'F43_1D' 'F10_1D' 'F35_1D' 'F31_1D',...
%     'F15_1D' 'F41_1D' 'F52_1D' 'F11_1D' 'F53_1D' 'F54_1D',...
%     'F26_2D' 'F28_2D' 'F01_2D' 'F06_2D' 'F29_2D' 'F30_2D',...
%     'F20_2D' 'F08_2D' 'F34_2D' 'F36_2D' 'F38_2D' 'F40_2D',...
%     'F04_2D' 'F07_2D' 'F37_2D' 'F12_2D' 'F14_2D' 'F09_2D',...
%     'F48_2D' 'F05_2D' 'F43_2D' 'F10_2D' 'F35_2D' 'F31_2D',...
%     'F15_2D' 'F41_2D' 'F52_2D' 'F11_2D' 'F53_2D' 'F54_2D',...
%     'F26_3D' 'F28_3D' 'F01_3D' 'F06_3D' 'F29_3D' 'F30_3D',...
%     'F20_3D' 'F08_3D' 'F34_3D' 'F36_3D' 'F38_3D' 'F40_3D',...
%     'F04_3D' 'F07_3D' 'F37_3D' 'F12_3D' 'F14_3D' 'F09_3D',...
%     'F48_3D' 'F05_3D' 'F43_3D' 'F10_3D' 'F35_3D' 'F31_3D',...
%     'F15_3D' 'F41_3D' 'F52_3D' 'F11_3D' 'F53_3D' 'F54_3D'
%     };

% for intense
FileNames = {
    'F28_1D' 'F01_1D' 'F06_1D' 'F29_1D' 'F30_1D',...
    'F20_1D' 'F08_1D' 'F34_1D' 'F36_1D' 'F38_1D' 'F40_1D',...
    'F07_1D' 'F37_1D' 'F12_1D' 'F14_1D' 'F09_1D',...
    'F48_1D' 'F05_1D' 'F10_1D' 'F35_1D' 'F31_1D',...
    'F15_1D' 'F41_1D' 'F52_1D' 'F11_1D' 'F53_1D' 'F54_1D',...
    'F28_2D' 'F01_2D' 'F06_2D' 'F29_2D' 'F30_2D',...
    'F20_2D' 'F08_2D' 'F34_2D' 'F36_2D' 'F38_2D' 'F40_2D',...
    'F07_2D' 'F37_2D' 'F12_2D' 'F14_2D' 'F09_2D',...
    'F48_2D' 'F05_2D' 'F10_2D' 'F35_2D' 'F31_2D',...
    'F15_2D' 'F41_2D' 'F52_2D' 'F11_2D' 'F53_2D' 'F54_2D',...
    'F28_3D' 'F01_3D' 'F06_3D' 'F29_3D' 'F30_3D',...
    'F20_3D' 'F08_3D' 'F34_3D' 'F36_3D' 'F38_3D' 'F40_3D',...
    'F07_3D' 'F37_3D' 'F12_3D' 'F14_3D' 'F09_3D',...
    'F48_3D' 'F05_3D' 'F10_3D' 'F35_3D' 'F31_3D',...
    'F15_3D' 'F41_3D' 'F52_3D' 'F11_3D' 'F53_3D' 'F54_3D'
    };

exluded = {'F04_1D' 'F04_2D' 'F04_3D' 'F26_1D' 'F26_2D' 'F26_3D' 'F43_1D' 'F43_2D' 'F43_3D'};

PathTraces = 'w:\Projects\FOF\ActivityData\Traces\';
PathSpikes = 'w:\Projects\FOF\ActivityData\Spikes\';
PathWorkSpaces = 'w:\Projects\FOF\ActivityData\Behav_mat\';
PathPresets = 'w:\Projects\FOF\ActivityData\Presets\';


PathOut = 'w:\Projects\FOF\ActivityData\PlaceCells\';

%% all vital parameters

params_main = struct(...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SYNCHRONIZATION OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'CorrectionTrackMode', 'Bonsai',...             % different modes for correction syncronization of behavior and calcium data {'NVista', 'FC', 'Bonsai', 'none'}
        'coordinates_correction', 0,...                 % 1 if you need in interpolation and smoothing of videotracking data
        'test_mode', 0,...                              % 0 for all cells analysis else number of n first cells
        'start_frame', 1,...                            % frame of the first frame for analysis
        'app_frame', 1,...                              % frame of the first frame "mouse in cage" (at last paradigm od analysis - is the same frame like a srart
        'end_frame', 0,...                              % frame of the last frame for analysis
        'TimeMode', 's',...                             % 's' for 3-20 min duration of session, 'min' - for 30-60 min duration of session
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DIFFERENT ANALYSIS MODES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'PC_criterion', 'MI_vanila',...                 % method for criterion of Place Cells: 'Peak' - schuffled peak of activity, 'MI_vanila' - Mutual Information for cells,  'MI_vanila_fields' - Mutual Information for fields
        'bin_size_cm', 8,...                            % size of bins in cm
        'heatmap_border', 1,...                         % additional bins number on the edges of the HeatMaps
        'S_sigma', 2.29,...                             % criteria for informative place cell(1.65 for p = 0.05, 2.29 for p = 0.01)
        'N_shift', 1000,...                             % number of shift for random distribution
        'shift', 0.9,...                                % percent of all time occupancy for random shift
        'kernel_opt', struct(...
        'small', struct('size', 3, 'sigma', 1.5),...
        'big', struct('size', 5, 'sigma', 1.5)),...     % gaussian kernel for maps smoothing
        'smooth_freq_mode', 1,...                       % 1 for smoothing activity map during MI calculation
        ...
        'vel_opt', 0,...                                % all maps and MI calculated with respond to velocity threshold
        'vel_border', 5,...                             % velocity threshold in cm/s
        ...
        'min_spike', 1,...                              % minimum number of spikes for active cell
        'min_spike_MI', 3,...                           % minimum number of spikes for MI calculation
        'min_spike_field', 3,...                        % minimum number of spikes for place field
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TEMPORAL PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'SmoothWindowS', 0.5,...                        % smoothing window in seconds for behavior analysis (in case non-smoothed data)
        'time_smooth', 1,...                            % flag for smoothing of time map(occupancy map)
        'spike_smooth', 1,...                           % flag for smoothing of spikes map
        'thres_spike', 0.3,...                          % threshold for spike map after smoothing
        'thres_firing', 0.3,...                         % threshold for activity map after smoothing
        'length_line_sec', 0.5,...                      % min time for acts (in area of fields or velocity binary timeseries)
        'snr_params', struct('percentile', 50),...      % percent of signal to identify noise lvl in neurob trace
        ...
        ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SUPPORTING PLOTS AND VERBOSE PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        'verbose', 1,...                                % additional messages
        'plot_mode', 1,...                              % main plot parameters, 0 - no one plots, 1 - basic plots, 2 - all plots
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

%% main

for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    if any(strcmp(FileNames{file}, exluded))
        fprintf('Not found: %s_%s\n', ExpID, FileNames{file});
        continue;
    end
    
%     if file > 0 && file <= 17
%         FileNamePR = 'FOF_F26_1D_Preset.mat';
%     elseif file > 17 && file <= 30
%         FileNamePR = 'FOF_F09_1D_Preset.mat';
%     elseif file > 30 && file <= 47
%         FileNamePR = 'FOF_F26_2D_Preset.mat';
%     elseif file > 47 && file <= 55
%         FileNamePR = 'FOF_F09_2D_Preset.mat';
%     elseif file > 55 && file <= 60
%         FileNamePR = 'FOF_F41_2D_Preset.mat';
%     elseif file > 60 && file <= 77
%         FileNamePR = 'FOF_F26_3D_Preset.mat';
%     else
%         FileNamePR = 'FOF_F09_3D_Preset.mat';
%     end
    
%     FileNameWS = sprintf('%s_%s_WorkSpace.mat',ExpID, FileNames{file});
%     FileNameTR = sprintf('%s_%s_traces.csv',ExpID, FileNames{file});
%     FileNameSP = sprintf('%s_%s_spikes.csv',ExpID, FileNames{file});
%     FileNamePR = sprintf('%s_%s_Preset.mat',ExpID, FileNames{file});
    
%     params_paths = struct('pathWS', PathWorkSpaces, 'filenameWS', FileNameWS, ...
%                 'pathTR', PathTraces, 'filenameTR', FileNameTR, ...
%                 'pathNV', PathSpikes, 'filenameNV', FileNameSP, ...
%                 'pathPR', PathPresets, 'filenamePR', FileNamePR, ...
%                 'pathOut', PathOut);    
%             
%     if isfile(fullfile(PathTraces,FileNameTR))
%         [FieldsIC] = PlaceFieldAnalyzerFOF(params_paths, params_main);
%     end
    load(pathin{day}, 'mouse', 'Cell_IC', 'cellmaps');
        tables = struct();
    for i = 1:64
        table_name = sprintf('table%d', i);
        tables.(table_name) = rand(10); % Пример данных
    end
    save('tables_data.mat', 'tables');

from scipy.io import loadmat

data = loadmat('tables_data.mat')
tables = data['tables']
# Обращение к конкретной таблице
table1 = tables['table1']

    clear 'params_paths'
end
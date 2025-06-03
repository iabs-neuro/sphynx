%% main
% Big_Cell_IC = [];
for file = 1:length(filenames)
    filename = sprintf('NOF_%s_WorkSpace.mat',filenames{file});
    %     filename = sprintf('NOF_%s_Features.csv',filenames{file});
    filenameNV = sprintf('NOF_%s_spikes.csv',filenames{file});
    filenamePR = sprintf('NOF_%s_Preset.mat',filenames{file});
    
    %     FilenameMat = sprintf('w:\\Projects\\NOF\\PlaceCellsData\\11_MAT_test\\WorkSpace_NOF_%s.mat',filenames{file});
    %     load(FilenameMat, 'Cell_IC');
    %     Big_Cell_IC = [Big_Cell_IC Cell_IC(6,:)];
    % end
    
    plot_opt = 1;
    
    if file > 9 && file < 17
        filenamePR = 'NOF_H26_1D_Preset.mat';
    elseif (file > 25 && file < 33) || (file > 41 && file <  49) || (file > 57)
        filenamePR = 'NOF_H26_2D_Preset.mat';
    else
        filenamePR = sprintf('NOF_%s_Preset.mat', filenames{file});
    end
    
    [FieldsIC] = PlaceFieldAnalyzerNOF(path,filename,pathNV,filenameNV,pathPR,filenamePR, plot_opt);
end


%% paths and names

ExpID = 'NOF';

FileNames = {
    'H01_1D','H02_1D','H03_1D','H06_1D','H07_1D','H08_1D','H09_1D','H14_1D','H23_1D',...
    'H26_1D','H27_1D','H31_1D','H32_1D','H33_1D','H36_1D','H39_1D',...
    'H01_2D','H02_2D','H03_2D','H06_2D','H07_2D','H08_2D','H09_2D','H14_2D','H23_2D'...
    'H26_2D','H27_2D','H31_2D','H32_2D','H33_2D','H36_2D','H39_2D',...
    'H01_3D','H02_3D','H03_3D','H06_3D','H07_3D','H08_3D','H09_3D','H14_3D','H23_3D',...
    'H26_3D','H27_3D','H31_3D','H32_3D','H33_3D','H36_3D','H39_3D',...
    'H01_4D','H02_4D','H03_4D','H06_4D','H07_4D','H08_4D','H09_4D','H14_4D','H23_4D',...
    'H26_4D','H27_4D','H31_4D','H32_4D','H33_4D','H36_4D','H39_4D',...
    };

PathTraces = 'w:\Projects\NOF\ActivityData\Traces\';
PathSpikes = 'w:\Projects\NOF\ActivityData\Spikes\';
PathWorkSpaces = 'w:\Projects\NOF\ActivityData\MAT_behav\';
PathPresets = 'w:\Projects\NOF\ActivityData\Presets\';

PathOut = 'w:\Projects\MSS\ActivityData\PlaceCells\';

%% all vital parameters

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
    'PC_criterion', 'MI_vanila',...                 % method for criterion of Place Cells: 'Peak' - schuffled peak of activity, 'MI_vanila' - Mutual Information for cells,  'MI_vanila_fields' - Mutual Information for fields
    'bin_size_cm', 4,...                            % size of bins in cm
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
    'min_spike_MI', 3,...                           % minimum number of spikes for MI calculation (not used right now)
    'min_spike_field', 3,...                        % minimum number of spikes for place field
    ...
    ... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TEMPORAL PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    'SmoothWindowS', 0.5,...                        % smoothing window in seconds for behavior analysis (in case non-smoothed data)
    'time_smooth', 1,...                            % flag for smoothing of time map (occupancy map)
    'spike_smooth', 1,...                           % flag for smoothing of spikes map
    'thres_spike', 0.3,...                          % threshold for spike map after smoothing
    'thres_firing', 0.5,...                         % threshold for activity map after smoothing
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

%% main

for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    FileNameWS = sprintf('%s_%s_WorkSpace.mat',ExpID, FileNames{file});
    FileNameTR = sprintf('%s_%s_traces.csv',ExpID, FileNames{file});
    FileNameSP = sprintf('%s_%s_spikes.csv',ExpID, FileNames{file});    
    
    % preset loading

    if file > 9 && file < 17
        FileNamePR = 'NOF_H26_1D_Preset.mat';
    elseif (file > 25 && file < 33) || (file > 41 && file <  49) || (file > 57)
        FileNamePR = 'NOF_H26_2D_Preset.mat';
    else
        FileNamePR = sprintf('%s_%s_Preset.mat',ExpID, FileNames{file});
    end
    
    params_paths = struct('pathWS', PathWorkSpaces, 'filenameWS', FileNameWS, ...
        'pathTR', PathTraces, 'filenameTR', FileNameTR, ...
        'pathNV', PathSpikes, 'filenameNV', FileNameSP, ...
        'pathPR', PathPresets, 'filenamePR', FileNamePR, ...
        'pathOut', PathOut);
    
    if isfile(fullfile(PathTraces,FileNameTR))
        [FieldsIC] = PlaceFieldAnalyzerMSS(params_paths, params_main);
    end
    
    clear 'params_paths'
end
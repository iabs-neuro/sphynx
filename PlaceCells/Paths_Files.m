%% manual defining parameters section
if ~exist('params_paths', 'var') || (exist('params_paths', 'var') && ~check_paths_in(params_paths))
    
    % define path for outputs
    params_paths.pathOut = uigetdir('w:\Projects\MSS\ActivityData\PlaceCells\', 'Please specify the path to save the data');
    
    % loading videotracking
    [params_paths.filenameWS, params_paths.pathWS]  = uigetfile('*.mat','Please specify the mat-file from behavior analysis','w:\Projects\MSS\ActivityData\Behav_mat\');
    
    % loading spike file
    [params_paths.filenameNV, params_paths.pathNV]  = uigetfile('*.csv','Please specify the file with spikes','w:\Projects\MSS\ActivityData\Spikes\');
    
    % loading trace file
    [params_paths.filenameTR, params_paths.pathTR]  = uigetfile('*.csv','Please specify the file with traces','w:\Projects\MSS\ActivityData\Traces\');
    
    % loading preset file
    [params_paths.filenamePR, params_paths.pathPR]  = uigetfile('*.mat','Please specify the preset file','w:\Projects\MSS\ActivityData\Presets\');
    
    % Проверяем, корректны ли пути
    if check_paths_in(params_paths)
        disp('✅ Все файлы выбраны корректно.');
    else
        disp('⚠️ Некоторые файлы выбраны некорректно! Проверьте пути и расширения файлов.');
    end
end


%% paths and filenames

ExpID = 'NOL';

PathVideo = 'w:\Projects\NOL\BehaviorData\1_Raw\';
PathDLC = 'w:\Projects\NOL\BehaviorData\2_DLC\';
PathOut = 'w:\Projects\NOL\BehaviorData\4_Behavior\';
PathPreset = 'w:\Projects\NOL\BehaviorData\3_Preset\';

% for ALL DAYS
FileNames = {
    '1L-test' '1L-training' '1R-test' '1R-training' '2L-test' '2L-training' '2R-test' ...
    '2R-training' '3L-test' '3L-training' '3R-test' '3R-training' '4L-test' '4L-training' ...
    '4R-test' '4R-training' '5L-test' '5L-training' '5R-test' '5R-training' ...
    };

FilesNumber = length(FileNames);

%% main part

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
Duration = zeros(1,FilesNumber);

AllActs = struct('SessionName', '',  'Acts', []);

%%
for file = 3:length(FileNames)

    FilenameVideo = sprintf('%s.mp4', FileNames{file});
    FilenameDLC = sprintf('%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
    FilenamePreset = sprintf('%s_Preset.mat', FileNames{file});
    
    fprintf('Processing of NOL_%s\n', FileNames{file})
    
    [Acts, ~, ~] = BehaviorAnalyzerNOL(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
        
    clear 'Acts' 'session';
end

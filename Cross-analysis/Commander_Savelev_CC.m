ExpID = 'CC';
PathVideo = 'e:\Projects\CC\BehaviorData\2_Combined\';
PathDLC = 'e:\Projects\CC\BehaviorData\3_DLC\';
PathsPreset = 'e:\Projects\CC\BehaviorData\4_Preset\\';
PathOut = 'e:\Projects\CC\BehaviorData\5_Behavior\';

%% main part 1D

FileNames = {
    'H01_1D','H02_1D','H03_1D','H04_1D','H05_1D','H06_1D','H07_1D','H08_1D','H09_1D','H10_1D', ...
    'H11_1D','H12_1D','H13_1D','H14_1D','H15_1D','H16_1D','H17_1D','H19_1D','H22_1D','H23_1D'};

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzerSavelev_1D(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
end

%% main part 2D

FileNames = {
    'H01_2D','H02_2D','H03_2D','H04_2D','H05_2D','H06_2D','H07_2D','H08_2D','H09_2D','H10_2D', ...
    'H11_2D','H12_2D','H13_2D','H14_2D','H15_2D','H16_2D','H17_2D','H19_2D','H22_2D','H23_2D'};

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzerSavelev_2D(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
end


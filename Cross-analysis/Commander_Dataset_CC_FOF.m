ExpID = 'CC';
PathVideo = 'e:\Projects\CC\BehaviorData\2_Combined\';
PathDLC = 'e:\Projects\CC\BehaviorData\3_DLC\';
PathPreset = 'e:\Projects\CC\BehaviorData\4_Preset\\';
PathOut = 'e:\Projects\CC\BehaviorData\5_Behavior\';

%% main part 1D

FileNames = {
    'H01_1D','H02_1D','H03_1D','H04_1D','H05_1D','H06_1D','H07_1D','H08_1D','H09_1D','H10_1D', ...
    'H11_1D','H12_1D','H13_1D','H14_1D','H15_1D','H16_1D','H17_1D','H19_1D','H22_1D','H23_1D'};

for file = 19:length(FileNames)
% for file = 1  
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
% for file = 1  
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzerSavelev_2D(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
end


%% paths and filenames

ExpID = 'FOF';
PathVideo = 'e:\Projects\FOF\BehaviorData\2_Combined\';
PathDLC = 'e:\Projects\FOF\BehaviorData\3_DLC\';
PathPreset = 'e:\Projects\FOF\BehaviorData\4_Preset\';

PathOut = 'e:\Projects\FOF\BehaviorData\5_Behavior_2026';

FileNames = {
    'F26_1D' 'F28_1D' 'F01_1D' 'F06_1D' 'F29_1D' 'F30_1D',...
    'F20_1D' 'F08_1D' 'F34_1D' 'F36_1D' 'F38_1D' 'F40_1D',...
    'F04_1D' 'F07_1D' 'F37_1D' 'F12_1D' 'F14_1D' 'F09_1D',...
    'F48_1D' 'F05_1D' 'F43_1D' 'F10_1D' 'F35_1D' 'F31_1D',...
    'F15_1D' 'F41_1D' 'F52_1D' 'F11_1D' 'F53_1D' 'F54_1D',...
    'F26_2D' 'F28_2D' 'F01_2D' 'F06_2D' 'F29_2D' 'F30_2D',...
    'F20_2D' 'F08_2D' 'F34_2D' 'F36_2D' 'F38_2D' 'F40_2D',...
    'F04_2D' 'F07_2D' 'F37_2D' 'F12_2D' 'F14_2D' 'F09_2D',...
    'F48_2D' 'F05_2D' 'F43_2D' 'F10_2D' 'F35_2D' 'F31_2D',...
    'F15_2D' 'F41_2D' 'F52_2D' 'F11_2D' 'F53_2D' 'F54_2D',...
    'F26_3D' 'F28_3D' 'F01_3D' 'F06_3D' 'F29_3D' 'F30_3D',...
    'F20_3D' 'F08_3D' 'F34_3D' 'F36_3D' 'F38_3D' 'F40_3D',...
    'F04_3D' 'F07_3D' 'F37_3D' 'F12_3D' 'F14_3D' 'F09_3D',...
    'F48_3D' 'F05_3D' 'F43_3D' 'F10_3D' 'F35_3D' 'F31_3D',...
    'F15_3D' 'F41_3D' 'F52_3D' 'F11_3D' 'F53_3D' 'F54_3D'
    };

FilesNumber = length(FileNames);

%% main part
for file = 1:length(FileNames)
% for file = 1  
    FilenameVideo = sprintf('FOF_%s.mp4', FileNames{file});
    FilenameDLC = sprintf('FOF_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
    
    if file > 0 && file <= 17
        FilenamePreset = 'FOF_F26_1D_Preset.mat';
    elseif file > 17 && file <= 30
        FilenamePreset = 'FOF_F09_1D_Preset.mat';
    elseif file > 30 && file <= 47
        FilenamePreset = 'FOF_F26_2D_Preset.mat';
    elseif file > 47 && file <= 55
        FilenamePreset = 'FOF_F09_2D_Preset.mat';
    elseif file > 55 && file <= 60
        FilenamePreset = 'FOF_F41_2D_Preset.mat';
    elseif file > 60 && file <= 77
        FilenamePreset = 'FOF_F26_3D_Preset.mat';
    else
        FilenamePreset = 'FOF_F09_3D_Preset.mat';
    end
    
    fprintf('Processing of FOF_%s\n', FileNames{file})
    % fprintf('Processing of NOF_%s\n', FilenamePreset)
    
    [~, ~] = BehaviorAnalyzerFOF(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
end

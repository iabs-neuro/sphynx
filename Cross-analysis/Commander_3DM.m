%% paths and filenames

ExpID = '3DM';

PathVideo = 'w:\Projects\3DM\BehaviorData\2_Combined\';
PathDLC = 'w:\Projects\3DM\BehaviorData\4_DLC\';
PathOut = 'w:\Projects\3DM\BehaviorData\5_Behavior_3_full_plots\';
PathPreset = 'w:\Projects\3DM\BehaviorData\3_Preset\';

% % for ALL DAYS
% FileNames = {
%     'D14_1D_1T' 'D14_2D_1T' 'D14_3D_1T' 'D14_4D_1T' 'D14_5D_1T' 'D14_6D_1T' 'D14_7D_1T' ...
%     'D17_1D_1T' 'D17_2D_1T' 'D17_3D_1T' 'D17_4D_1T' 'D17_5D_1T' 'D17_6D_1T' 'D17_7D_1T' ...
%     'F26_1D_1T' 'F26_2D_1T' 'F26_3D_1T' 'F26_4D_1T' 'F26_5D_1T' 'F26_6D_1T' 'F26_7D_1T' ...
%     'F28_1D_1T' 'F28_2D_1T' 'F28_3D_1T' 'F28_4D_1T' 'F28_5D_1T' 'F28_6D_1T' 'F28_7D_1T' ...
%     'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T' 'F29_6D_1T' 'F29_7D_1T' ...
%     'F30_1D_1T' 'F30_2D_1T' 'F30_3D_1T' 'F30_4D_1T' 'F30_5D_1T' 'F30_6D_1T' 'F30_7D_1T' ...
%     'F31_1D_1T' 'F31_2D_1T' 'F31_3D_1T' 'F31_4D_1T' 'F31_5D_1T' 'F31_6D_1T' 'F31_7D_1T' ...
%     'F35_1D_1T' 'F35_2D_1T' 'F35_3D_1T' 'F35_4D_1T' 'F35_5D_1T' 'F35_6D_1T' 'F35_7D_1T' ...
%     'F36_1D_1T' 'F36_2D_1T' 'F36_3D_1T' 'F36_4D_1T' 'F36_5D_1T'             'F36_7D_1T' ...
%     'F37_1D_1T' 'F37_2D_1T' 'F37_3D_1T' 'F37_4D_1T' 'F37_5D_1T' 'F37_6D_1T' 'F37_7D_1T' ...
%     'F38_1D_1T' 'F38_2D_1T' 'F38_3D_1T' 'F38_4D_1T' 'F38_5D_1T' 'F38_6D_1T' 'F38_7D_1T' ...
%     'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T' 'F40_6D_1T' 'F40_7D_1T' ...
%     'F43_1D_1T' 'F43_2D_1T' 'F43_3D_1T' 'F43_4D_1T' 'F43_5D_1T' 'F43_6D_1T' 'F43_7D_1T' ...
%     'F48_1D_1T' 'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T' 'F48_6D_1T' 'F48_7D_1T' ...
%     'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T' 'F52_6D_1T' 'F52_7D_1T' ...
%     'F54_1D_1T' 'F54_2D_1T' 'F54_3D_1T' 'F54_4D_1T' 'F54_5D_1T' 'F54_6D_1T' 'F54_7D_1T' ...
%     };

% full plots
FileNames = {'F43_1D_1T' 'F36_2D_1T' 'F38_2D_1T' 'F40_6D_1T'};

FilesNumber = length(FileNames);

% for correction framerate
% filess = [16 23 30 37 49 56 58 69 71 78 90 97 104 111];

%% main part


for file = 4:length(FileNames)
    % for file = filess
    FilenameVideo = sprintf('3DM_%s.mp4', FileNames{file});
    FilenameDLC = sprintf('3DM_%sDLC_Resnet101_3DMMar25shuffle3_snapshot_370.csv',FileNames{file});
    FilenamePreset = '3DM_Tunnels_Preset2.mat';
    
    time_end = 0;
    %     if file == 28 || file == 33
    %         time_end = 88959;
    %     elseif file == 83
    %         time_end = 87279;
    %     end
    %
    fprintf('Processing of 3DM_%s\n', FileNames{file})
    
    [Acts, ~, ~, ~, session] = BehaviorAnalyzer3DM(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, time_end, PathPreset, FilenamePreset);
    
    clear 'Acts' 'session';
end

%% paths and filenames

PathVideo = 'w:\Projects\FOF\BehaviorData\2_Combined\';
PathDLC = 'w:\Projects\FOF\BehaviorData\3_DLC\';
PathPreset = 'w:\Projects\FOF\BehaviorData\4_Preset\';

PathOut = 'w:\Projects\FOF\BehaviorData\5_Behavior';

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

PathMat = 'd:\Projects\H_mice\8_matfiles\';

%% variables initiation

FreezingPercent = zeros(1,FilesNumber);
FreezingNumber = zeros(1,FilesNumber);
FreezingMeanTime = zeros(1,FilesNumber);

RearsPercent = zeros(1,FilesNumber);
RearsNumber = zeros(1,FilesNumber);
RearsMeanTime = zeros(1,FilesNumber);

CornersWallsCenterPercent = zeros(4,FilesNumber);
CornersWallsCenterNumber = zeros(4,FilesNumber);
CornersWallsCenterMeanTime = zeros(4,FilesNumber);
CornersWallsCenterDistance = zeros(4,FilesNumber);
CornersWallsCenterMeanDistance = zeros(4,FilesNumber);
CornersWallsCenterVelocity = zeros(4,FilesNumber);

RestOtherLocomotionPercent = zeros(3,FilesNumber);
RestOtherLocomotionNumber = zeros(3,FilesNumber);
RestOtherLocomotionMeanTime = zeros(3,FilesNumber);
RestOtherLocomotionDistance = zeros(3,FilesNumber);
RestOtherLocomotionMeanDistance = zeros(3,FilesNumber);
RestOtherLocomotionVelocity = zeros(3,FilesNumber);

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

%% main part
for file = 1:length(FileNames)
    
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
    
    [Acts, BodyPartsTraces] = BehaviorAnalyzerFOF(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    % load (sprintf('%sNOF_%s_WorkSpace.mat',PathMat,FileNames{file}), 'Acts', 'BodyPartsTraces');
    
    % variables calculaion
    FreezingPercent(file) = Acts(4).ActPercent;
    FreezingNumber(file) = Acts(4).ActNumber;
    FreezingMeanTime(file) = Acts(4).ActMeanTime;
    
    RearsPercent(file) = Acts(5).ActPercent;
    RearsNumber(file) = Acts(5).ActNumber;
    RearsMeanTime(file) = Acts(5).ActMeanTime;
    
    CornersWallsCenterPercent(1:4,file) = [Acts(6).ActPercent; Acts(7).ActPercent; Acts(8).ActPercent; Acts(9).ActPercent];
    CornersWallsCenterNumber(1:4,file) = [Acts(6).ActNumber; Acts(7).ActNumber; Acts(8).ActNumber; Acts(9).ActNumber];
    CornersWallsCenterMeanTime(1:4,file) = [Acts(6).ActMeanTime; Acts(7).ActMeanTime; Acts(8).ActMeanTime; Acts(9).ActMeanTime];
    CornersWallsCenterDistance(1:4,file) = [Acts(6).Distance; Acts(7).Distance; Acts(8).Distance; Acts(9).Distance];
    CornersWallsCenterMeanDistance(1:4,file) = [Acts(6).ActMeanDistance; Acts(7).ActMeanDistance; Acts(8).ActMeanDistance; Acts(9).ActMeanDistance];
    CornersWallsCenterVelocity(1:4,file) = CornersWallsCenterDistance(1:4,file)./(CornersWallsCenterMeanTime(1:4,file).*CornersWallsCenterNumber(1:4,file))*100;
    
    RestOtherLocomotionPercent(1:3,file) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
    RestOtherLocomotionNumber(1:3,file) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
    RestOtherLocomotionMeanTime(1:3,file) = [Acts(1).ActMeanTime; Acts(2).ActMeanTime; Acts(3).ActMeanTime];
    RestOtherLocomotionDistance(1:3,file) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
    RestOtherLocomotionMeanDistance(1:3,file) = [Acts(1).ActMeanDistance; Acts(2).ActMeanDistance; Acts(3).ActMeanDistance];
    RestOtherLocomotionVelocity(1:3,file) = RestOtherLocomotionDistance(1:3,file)./(RestOtherLocomotionMeanTime(1:3,file).*RestOtherLocomotionNumber(1:3,file))*100;
    
    Distance(file) = BodyPartsTraces(12).AverageDistance;
    Velocity(file) = BodyPartsTraces(12).AverageSpeed;
    
    clear 'Acts' 'BodyPartsTraces';
end


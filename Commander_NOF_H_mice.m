%% paths and filenames

PathVideo = 'd:\Projects\H_mice\2_RawCombineVideo\';
PathDLC = 'd:\Projects\H_mice\3_DLC\';
PathOut = 'd:\Projects\H_mice\5_Behavior_full_video\';
% PathOut = 'd:\Projects\H_mice\5_Behavior_only_features\';

PathPreset = 'd:\Projects\H_mice\4_Presets\';

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

FilesNumber = length(FileNames);

PathMat = 'd:\Projects\H_mice\8_matfiles\';

%% variables initiation

FreezingPercent = zeros(1,FilesNumber);
FreezingNumber = zeros(1,FilesNumber);
FreezingMeanTime = zeros(1,FilesNumber);

RearsPercent = zeros(1,FilesNumber);
RearsNumber = zeros(1,FilesNumber);
RearsMeanTime = zeros(1,FilesNumber);

CornersWallsCenterPercent = zeros(3,FilesNumber);
CornersWallsCenterNumber = zeros(3,FilesNumber);
CornersWallsCenterMeanTime = zeros(3,FilesNumber);
CornersWallsCenterDistance = zeros(3,FilesNumber);
CornersWallsCenterMeanDistance = zeros(3,FilesNumber);
CornersWallsCenterVelocity = zeros(3,FilesNumber);

RestOtherLocomotionPercent = zeros(3,FilesNumber);
RestOtherLocomotionNumber = zeros(3,FilesNumber);
RestOtherLocomotionMeanTime = zeros(3,FilesNumber);
RestOtherLocomotionDistance = zeros(3,FilesNumber);
RestOtherLocomotionMeanDistance = zeros(3,FilesNumber);
RestOtherLocomotionVelocity = zeros(3,FilesNumber);

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

% NOF objects
ObjectNumber = zeros(5,length(FileNames));
ObjectPercent = zeros(5,length(FileNames));
ObjectMeanTime = zeros(5,length(FileNames));
ObjectMeanDistance = zeros(5,length(FileNames));
ObjectDistance = zeros(5,length(FileNames));

%% main part
for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('NOF_%s.mp4', FileNames{file});
    FilenameDLC = sprintf('NOF_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
    
    if file > 9 && file < 17
        FilenamePreset = 'NOF_H26_1D_Preset.mat';        
    elseif (file > 25 && file < 33) || (file > 41 && file <  49) || (file > 57)
        FilenamePreset = 'NOF_H26_2D_Preset.mat';
    else
        FilenamePreset = sprintf('NOF_%s_Preset.mat', FileNames{file});
    end
    
    fprintf('Processing of NOF_%s\n', FileNames{file})
%     fprintf('Processing of NOF_%s\n', FilenamePreset)

[Acts, BodyPartsTraces] = BehaviorAnalyzerNOF(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
%     load (sprintf('%sNOF_%s_WorkSpace.mat',PathMat,FileNames{file}), 'Acts', 'BodyPartsTraces');
    
    % variables calculaion
    
    FreezingPercent(file) = Acts(4).ActPercent;
    FreezingNumber(file) = Acts(4).ActNumber;
    FreezingMeanTime(file) = Acts(4).ActMeanTime;
    
    RearsPercent(file) = Acts(5).ActPercent;
    RearsNumber(file) = Acts(5).ActNumber;
    RearsMeanTime(file) = Acts(5).ActMeanTime;    
    
    CornersWallsCenterPercent(1:3,file) = [Acts(6).ActPercent; Acts(7).ActPercent; Acts(8).ActPercent];
    CornersWallsCenterNumber(1:3,file) = [Acts(6).ActNumber; Acts(7).ActNumber; Acts(8).ActNumber];
    CornersWallsCenterMeanTime(1:3,file) = [Acts(6).ActMeanTime; Acts(7).ActMeanTime; Acts(8).ActMeanTime];
    CornersWallsCenterDistance(1:3,file) = [Acts(6).Distance; Acts(7).Distance; Acts(8).Distance];
    CornersWallsCenterMeanDistance(1:3,file) = [Acts(6).ActMeanDistance; Acts(7).ActMeanDistance; Acts(8).ActMeanDistance];
    CornersWallsCenterVelocity(1:3,file) = CornersWallsCenterDistance(1:3,file)./(CornersWallsCenterMeanTime(1:3,file).*CornersWallsCenterNumber(1:3,file))*100;
    
    RestOtherLocomotionPercent(1:3,file) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
    RestOtherLocomotionNumber(1:3,file) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
    RestOtherLocomotionMeanTime(1:3,file) = [Acts(1).ActMeanTime; Acts(2).ActMeanTime; Acts(3).ActMeanTime];
    RestOtherLocomotionDistance(1:3,file) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
    RestOtherLocomotionMeanDistance(1:3,file) = [Acts(1).ActMeanDistance; Acts(2).ActMeanDistance; Acts(3).ActMeanDistance];
    RestOtherLocomotionVelocity(1:3,file) = RestOtherLocomotionDistance(1:3,file)./(RestOtherLocomotionMeanTime(1:3,file).*RestOtherLocomotionNumber(1:3,file))*100;
   
    Distance(file) = BodyPartsTraces(12).AverageDistance;
    Velocity(file) = BodyPartsTraces(12).AverageSpeed;
    
    ObjectNumber(1:5,file) = [Acts(9).ActNumber; Acts(10).ActNumber; Acts(11).ActNumber; Acts(12).ActNumber; Acts(13).ActNumber];
    ObjectPercent(1:5,file) = [Acts(9).ActPercent; Acts(10).ActPercent; Acts(11).ActPercent; Acts(12).ActPercent; Acts(13).ActPercent];
    ObjectMeanTime(1:5,file) = [Acts(9).ActMeanTime; Acts(10).ActMeanTime; Acts(11).ActMeanTime; Acts(12).ActMeanTime; Acts(13).ActMeanTime];
    ObjectMeanDistance(1:5,file) = [Acts(9).ActMeanDistance; Acts(10).ActMeanDistance; Acts(11).ActMeanDistance; Acts(12).ActMeanDistance; Acts(13).ActMeanDistance];
    ObjectDistance = ObjectNumber.*ObjectMeanDistance;
    
    clear 'Acts' 'BodyPartsTraces';
end

    
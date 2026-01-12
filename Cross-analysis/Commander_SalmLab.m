%% paths and filenames

PathVideo = 'd:\_WORK\Project_DLC_Salm_lab\video\';
PathDLC = 'd:\_WORK\Project_DLC_Salm_lab\DLC\';
PathPreset = 'd:\_WORK\Project_DLC_Salm_lab\Preset\';

PathOut = 'd:\_WORK\Project_DLC_Salm_lab\Behavior\';

FileNames = {
    '1.1' '1.1' ...
    '1.1' '1.1' ...
    };

FilesNumber = length(FileNames);

%% variables initiation

FreezingPercent = zeros(1,FilesNumber);
FreezingNumber = zeros(1,FilesNumber);

RearsNumber = zeros(1,FilesNumber);

CornersWallsCenterPercent = zeros(3,FilesNumber); 
CornersWallsCenterNumber = zeros(3,FilesNumber);
CornersWallsCenterDistance = zeros(3,FilesNumber);
CornersWallsCenterVelocity = zeros(3,FilesNumber);

RestOtherLocomotionPercent = zeros(3,FilesNumber);
RestOtherLocomotionNumber = zeros(3,FilesNumber);
RestOtherLocomotionDistance = zeros(3,FilesNumber);

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

% % objects
% ObjectNumber = zeros(3,length(FileNames));
% ObjectPercent = zeros(3,length(FileNames));

%% main part

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s.mp4', FileNames{file});
    FilenameDLC = sprintf('%sDLC_Resnet101_MiceFriltySep23shuffle1_snapshot_160.csv', FileNames{file});
    FilenamePreset = sprintf('%s_Preset.mat',  FileNames{file});
    
    fprintf('Processing of %s\n',  FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzerSalmLab(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);

    % variables calculaion    
    FreezingPercent(file) = Acts(4).ActPercent;
    FreezingNumber(file) = Acts(4).ActNumber;
    
    RearsNumber(file) = Acts(5).ActNumber;
    
    CornersWallsCenterPercent(1:3,file) = [Acts(6).ActPercent; Acts(7).ActPercent; Acts(8).ActPercent];
    CornersWallsCenterNumber(1:3,file) = [Acts(6).ActNumber; Acts(7).ActNumber; Acts(8).ActNumber];
    CornersWallsCenterDistance(1:3,file) = [Acts(6).Distance; Acts(7).Distance; Acts(8).Distance];
    CornersWallsCenterVelocity(1:3,file) = CornersWallsCenterDistance(1:3,file)./(CornersWallsCenterMeanTime(1:3,file).*CornersWallsCenterNumber(1:3,file))*100;
    
    RestOtherLocomotionPercent(1:3,file) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
    RestOtherLocomotionNumber(1:3,file) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
    RestOtherLocomotionDistance(1:3,file) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
  
    Distance(file) = BodyPartsTraces(12).AverageDistance;
    Velocity(file) = BodyPartsTraces(12).AverageSpeed;
    
%     ObjectNumber(1:3,file) = [Acts(9).ActNumber; Acts(10).ActNumber; Acts(11).ActNumber; Acts(12).ActNumber; Acts(13).ActNumber];
%     ObjectPercent(1:3,file) = [Acts(9).ActPercent; Acts(10).ActPercent; Acts(11).ActPercent; Acts(12).ActPercent; Acts(13).ActPercent];
%     
end


%% paths and filenames

PathVideo = 'd:\Projects\BOF\VideoData\';
PathDLC = 'd:\Projects\BOF\DLC\';
PathOut = 'd:\Projects\BOF\Behavior\';

PathPreset = 'd:\Projects\BOF\Presets\';

% 1T
FileNames = {
    'H02_1T','H03_1T','H04_1T','H07_1T','H08_1T','H10_1T','H11_1T','H12_1T','H13_1T','H14_1T','H15_1T','H16_1T','H17_1T','H19_1T','H22_1T','H23_1T'
    };
ArenaType = 'circle';

% % 2T
% FileNames = {
%     'H02_2T','H03_2T','H04_2T','H07_2T','H08_2T','H10_2T','H11_2T','H12_2T','H13_2T','H14_2T','H15_2T','H16_2T','H17_2T','H19_2T','H22_2T','H23_2T'
%     };
% ArenaType = 'circle';
% 
% 
% % 3T
% FileNames = {
%     'H02_3T','H03_3T','H04_3T','H07_3T','H08_3T','H10_3T','H11_3T','H12_3T','H13_3T','H14_3T','H15_3T','H16_3T','H17_3T','H19_3T','H22_3T','H23_3T'
%     };
% ArenaType = 'circle';
% 
% % 4T
% FileNames = {
%     'H02_4T','H03_4T','H04_4T','H07_4T','H08_4T','H10_4T','H11_4T','H12_4T','H13_4T','H14_4T','H15_4T','H16_4T','H17_4T','H19_4T','H22_4T','H23_4T'
%     };
% ArenaType = 'polygon';
% 
% % 5T
% FileNames = {
%     'H02_5T','H03_5T','H04_5T','H07_5T','H08_5T','H10_5T','H11_5T','H12_5T','H13_5T','H14_5T','H15_5T','H16_5T','H17_5T','H19_5T','H22_5T','H23_5T'
%     };
% ArenaType = 'circle';

FilesNumber = length(FileNames);

%% variables initiation

FreezingPercent = zeros(1,FilesNumber);
FreezingNumber = zeros(1,FilesNumber);
FreezingMeanTime = zeros(1,FilesNumber);

RearsPercent = zeros(1,FilesNumber);
RearsNumber = zeros(1,FilesNumber);
RearsMeanTime = zeros(1,FilesNumber);

if ArenaType == "polygon"
    CornersWallsCenterPercent = zeros(3,FilesNumber);
    CornersWallsCenterNumber = zeros(3,FilesNumber);
    CornersWallsCenterMeanTime = zeros(3,FilesNumber);
    CornersWallsCenterDistance = zeros(3,FilesNumber);
    CornersWallsCenterMeanDistance = zeros(3,FilesNumber);
    CornersWallsCenterVelocity = zeros(3,FilesNumber);
else
    WallsMiddleCenterPercent = zeros(3,FilesNumber);
    WallsMiddleCenterNumber = zeros(3,FilesNumber);
    WallsMiddleCenterMeanTime = zeros(3,FilesNumber);
    WallsMiddleCenterDistance = zeros(3,FilesNumber);
    WallsMiddleCenterMeanDistance = zeros(3,FilesNumber);
    WallsMiddleCenterVelocity = zeros(3,FilesNumber);
end

RestOtherLocomotionPercent = zeros(3,FilesNumber);
RestOtherLocomotionNumber = zeros(3,FilesNumber);
RestOtherLocomotionMeanTime = zeros(3,FilesNumber);
RestOtherLocomotionDistance = zeros(3,FilesNumber);
RestOtherLocomotionMeanDistance = zeros(3,FilesNumber);
RestOtherLocomotionVelocity = zeros(3,FilesNumber);

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

% BOF objects 1T
ObjectNumber = zeros(1,length(FileNames));
ObjectPercent = zeros(1,length(FileNames));
ObjectMeanTime = zeros(1,length(FileNames));
ObjectMeanDistance = zeros(1,length(FileNames));
ObjectDistance = zeros(1,length(FileNames));

% % BOF objects 2-5T
% ObjectNumber = zeros(2,length(FileNames));
% ObjectPercent = zeros(2,length(FileNames));
% ObjectMeanTime = zeros(2,length(FileNames));
% ObjectMeanDistance = zeros(2,length(FileNames));
% ObjectDistance = zeros(2,length(FileNames));

%% main part
for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('BOF_%s.mp4', FileNames{file});
    FilenameDLC = sprintf('BOF_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
    
    FilenamePreset = sprintf('BOF_%s_Preset.mat', FileNames{file});
    fprintf('Processing of BOF_%s\n', FileNames{file})
    
    [Acts, BodyPartsTraces] = BehaviorAnalyzerBOF(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    % variables calculaion
    
    FreezingPercent(file) = Acts(4).ActPercent;
    FreezingNumber(file) = Acts(4).ActNumber;
    FreezingMeanTime(file) = Acts(4).ActMeanTime;
    
    RearsPercent(file) = Acts(5).ActPercent;
    RearsNumber(file) = Acts(5).ActNumber;
    RearsMeanTime(file) = Acts(5).ActMeanTime;
    
    if ArenaType == "polygon"
        
        CornersWallsCenterPercent(1:3,file) = [Acts(6).ActPercent; Acts(7).ActPercent; Acts(8).ActPercent];
        CornersWallsCenterNumber(1:3,file) = [Acts(6).ActNumber; Acts(7).ActNumber; Acts(8).ActNumber];
        CornersWallsCenterMeanTime(1:3,file) = [Acts(6).ActMeanTime; Acts(7).ActMeanTime; Acts(8).ActMeanTime];
        CornersWallsCenterDistance(1:3,file) = [Acts(6).Distance; Acts(7).Distance; Acts(8).Distance];
        CornersWallsCenterMeanDistance(1:3,file) = [Acts(6).ActMeanDistance; Acts(7).ActMeanDistance; Acts(8).ActMeanDistance];
        CornersWallsCenterVelocity(1:3,file) = CornersWallsCenterDistance(1:3,file)./(CornersWallsCenterMeanTime(1:3,file).*CornersWallsCenterNumber(1:3,file))*100;
    else
        WallsMiddleCenterPercent(1:3,file) = [Acts(6).ActPercent; Acts(7).ActPercent; Acts(8).ActPercent];
        WallsMiddleCenterNumber(1:3,file) = [Acts(6).ActNumber; Acts(7).ActNumber; Acts(8).ActNumber];
        WallsMiddleCenterMeanTime(1:3,file) = [Acts(6).ActMeanTime; Acts(7).ActMeanTime; Acts(8).ActMeanTime];
        WallsMiddleCenterDistance(1:3,file) = [Acts(6).Distance; Acts(7).Distance; Acts(8).Distance];
        WallsMiddleCenterMeanDistance(1:3,file) = [Acts(6).ActMeanDistance; Acts(7).ActMeanDistance; Acts(8).ActMeanDistance];
        WallsMiddleCenterVelocity(1:3,file) = CornersWallsCenterDistance(1:3,file)./(CornersWallsCenterMeanTime(1:3,file).*CornersWallsCenterNumber(1:3,file))*100;
        
    end
    RestOtherLocomotionPercent(1:3,file) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
    RestOtherLocomotionNumber(1:3,file) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
    RestOtherLocomotionMeanTime(1:3,file) = [Acts(1).ActMeanTime; Acts(2).ActMeanTime; Acts(3).ActMeanTime];
    RestOtherLocomotionDistance(1:3,file) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
    RestOtherLocomotionMeanDistance(1:3,file) = [Acts(1).ActMeanDistance; Acts(2).ActMeanDistance; Acts(3).ActMeanDistance];
    RestOtherLocomotionVelocity(1:3,file) = RestOtherLocomotionDistance(1:3,file)./(RestOtherLocomotionMeanTime(1:3,file).*RestOtherLocomotionNumber(1:3,file))*100;
   
    Distance(file) = BodyPartsTraces(12).AverageDistance;
    Velocity(file) = BodyPartsTraces(12).AverageSpeed;
    
    % for 1T
    ObjectNumber(1,file) = Acts(9).ActNumber;
    ObjectPercent(1,file) = Acts(9).ActPercent;
    ObjectMeanTime(1,file) = Acts(9).ActMeanTime;
    ObjectMeanDistance(1,file) = Acts(9).ActMeanDistance;
    ObjectDistance = ObjectNumber.*ObjectMeanDistance;
    
    % for 2-5T
    ObjectNumber(1,file) = [Acts(9).ActNumber; Acts(10).ActNumber];
    ObjectPercent(1,file) = [Acts(9).ActPercent; Acts(10).ActPercent];
    ObjectMeanTime(1,file) = [Acts(9).ActMeanTime; Acts(10).ActMeanTime];
    ObjectMeanDistance(1,file) = [Acts(9).ActMeanDistance; Acts(10).ActMeanDistance];
    ObjectDistance = ObjectNumber.*ObjectMeanDistance;
    
    clear 'Acts' 'BodyPartsTraces';
end

    
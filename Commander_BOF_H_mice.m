%% paths and filenames

PathVideo = 'w:\Projects\BOF\BehaviorData\2_Combined\';
PathDLC = 'w:\Projects\BOF\BehaviorData\3_DLC\';
PathOut = 'w:\Projects\BOF\BehaviorData\5_Behavior\';

PathPreset = 'w:\Projects\BOF\BehaviorData\4_Presets\';

% % 1T
% FileNames = {
%     'H02_1T','H03_1T','H04_1T','H06_1T','H07_1T','H10_1T','H11_1T','H12_1T','H13_1T','H14_1T','H15_1T','H16_1T','H17_1T','H19_1T','H22_1T','H26_1T','H27_1T','H31_1T','H32_1T','H33_1T','H39_1T'
%     };
% ArenaType = 'circle';

% 2T
% FileNames = {
%      'H02_2T','H03_2T','H04_2T','H06_2T','H07_2T','H10_2T','H11_2T','H12_2T','H13_2T','H14_2T','H15_2T','H16_2T','H17_2T','H19_2T','H22_2T','H26_2T','H27_2T','H31_2T','H32_2T','H33_2T','H39_2T'
%     };
% ArenaType = 'circle';

% 3T
% FileNames = {
%    'H02_3T','H03_3T','H04_3T','H06_3T','H07_3T','H10_3T','H11_3T','H12_3T','H13_3T','H14_3T','H15_3T','H16_3T','H17_3T','H19_3T','H22_3T','H26_3T','H27_3T','H31_3T','H32_3T','H33_3T','H39_3T'
%     };
% ArenaType = 'circle';

% 4T
FileNames = {
   'H02_4T','H03_4T','H04_4T','H06_4T','H07_4T','H10_4T','H11_4T','H12_4T','H13_4T','H14_4T','H15_4T','H16_4T','H17_4T','H19_4T','H22_4T','H26_4T','H27_4T','H31_4T','H32_4T','H33_4T','H39_4T'
    };
ArenaType = 'polygon';

% 5T
% FileNames = {
%    'H02_5T','H03_5T','H04_5T','H06_5T','H07_5T','H10_5T','H11_5T','H12_5T','H13_5T','H14_5T','H15_5T','H16_5T','H17_5T','H19_5T','H22_5T','H26_5T','H27_5T','H31_5T','H32_5T','H33_5T','H39_5T'
%     };
% ArenaType = 'circle';

% for 2T,3T,5T
% FileNames = {
%     'H02_2T','H03_2T','H04_2T','H06_2T','H07_2T','H10_2T','H11_2T','H12_2T','H13_2T','H14_2T','H15_2T','H16_2T','H17_2T','H19_2T','H22_2T','H26_2T','H27_2T','H31_2T','H32_2T','H33_2T','H39_2T',...
%     'H02_3T','H03_3T','H04_3T','H06_3T','H07_3T','H10_3T','H11_3T','H12_3T','H13_3T','H14_3T','H15_3T','H16_3T','H17_3T','H19_3T','H22_3T','H26_3T','H27_3T','H31_3T','H32_3T','H33_3T','H39_3T',...
%     'H02_5T','H03_5T','H04_5T','H06_5T','H07_5T','H10_5T','H11_5T','H12_5T','H13_5T','H14_5T','H15_5T','H16_5T','H17_5T','H19_5T','H22_5T','H26_5T','H27_5T','H31_5T','H32_5T','H33_5T','H39_5T'
%     };
% ArenaType = 'circle';
% ArenaType = 'polygon';

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

% specific-related variables
% BOF objects 1T
% ObjectNumber = zeros(4,length(FileNames));
% ObjectPercent = zeros(4,length(FileNames));
% ObjectMeanTime = zeros(4,length(FileNames));
% ObjectMeanDistance = zeros(4,length(FileNames));
% ObjectDistance = zeros(4,length(FileNames));
% ObjectVelocity = zeros(4,length(FileNames));
% 
% EntryNumber = zeros(8,length(FileNames));
% EntryPercent = zeros(8,length(FileNames));
% EntryMeanTime = zeros(8,length(FileNames));
% EntryMeanDistance = zeros(8,length(FileNames));
% EntryDistance = zeros(8,length(FileNames));
% EntryVelocity = zeros(8,length(FileNames));

% % BOF objects 2-5T
ObjectNumber = zeros(8,length(FileNames));
ObjectPercent = zeros(8,length(FileNames));
ObjectMeanTime = zeros(8,length(FileNames));
ObjectMeanDistance = zeros(8,length(FileNames));
ObjectDistance = zeros(8,length(FileNames));
ObjectVelocity = zeros(8,length(FileNames));

EntryNumber = zeros(16,length(FileNames));
EntryPercent = zeros(16,length(FileNames));
EntryMeanTime = zeros(16,length(FileNames));
EntryMeanDistance = zeros(16,length(FileNames));
EntryDistance = zeros(16,length(FileNames));
EntryVelocity = zeros(16,length(FileNames));

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
        WallsMiddleCenterVelocity(1:3,file) = WallsMiddleCenterDistance(1:3,file)./(WallsMiddleCenterMeanTime(1:3,file).*WallsMiddleCenterNumber(1:3,file))*100;        
    end
    
    RestOtherLocomotionPercent(1:3,file) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
    RestOtherLocomotionNumber(1:3,file) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
    RestOtherLocomotionMeanTime(1:3,file) = [Acts(1).ActMeanTime; Acts(2).ActMeanTime; Acts(3).ActMeanTime];
    RestOtherLocomotionDistance(1:3,file) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
    RestOtherLocomotionMeanDistance(1:3,file) = [Acts(1).ActMeanDistance; Acts(2).ActMeanDistance; Acts(3).ActMeanDistance];
    RestOtherLocomotionVelocity(1:3,file) = RestOtherLocomotionDistance(1:3,file)./(RestOtherLocomotionMeanTime(1:3,file).*RestOtherLocomotionNumber(1:3,file))*100;
   
    Distance(file) = BodyPartsTraces(13).AverageDistance;
    Velocity(file) = BodyPartsTraces(13).AverageSpeed;
    
%     % for 1T
%     ObjectNumber(1:4,file) = [Acts(9).ActNumber; Acts(10).ActNumber; Acts(11).ActNumber;Acts(20).ActNumber];
%     ObjectPercent(1:4,file) = [Acts(9).ActPercent; Acts(10).ActPercent; Acts(11).ActPercent;Acts(20).ActPercent];
%     ObjectMeanTime(1:4,file) = [Acts(9).ActMeanTime; Acts(10).ActMeanTime; Acts(11).ActMeanTime;Acts(20).ActMeanTime];
%     ObjectMeanDistance(1:4,file) = [Acts(9).ActMeanDistance; Acts(10).ActMeanDistance; Acts(11).ActMeanDistance;Acts(20).ActMeanDistance];
%     ObjectDistance(1:4,file) = [Acts(9).Distance; Acts(10).Distance; Acts(11).Distance;Acts(20).Distance];
%     ObjectVelocity(1:4,file) = ObjectDistance(1:4,file)./(ObjectMeanTime(1:4,file).*ObjectNumber(1:4,file))*100;
%         
%     EntryNumber(1:8,file) =  [Acts(12).ActNumber; Acts(13).ActNumber; Acts(14).ActNumber; Acts(15).ActNumber ;Acts(16).ActNumber; Acts(17).ActNumber; Acts(18).ActNumber;Acts(19).ActNumber];
%     EntryPercent(1:8,file) = [Acts(12).ActPercent; Acts(13).ActPercent; Acts(14).ActPercent; Acts(15).ActPercent; Acts(16).ActPercent; Acts(17).ActPercent; Acts(18).ActPercent;Acts(19).ActPercent];
%     EntryMeanTime(1:8,file) = [Acts(12).ActMeanTime; Acts(13).ActMeanTime; Acts(14).ActMeanTime; Acts(15).ActMeanTime; Acts(16).ActMeanTime; Acts(17).ActMeanTime; Acts(18).ActMeanTime;Acts(19).ActMeanTime];
%     EntryMeanDistance(1:8,file) = [Acts(12).ActMeanDistance; Acts(13).ActMeanDistance; Acts(14).ActMeanDistance;Acts(15).ActMeanDistance; Acts(16).ActMeanDistance; Acts(17).ActMeanDistance; Acts(18).ActMeanDistance; Acts(19).ActMeanDistance];
%     EntryDistance(1:8,file) = [Acts(12).Distance; Acts(13).Distance; Acts(14).Distance; Acts(15).Distance; Acts(16).Distance; Acts(17).Distance; Acts(18).Distance; Acts(19).Distance];
%     EntryVelocity(1:8,file) = EntryDistance(1:8,file)./(EntryMeanTime(1:8,file).*EntryNumber(1:8,file))*100;
    
%     % for 2-5T
    ObjectNumber(1:8,file)          = [Acts(9).ActNumber;Acts(10).ActNumber;Acts(13).ActNumber;Acts(31).ActNumber;       Acts(11).ActNumber;Acts(12).ActNumber;Acts(14).ActNumber;Acts(32).ActNumber];
    ObjectPercent(1:8,file)         = [Acts(9).ActPercent;Acts(10).ActPercent;Acts(11).ActPercent;Acts(20).ActPercent;   Acts(11).ActPercent;Acts(12).ActPercent;Acts(14).ActPercent;Acts(32).ActPercent];
    ObjectMeanTime(1:8,file)        = [Acts(9).ActMeanTime;Acts(10).ActMeanTime;Acts(11).ActMeanTime;Acts(20).ActMeanTime;  Acts(11).ActMeanTime;Acts(12).ActMeanTime;Acts(14).ActMeanTime;Acts(32).ActMeanTime];
    ObjectMeanDistance(1:8,file)    = [Acts(9).ActMeanDistance; Acts(10).ActMeanDistance;Acts(11).ActMeanDistance;Acts(20).ActMeanDistance;     Acts(11).ActMeanDistance; Acts(12).ActMeanDistance;Acts(14).ActMeanDistance;Acts(32).ActMeanDistance;];
    ObjectDistance(1:8,file)        = [Acts(9).Distance; Acts(10).Distance; Acts(11).Distance;Acts(20).Distance;    Acts(11).Distance; Acts(12).Distance; Acts(14).Distance;Acts(32).Distance;];
    ObjectVelocity(1:8,file)        = ObjectDistance(1:8,file)./(ObjectMeanTime(1:8,file).*ObjectNumber(1:8,file))*100;
    
    EntryNumber(1:16,file) =  [Acts(15).ActNumber; Acts(16).ActNumber; Acts(17).ActNumber; Acts(18).ActNumber ;Acts(19).ActNumber; Acts(20).ActNumber;...
        Acts(21).ActNumber;Acts(22).ActNumber;Acts(23).ActNumber; Acts(24).ActNumber; Acts(25).ActNumber; Acts(26).ActNumber ;Acts(27).ActNumber; Acts(28).ActNumber;Acts(29).ActNumber; Acts(30).ActNumber];
    
    EntryPercent(1:16,file) = [Acts(15).ActPercent; Acts(16).ActPercent; Acts(17).ActPercent; Acts(18).ActPercent ;Acts(19).ActPercent; Acts(20).ActPercent;...
        Acts(21).ActPercent;Acts(22).ActPercent;Acts(23).ActPercent; Acts(24).ActPercent; Acts(25).ActPercent; Acts(26).ActPercent ;Acts(27).ActPercent; Acts(28).ActPercent;Acts(29).ActPercent; Acts(30).ActPercent];
    
    EntryMeanTime(1:16,file) = [Acts(15).ActMeanTime; Acts(16).ActMeanTime; Acts(17).ActMeanTime; Acts(18).ActMeanTime ;Acts(19).ActMeanTime; Acts(20).ActMeanTime;...
        Acts(21).ActMeanTime;Acts(22).ActMeanTime;Acts(23).ActMeanTime; Acts(24).ActMeanTime; Acts(25).ActMeanTime; Acts(26).ActMeanTime ;Acts(27).ActMeanTime; Acts(28).ActMeanTime;Acts(29).ActMeanTime; Acts(30).ActMeanTime];
    
    EntryMeanDistance(1:16,file) = [Acts(15).ActMeanDistance; Acts(16).ActMeanDistance; Acts(17).ActMeanDistance; Acts(18).ActMeanDistance ;Acts(19).ActMeanDistance; Acts(20).ActMeanDistance;...
        Acts(21).ActMeanDistance;Acts(22).ActMeanDistance;Acts(23).ActMeanDistance; Acts(24).ActMeanDistance; Acts(25).ActMeanDistance; Acts(26).ActMeanDistance ;Acts(27).ActMeanDistance; Acts(28).ActMeanDistance;Acts(29).ActMeanDistance; Acts(30).ActMeanDistance];
    
    EntryDistance(1:16,file) = [Acts(15).Distance; Acts(16).Distance; Acts(17).Distance; Acts(18).Distance ;Acts(19).Distance; Acts(20).Distance;...
        Acts(21).Distance;Acts(22).Distance;Acts(23).Distance; Acts(24).Distance; Acts(25).Distance; Acts(26).Distance ;Acts(27).Distance; Acts(28).Distance;Acts(29).Distance; Acts(30).Distance];
    
    EntryVelocity(1:16,file) = EntryDistance(1:16,file)./(EntryMeanTime(1:16,file).*EntryNumber(1:16,file))*100;
    
    clear 'Acts' 'BodyPartsTraces';
end

    
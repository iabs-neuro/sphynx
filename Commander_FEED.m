%% paths and filenames

PathVideo = 'h:\Projects\Feed\2_CombinedData\';
PathDLC = 'h:\Projects\Feed\3_DLC\';
PathOut = 'h:\Projects\Feed\5_Behavior\';

PathPreset = 'h:\Projects\Feed\4_Presets\';


FileNames = {
    'M01','M02','M03','M04','M05','M06','M07','M08','M09','M10','M11'
    };

FilesNumber = length(FileNames);

%% variables initiation

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

% BOF objects 1T
ObjectNumber = zeros(3,length(FileNames));
ObjectPercent = zeros(3,length(FileNames));
ObjectMeanTime = zeros(3,length(FileNames));
ObjectMeanDistance = zeros(3,length(FileNames));
ObjectDistance = zeros(3,length(FileNames));

%% main part
for file = 2:length(FileNames)
    
    FilenameVideo = sprintf('%s.mp4', FileNames{file});
    FilenameDLC = sprintf('%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
    
    FilenamePreset = sprintf('%s_Preset.mat', FileNames{file});
    fprintf('Processing of FEED_%s\n', FileNames{file})
    
    [Acts, BodyPartsTraces] = BehaviorAnalyzerFEED(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    
    % common variables calculaion
    Distance(file) = BodyPartsTraces(12).AverageDistance;
    Velocity(file) = BodyPartsTraces(12).AverageSpeed;
    
    % task-specific variabels calculaion
%      9: {'feeding'} 
%      8: {'interaction'} 
%     11: {'bowlinside'}
    ObjectNumber(1:3,file) = [Acts(9).ActNumber; Acts(8).ActNumber; Acts(11).ActNumber];
    ObjectPercent(1:3,file) = [Acts(9).ActPercent; Acts(8).ActPercent; Acts(11).ActPercent];
    ObjectMeanTime(1:3,file) = [Acts(9).ActMeanTime; Acts(8).ActMeanTime; Acts(11).ActMeanTime];
    ObjectMeanDistance(1:3,file) = [Acts(9).ActMeanDistance; Acts(8).ActMeanDistance; Acts(11).ActMeanDistance];
    ObjectDistance = ObjectNumber.*ObjectMeanDistance;
    
    clear 'Acts' 'BodyPartsTraces';
end

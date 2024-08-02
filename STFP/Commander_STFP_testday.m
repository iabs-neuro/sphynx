%% paths
PathVideo = 'd:\STFP\Behavior\Video\';
PathDLC = 'd:\STFP\Behavior\_Tracks\';
PathPreset = 'd:\STFP\Behavior\Presets MAT\';

PathOut = 'd:\STFP\Behavior\Results\';

NameVideoAdd = '.m4v';
NameDLCAdd = '_traces.csv';
NamePresetAdd = '_Preset.mat';

%% STFP Social Test Day

StartVideo = [970 1130 1050 1020 600 820];
FileNames = {'STFP1_D6','STFP3_D6','STFP4_D3','STFP5_D3','STFP7_D3','STFP9_D6'};

%%
Freezing = zeros(1,length(FileNames)); %процент фризинга
AverageDurationFreezing = zeros(1,length(FileNames)); % средняя продолжительность фризинга в секундах
NumRears = zeros(1,length(FileNames)); % количество стоек (завышено, осторожно)
PercentCornersWallsCenter = zeros(3,length(FileNames)); %процент нахождения в зонах углов и стен (актуально только для открытого поля)
NumCenterEntries = zeros(1,length(FileNames)); % количество выходов в центр (из углов и стен) (актуально только для открытого поля)
Distanse = zeros(1,length(FileNames)); %общая пройденная дистанция в метрах
NumRestLocomotion = zeros(2,length(FileNames)); % количество остановок и побежек 
PercentRestLocomotion = zeros(2,length(FileNames)); % процент по времени на остановки и побежки
AverageDurationRestLocomotion = zeros(2,length(FileNames)); % средняя продолжительность остановок и побежек по времени
DistanceCenterWalls = zeros(2,length(FileNames)); % пройденная дистанция в центре и у стен (актуально только для открытого поля)
DistanceLocomotion = zeros(1, length(FileNames)); % средний пройденный путь на одну побежку в метрах
%%
for file = 2:length(FileNames)
    
    FilenameVideo = sprintf('%s%s',FileNames{file},NameVideoAdd);
    FilenameDLC = sprintf('%s%s',FileNames{file},NameDLCAdd);
    FilenamePreset = sprintf('%s%s',FileNames{file},NamePresetAdd);
    
    fprintf('Processing of %s mouse\n', FileNames{file})
    
    [Acts, BodyPartsTraces] = BehaviorAnalyzer(StartVideo(file), PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut,1, 0, PathPreset, FilenamePreset);
    Freezing(file) = Acts(4).ActPercent;
    AverageDurationFreezing(file) = Acts(4).ActMeanTime;
    NumRears(file) = Acts(5).ActNumber;
    PercentCornersWallsCenter(1:3,file) = [Acts(7).ActPercent; Acts(8).ActPercent; Acts(9).ActPercent];
    NumCenterEntries(file) = Acts(9).ActNumber;
    Distanse(file) = BodyPartsTraces(11).AverageDistance;
    NumRestLocomotion(1:2,file) = [Acts(1).ActNumber; Acts(3).ActNumber];
    PercentRestLocomotion(1:2,file) = [Acts(1).ActPercent; Acts(3).ActPercent];
    AverageDurationRestLocomotion(1:2,file) = [Acts(1).ActMeanTime; Acts(3).ActMeanTime];
%     DistanceCenterWalls(1:2,file) = [Acts(9).Distance; Acts(8).Distance];
%     DistanceLocomotion(file) = Acts(3).ActMeanDistance;
    clear 'Acts' 'BodyPartsTraces';
end

    
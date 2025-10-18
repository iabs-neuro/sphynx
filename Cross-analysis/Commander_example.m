%% paths
PathVideo = 'G:\Cre-mice_2023\OF\Day1\';
PathDLC = 'G:\Cre-mice_2023\OF\Day1\';
PathPreset = 'g:\Cre-mice_2023\OF\Day1\';

PathPresetAdd = '21-BiRSC-Cre_zones\';

PathOut = 'g:\Cre-mice_2023\OF\Day1\Behavior\';

NameVideoAdd = '-BiRSC-Cre.avi';
NameDLCAdd = '-BiRSC-CreDLC_resnet50_Cre-mice_Open fieldApr11shuffle1_500000.csv';
NamePresetAdd = '21-BiRSC-Cre_Preset.mat';

%% day1

FileNames = {'9','11','14','17','20'};

%%
Freezing = zeros(1,length(FileNames)); %процент фризинга
AverageDurationFreezing = zeros(1,length(FileNames)); % средняя продолжительность фризинга в секундах
NumRears = zeros(1,length(FileNames)); % количество стоек
PercentCornersWallsCenter = zeros(3,length(FileNames)); %процент нахождения в зонах углов и стен
NumCenterEntries = zeros(1,length(FileNames)); % количество выходов в центр (из углов и стен)
Distanse = zeros(1,length(FileNames)); %общая пройденная дистанция в метрах
NumRestLocomotion = zeros(2,length(FileNames)); % количество остановок и побежек 
PercentRestLocomotion = zeros(2,length(FileNames)); % процент по времени на остановки и побежки
AverageDurationRestLocomotion = zeros(2,length(FileNames)); % средняя продолжительность остановок и побежек по времени
DistanceCenterWalls = zeros(2,length(FileNames)); % пройденная дистанция в центре и у стен
DistanceLocomotion = zeros(1, length(FileNames)); % средний пройденный путь на одну побежку в метрах
%%
for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s%s',FileNames{file},NameVideoAdd);
    FilenameDLC = sprintf('%s%s',FileNames{file},NameDLCAdd);
    PathPresetThis = sprintf('%s%s',PathPreset,PathPresetAdd);
    FilenamePreset = sprintf('%s',NamePresetAdd);
    
    fprintf('Processing of %s mouse\n', FileNames{file})
    
    [Acts, BodyPartsTraces] = BehaviorAnalyzer(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut,1, 0, PathPresetThis, FilenamePreset);
    Freezing(file) = Acts(4).ActPercent;
    AverageDurationFreezing(file) = Acts(4).ActMeanTime;
    NumRears(file) = Acts(5).ActNumber;
    PercentCornersWallsCenter(1:3,file) = [Acts(7).ActPercent; Acts(8).ActPercent; Acts(9).ActPercent];
    NumCenterEntries(file) = Acts(9).ActNumber;
    Distanse(file) = BodyPartsTraces(11).AverageDistance;
    NumRestLocomotion(1:2,file) = [Acts(1).ActNumber; Acts(3).ActNumber];
    PercentRestLocomotion(1:2,file) = [Acts(1).ActPercent; Acts(3).ActPercent];
    AverageDurationRestLocomotion(1:2,file) = [Acts(1).ActMeanTime; Acts(3).ActMeanTime];
    DistanceCenterWalls(1:2,file) = [Acts(9).Distance; Acts(8).Distance];
    DistanceLocomotion(file) = Acts(3).ActMeanDistance;
    clear 'Acts' 'BodyPartsTraces';
end

    
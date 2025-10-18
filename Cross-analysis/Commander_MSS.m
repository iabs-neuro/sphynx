%% paths and filenames
ExpID = 'MSS';

PathVideo = sprintf('w:\\Projects\\%s\\BehaviorData\\2_Combined\\',ExpID);
PathDLC = sprintf('w:\\Projects\\%s\\BehaviorData\\3_DLC\\',ExpID);
PathPreset = sprintf('w:\\Projects\\%s\\BehaviorData\\4_Presets\\',ExpID);
PathMat = sprintf('w:\\Projects\\%s\\BehaviorData\\7_Matfiles\\',ExpID);

PathOut = sprintf('w:\\Projects\\%s\\BehaviorData\\5_Behavior\\',ExpID);

FileNames = {
    'F08_1D_1T' 'F10_1D_1T' 'F11_1D_1T' 'F14_1D_1T' 'F26_1D_1T' 'F28_1D_1T' 'F31_1D_1T' 'F35_1D_1T' 'F36_1D_1T' 'F37_1D_1T' 'H31_1D_1T' 'D01_1D_1T', ...
    'F08_2D_1T' 'F10_2D_1T' 'F11_2D_1T' 'F14_2D_1T' 'F26_2D_1T' 'F28_2D_1T' 'F31_2D_1T' 'F35_2D_1T' 'F36_2D_1T' 'F37_2D_1T' 'H31_2D_1T' 'D01_2D_1T', ...
    'F01_1D_1T' 'F01_2D_1T' 'F01_3D_1T' 'F01_4D_1T' 'F01_5D_1T' 'F01_6D_1T', ...
    'F04_1D_1T' 'F04_2D_1T' 'F04_3D_1T' 'F04_4D_1T' 'F04_5D_1T' 'F04_6D_1T', ...
    'F09_1D_1T' 'F09_2D_1T' 'F09_3D_1T' 'F09_4D_1T' 'F09_5D_1T' 'F09_6D_1T', ...
    'F12_1D_1T' 'F12_2D_1T' 'F12_3D_1T' 'F12_4D_1T' 'F12_5D_1T' 'F12_6D_1T', ...
    'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T' 'F29_6D_1T', ...
    'F38_1D_1T' 'F38_2D_1T' 'F38_3D_1T' 'F38_4D_1T' 'F38_5D_1T' 'F38_6D_1T', ...
    'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T' 'F40_6D_1T', ...
    'F48_1D_1T' 'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T' 'F48_6D_1T', ...
    'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T' 'F52_6D_1T', ...
    'H27_1D_1T' 'H27_2D_1T' 'H27_3D_1T' 'H27_4D_1T' 'H27_5D_1T' 'H27_6D_1T', ...
    'H32_1D_1T' 'H32_2D_1T' 'H32_3D_1T' 'H32_4D_1T' 'H32_5D_1T' 'H32_6D_1T', ...
    'F05_1D_1T' 'F05_1D_2T' 'F05_1D_3T' 'F05_1D_4T' 'F05_1D_5T' 'F05_2D_1T', ...
    'F06_1D_1T' 'F06_1D_2T' 'F06_1D_3T' 'F06_1D_4T' 'F06_1D_5T' 'F06_2D_1T', ...
    'F15_1D_1T' 'F15_1D_2T' 'F15_1D_3T' 'F15_1D_4T' 'F15_1D_5T' 'F15_2D_1T', ...
    'F20_1D_1T' 'F20_1D_2T' 'F20_1D_3T' 'F20_1D_4T' 'F20_1D_5T' 'F20_2D_1T', ...
    'F30_1D_1T' 'F30_1D_2T' 'F30_1D_3T' 'F30_1D_4T' 'F30_1D_5T' 'F30_2D_1T', ...
    'F34_1D_1T' 'F34_1D_2T' 'F34_1D_3T' 'F34_1D_4T' 'F34_1D_5T' 'F34_2D_1T', ...
    'F43_1D_1T' 'F43_1D_2T' 'F43_1D_3T' 'F43_1D_4T' 'F43_1D_5T' 'F43_2D_1T', ...
    'F53_1D_1T' 'F53_1D_2T' 'F53_1D_3T' 'F53_1D_4T' 'F53_1D_5T' 'F53_2D_1T', ...
    'F54_1D_1T' 'F54_1D_2T' 'F54_1D_3T' 'F54_1D_4T' 'F54_1D_5T' 'F54_2D_1T', ...
    'H26_1D_1T' 'H26_1D_2T' 'H26_1D_3T' 'H26_1D_4T' 'H26_1D_5T' 'H26_2D_1T', ...
    'H33_1D_1T' 'H33_1D_2T' 'H33_1D_3T' 'H33_1D_4T' 'H33_1D_5T' 'H33_2D_1T'
    };

MouseGroup = {
    'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single', ...
    'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed', ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed'
    };

FilesNumber = length(FileNames);

%% variables initiation

FreezingPercent = zeros(1,FilesNumber)';
FreezingNumber = zeros(1,FilesNumber)';
FreezingMeanTime = zeros(1,FilesNumber)';

RearsPercent = zeros(1,FilesNumber)';
RearsNumber = zeros(1,FilesNumber)';
RearsMeanTime = zeros(1,FilesNumber)';

CornersWallsCenterPercent = zeros(3,FilesNumber)';
CornersWallsCenterNumber = zeros(3,FilesNumber)';
CornersWallsCenterMeanTime = zeros(3,FilesNumber)';
CornersWallsCenterDistance = zeros(3,FilesNumber)';
CornersWallsCenterMeanDistance = zeros(3,FilesNumber)';
CornersWallsCenterVelocity = zeros(3,FilesNumber)';

RestOtherLocomotionPercent = zeros(3,FilesNumber)';
RestOtherLocomotionNumber = zeros(3,FilesNumber)';
RestOtherLocomotionMeanTime = zeros(3,FilesNumber)';
RestOtherLocomotionDistance = zeros(3,FilesNumber)';
RestOtherLocomotionMeanDistance = zeros(3,FilesNumber)';
RestOtherLocomotionVelocity = zeros(3,FilesNumber)';

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
AllActs = struct();

%% main part

for file = 142:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    switch MouseGroup{file}
        case 'Single'
            EndTime = 0;
        case 'Spaced'
            
            if FileNames{file} == "H27_1D_1T"
                EndTime = 6660;
            else
                EndTime = 3600;
            end
            
            if FileNames{file}(5) == "6"
                EndTime = 0;
            end
        case 'Massed'
            EndTime = 0;
    end
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file})
    
    [Acts, BodyPartsTraces, Point] = BehaviorAnalyzerMSS(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, EndTime, PathPreset, FilenamePreset);

%     load(sprintf('%s\\%s_%s_WorkSpace.mat',PathMat, ExpID, FileNames{file}), 'Acts', 'Point', 'BodyPartsTraces');
    
%     % add velocity into Acts
%     for line = 1:size(Acts,2)
%         Acts(line).ActVelocity = Acts(line).Distance/(Acts(line).ActMeanTime*Acts(line).ActNumber)*100;
%     end

    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs.(table_name) = Acts;
    
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
    
    Distance(file) = BodyPartsTraces(Point.Center).AverageDistance;
    Velocity(file) = BodyPartsTraces(Point.Center).AverageSpeed;
    
    clear 'Acts' 'BodyPartsTraces';
end

%% Create structure of outputs data

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
mouse_id = sprintf('%s_%s', ExpID,  FileNames{1});
acts = {AllActs.(mouse_id).ActName};

% создание структуры таблицы:
% мыши и группы - два первых столбца
% сессии - последующие столбцы, повторяются (колво метрик)*(кол-во актов) раз

mice = {
    'F08' 'F10' 'F11' 'F14' 'F26' 'F28' 'F31' 'F35' 'F36' 'F37' 'H31' 'D01' ...
    'F01' 'F04' 'F09' 'F12' 'F29' 'F38' 'F40' 'F48' 'F52' 'H27' 'H32' ...
    'F05' 'F06' 'F15' 'F20' 'F30' 'F34' 'F43' 'F53' 'F54' 'H26' 'H33'
};

groups = {
    'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed'
    };

lines = {
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6'
};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), lines(:), 'VariableNames', {'mouse', 'group', 'line'});

% сессии в конкретном эксперименте
session_id = {'1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T' '2D_1T' '3D_1T' '4D_1T' '5D_1T' '6D_1T'};

% необходимые метрики
names_metric = {'ActNumber' 'ActPercent' 'ActMeanTime' 'Distance' 'ActMeanDistance' 'ActVelocity'};

%% Create MAIN Big Ugly Table

% добавить все метрики актов
for act = 1:length(acts)
    for metric = 1:length(names_metric)
        for session = 1:length(session_id)
            num_volume = (act-1)*length(names_metric)*length(session_id)+(metric-1)*length(session_id)+session;
            UglyTable.Name{num_volume} = [acts{act} '_' names_metric{metric} '_' session_id{session}];
            for mouse = 1:length(mice)
                session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
                if isfield(AllActs, session_name)
                    UglyTable.Data(mouse, num_volume) = AllActs.(session_name)(act).(names_metric{metric});
                else
                    UglyTable.Data(mouse, num_volume) = NaN;
                end
            end
        end
    end
end

% добавить дситанцию 
column_count = length(UglyTable.Name);
for session = 1:length(session_id)
    UglyTable.Name{column_count+1} = ['distance_' session_id{session}];
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            UglyTable.Data(mouse, column_count+1) = Distance(ismember(FileNames, this_name));
        else
            UglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% добавить скорость
column_count = length(UglyTable.Name);
for session = 1:length(session_id)
    UglyTable.Name{column_count+1} = ['velocity_' session_id{session}];
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            UglyTable.Data(mouse, column_count+1) = Velocity(ismember(FileNames, this_name));
        else
            UglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% создание и сохранение итоговой таблицы
UglyTable.Table = array2table(UglyTable.Data, 'VariableNames', UglyTable.Name);
UglyTable.Table = [mice_info, UglyTable.Table];
writetable(UglyTable.Table, sprintf('%s\\%s_Behavior.csv',PathOut, ExpID));

%%  Create several cute tables

for act = 1:length(acts)
    
    for metric = 1:length(names_metric)
        for session = 1:length(session_id)
            num_volume = (metric-1)*length(session_id)+session;
            NotUglyTable.Name{num_volume} = [names_metric{metric} '_' session_id{session}];
            for mouse = 1:length(mice)
                session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
                if isfield(AllActs, session_name)
                    NotUglyTable.Data(mouse, num_volume) = AllActs.(session_name)(act).(names_metric{metric});
                else
                    NotUglyTable.Data(mouse, num_volume) = NaN;
                end
            end
        end
    end
    
    % создание и сохранение итоговых таблиц
    NotUglyTable.Table = array2table(NotUglyTable.Data, 'VariableNames', NotUglyTable.Name);
    NotUglyTable.Table = [mice_info, NotUglyTable.Table];
    writetable(NotUglyTable.Table, sprintf('%s\\%s_Behavior_%s.csv',PathOut, ExpID, acts{act}));
    clear 'NotUglyTable';
end

% таблица дистанции
column_count = 0;
for session = 1:length(session_id)
    NotUglyTable.Name{column_count+1} = session_id{session};
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            NotUglyTable.Data(mouse, column_count+1) = Distance(ismember(FileNames, this_name));
        else
            NotUglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end
NotUglyTable.Table = array2table(NotUglyTable.Data, 'VariableNames', NotUglyTable.Name);
NotUglyTable.Table = [mice_info, NotUglyTable.Table];
writetable(NotUglyTable.Table, sprintf('%s\\%s_Behavior_distance.csv',PathOut, ExpID));
clear 'NotUglyTable';

% таблица скорости
column_count = 0;
for session = 1:length(session_id)
    NotUglyTable.Name{column_count+1} = session_id{session};
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            NotUglyTable.Data(mouse, column_count+1) = Velocity(ismember(FileNames, this_name));
        else
            NotUglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end
NotUglyTable.Table = array2table(NotUglyTable.Data, 'VariableNames', NotUglyTable.Name);
NotUglyTable.Table = [mice_info, NotUglyTable.Table];
writetable(NotUglyTable.Table, sprintf('%s\\%s_Behavior_velocity.csv',PathOut, ExpID));
clear 'NotUglyTable';

% сохранить мат-файл всех поведенческих данных
save(sprintf('%s\\%s_Behavior.mat',PathOut, ExpID));


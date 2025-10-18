%% paths and filenames
ExpID = 'HOS';

PathVideo = sprintf('w:\\Projects\\%s\\BehaviorData\\2_Combined\\',ExpID);
PathDLC = sprintf('w:\\Projects\\%s\\BehaviorData\\3_DLC\\',ExpID);
PathPreset = sprintf('w:\\Projects\\%s\\BehaviorData\\4_Presets\\',ExpID);
PathMat = sprintf('w:\\Projects\\%s\\BehaviorData\\7_Matfiles\\',ExpID);

PathOut = sprintf('w:\\Projects\\%s\\BehaviorData\\5_Behavior\\',ExpID);

FileNames = {
'D01_1D_1T' 'D01_2D_1T' 'D01_3D_1T' 'D01_4D_1T' 'D01_5D_1T' ...
'D03_1D_1T' 'D03_2D_1T' 'D03_3D_1T' 'D03_4D_1T' 'D03_5D_1T' ...
'D04_1D_1T' 'D04_1D_2T' 'D04_1D_3T' 'D04_1D_4T' 'D04_1D_5T' ...
'D07_1D_1T' 'D07_2D_1T' 'D07_3D_1T' 'D07_4D_1T' 'D07_5D_1T' ...
'D08_1D_1T' 'D08_2D_1T' 'D08_3D_1T' 'D08_4D_1T' 'D08_5D_1T' ...
'D11_1D_1T' 'D11_1D_2T' 'D11_1D_3T' 'D11_1D_4T' 'D11_1D_5T' ...
'D14_1D_1T' 'D14_2D_1T' 'D14_3D_1T' 'D14_4D_1T' 'D14_5D_1T' ...
'D17_1D_1T' 'D17_2D_1T' 'D17_3D_1T' 'D17_4D_1T' 'D17_5D_1T'
    };

MouseGroup = {
'Equal5d' 'Equal5d' 'Equal5d' 'Equal5d' 'Equal5d', ...
'Diverse5d' 'Diverse5d' 'Diverse5d' 'Diverse5d' 'Diverse5d', ...
'Equal1D' 'Equal1D' 'Equal1D' 'Equal1D' 'Equal1D', ...
'Diverse5d' 'Diverse5d' 'Diverse5d' 'Diverse5d' 'Diverse5d', ...
'Equal5d' 'Equal5d' 'Equal5d' 'Equal5d' 'Equal5d', ...
'Equal1D' 'Equal1D' 'Equal1D' 'Equal1D' 'Equal1D', ...
'Equal5d' 'Equal5d' 'Equal5d' 'Equal5d' 'Equal5d', ...
'Diverse5d' 'Diverse5d' 'Diverse5d' 'Diverse5d' 'Diverse5d'
    };

FilesNumber = length(FileNames);

%% variables initiation

FreezingPercent = zeros(1,FilesNumber)';
FreezingNumber = zeros(1,FilesNumber)';
FreezingMeanTime = zeros(1,FilesNumber)';

RearsPercent = zeros(1,FilesNumber)';
RearsNumber = zeros(1,FilesNumber)';
RearsMeanTime = zeros(1,FilesNumber)';

WallsMiddleCenterPercent = zeros(3,FilesNumber)';
WallsMiddleCenterNumber = zeros(3,FilesNumber)';
WallsMiddleCenterMeanTime = zeros(3,FilesNumber)';
WallsMiddleCenterDistance = zeros(3,FilesNumber)';
WallsMiddleCenterMeanDistance = zeros(3,FilesNumber)';
WallsMiddleCenterVelocity = zeros(3,FilesNumber)';

RestOtherLocomotionPercent = zeros(3,FilesNumber)';
RestOtherLocomotionNumber = zeros(3,FilesNumber)';
RestOtherLocomotionMeanTime = zeros(3,FilesNumber)';
RestOtherLocomotionDistance = zeros(3,FilesNumber)';
RestOtherLocomotionMeanDistance = zeros(3,FilesNumber)';
RestOtherLocomotionVelocity = zeros(3,FilesNumber)';

Distance = zeros(1,FilesNumber)';
Velocity = zeros(1,FilesNumber)';

% task-specific
ObjectNumber = zeros(4,length(FileNames))';
ObjectPercent = zeros(4,length(FileNames))';
ObjectMeanTime = zeros(4,length(FileNames))';
ObjectMeanDistance = zeros(4,length(FileNames))';
ObjectDistance = zeros(4,length(FileNames))';
ObjectVelocity = zeros(4,length(FileNames))';

EntryNumber = zeros(8,length(FileNames))';
EntryPercent = zeros(8,length(FileNames))';
EntryMeanTime = zeros(8,length(FileNames))';
EntryMeanDistance = zeros(8,length(FileNames))';
EntryDistance = zeros(8,length(FileNames))';
EntryVelocity = zeros(8,length(FileNames))';

%% main part
AllActs = struct();
for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
   
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file})
    
%     [Acts, BodyPartsTraces, Point] = BehaviorAnalyzerHOS(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    load (sprintf('%sHOS_%s_WorkSpace.mat',PathMat,FileNames{file}), 'Acts');
    
    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs.(table_name) = Acts;
    
% %     variables calculaion
%     FreezingPercent(file) = Acts(4).ActPercent;
%     FreezingNumber(file) = Acts(4).ActNumber;
%     FreezingMeanTime(file) = Acts(4).ActMeanTime;
%     
%     RearsPercent(file) = Acts(5).ActPercent;
%     RearsNumber(file) = Acts(5).ActNumber;
%     RearsMeanTime(file) = Acts(5).ActMeanTime;
%     
%     WallsMiddleCenterPercent(file,1:3) = [Acts(6).ActPercent; Acts(7).ActPercent; Acts(8).ActPercent];
%     WallsMiddleCenterNumber(file,1:3) = [Acts(6).ActNumber; Acts(7).ActNumber; Acts(8).ActNumber];
%     WallsMiddleCenterMeanTime(file,1:3) = [Acts(6).ActMeanTime; Acts(7).ActMeanTime; Acts(8).ActMeanTime];
%     WallsMiddleCenterDistance(file,1:3) = [Acts(6).Distance; Acts(7).Distance; Acts(8).Distance];
%     WallsMiddleCenterMeanDistance(file,1:3) = [Acts(6).ActMeanDistance; Acts(7).ActMeanDistance; Acts(8).ActMeanDistance];
%     WallsMiddleCenterVelocity(file,1:3) = WallsMiddleCenterDistance(file,1:3)./(WallsMiddleCenterMeanTime(file,1:3).*WallsMiddleCenterNumber(file,1:3))*100;    
%     
%     RestOtherLocomotionPercent(file,1:3) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
%     RestOtherLocomotionNumber(file,1:3) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
%     RestOtherLocomotionMeanTime(file,1:3) = [Acts(1).ActMeanTime; Acts(2).ActMeanTime; Acts(3).ActMeanTime];
%     RestOtherLocomotionDistance(file,1:3) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
%     RestOtherLocomotionMeanDistance(file,1:3) = [Acts(1).ActMeanDistance; Acts(2).ActMeanDistance; Acts(3).ActMeanDistance];
%     RestOtherLocomotionVelocity(file,1:3) = RestOtherLocomotionDistance(file,1:3)./(RestOtherLocomotionMeanTime(file,1:3).*RestOtherLocomotionNumber(file,1:3))*100;
%     
%     Distance(file) = BodyPartsTraces(Point.Center).AverageDistance;
%     Velocity(file) = BodyPartsTraces(Point.Center).AverageSpeed;
%     
%     ObjectNumber(file,1:4) = [Acts(9).ActNumber; Acts(10).ActNumber; Acts(11).ActNumber;Acts(20).ActNumber];
%     ObjectPercent(file,1:4) = [Acts(9).ActPercent; Acts(10).ActPercent; Acts(11).ActPercent;Acts(20).ActPercent];
%     ObjectMeanTime(file,1:4) = [Acts(9).ActMeanTime; Acts(10).ActMeanTime; Acts(11).ActMeanTime;Acts(20).ActMeanTime];
%     ObjectMeanDistance(file,1:4) = [Acts(9).ActMeanDistance; Acts(10).ActMeanDistance; Acts(11).ActMeanDistance;Acts(20).ActMeanDistance];
%     ObjectDistance(file,1:4) = [Acts(9).Distance; Acts(10).Distance; Acts(11).Distance;Acts(20).Distance];
%     ObjectVelocity(file,1:4) = ObjectDistance(file,1:4)./(ObjectMeanTime(file,1:4).*ObjectNumber(file,1:4))*100;
%         
%     EntryNumber(file,1:8) =  [Acts(12).ActNumber; Acts(13).ActNumber; Acts(14).ActNumber; Acts(15).ActNumber ;Acts(16).ActNumber; Acts(17).ActNumber; Acts(18).ActNumber;Acts(19).ActNumber];
%     EntryPercent(file,1:8) = [Acts(12).ActPercent; Acts(13).ActPercent; Acts(14).ActPercent; Acts(15).ActPercent; Acts(16).ActPercent; Acts(17).ActPercent; Acts(18).ActPercent;Acts(19).ActPercent];
%     EntryMeanTime(file,1:8) = [Acts(12).ActMeanTime; Acts(13).ActMeanTime; Acts(14).ActMeanTime; Acts(15).ActMeanTime; Acts(16).ActMeanTime; Acts(17).ActMeanTime; Acts(18).ActMeanTime;Acts(19).ActMeanTime];
%     EntryMeanDistance(file,1:8) = [Acts(12).ActMeanDistance; Acts(13).ActMeanDistance; Acts(14).ActMeanDistance;Acts(15).ActMeanDistance; Acts(16).ActMeanDistance; Acts(17).ActMeanDistance; Acts(18).ActMeanDistance; Acts(19).ActMeanDistance];
%     EntryDistance(file,1:8) = [Acts(12).Distance; Acts(13).Distance; Acts(14).Distance; Acts(15).Distance; Acts(16).Distance; Acts(17).Distance; Acts(18).Distance; Acts(19).Distance];
%     EntryVelocity(file,1:8) = EntryDistance(file,1:8)./(EntryMeanTime(file,1:8).*EntryNumber(file,1:8))*100;
   
    
    clear 'Acts' 'BodyPartsTraces';
end

%% Create ugly table (MAIN - 1 Table)

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
mouse_id = sprintf('%s_%s', ExpID,  FileNames{1});
acts = {AllActs.(mouse_id).ActName};

% создание структуры таблицы:
% мыши и группы - два первых столбца
% сессии - последующие столбцы, повторяются (колво метрик)*(кол-во актов) раз

mouses = {'D01', 'D08', 'D14', 'D03', 'D07', 'D17', 'D04', 'D11'};
groups = {'Equal5d' 'Equal5d' 'Equal5d' 'Diverse5d' 'Diverse5d' 'Diverse5d' 'Equal1d' 'Equal1d'};

% сессии в конкретном эксперименте
session_id = {'1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T' '2D_1T' '3D_1T' '4D_1T' '5D_1T'};

% необходимые метрики
names_metric = {'ActNumber' 'ActPercent' 'ActMeanTime' 'Distance' 'ActMeanDistance' 'ActVelocity'};

%% Create MAIN - 1 Table

for act = 1:length(acts)
    for metric = 1:length(names_metric)
        for session = 1:length(session_id)
            num_volume = (act-1)*length(names_metric)*length(session_id)+(metric-1)*length(session_id)+session;
            UglyTable.Name{num_volume} = [acts{act} '_' names_metric{metric} '_' session_id{session}];
            for mouse = 1:length(mouses)
                session_name = [ExpID '_' mouses{mouse} '_' session_id{session}];
                if isfield(AllActs, session_name)
                    UglyTable.Data(mouse, num_volume) = AllActs.(session_name)(act).(names_metric{metric});
                else
                    UglyTable.Data(mouse, num_volume) = NaN;
                end
            end
        end
    end
end

% добавить дситанцию и скорость
column_count = length(UglyTable.Name);
for session = 1:length(session_id)
    UglyTable.Name{column_count+1} = ['distance_' session_id{session}];
    for mouse = 1:length(mouses)
        this_name = [mouses{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mouses{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            UglyTable.Data(mouse, column_count+1) = Distance(ismember(FileNames, this_name));
        else
            UglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

column_count = length(UglyTable.Name);
for session = 1:length(session_id)
    UglyTable.Name{column_count+1} = ['velocity_' session_id{session}];
    for mouse = 1:length(mouses)
        this_name = [mouses{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mouses{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            UglyTable.Data(mouse, column_count+1) = Velocity(ismember(FileNames, this_name));
        else
            UglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% создание итоговой таблицы
UglyTable.Table = array2table(UglyTable.Data, 'VariableNames', UglyTable.Name);

% Создание столбцов с id мышей и группой в начале таблицы
newColumns = table(mouses(:), groups(:), 'VariableNames', {'mouse', 'group'});
UglyTable.Table = [newColumns, UglyTable.Table];

writetable(UglyTable.Table, sprintf('%s\\%s_Behavior.csv',PathOut, ExpID));


%%  Создать несколько красивых таблиц, пофично

newColumns = table(mouses(:), groups(:), 'VariableNames', {'mouse', 'group'});

for act = 1:length(acts)
    
    for metric = 1:length(names_metric)
        for session = 1:length(session_id)
            num_volume = (metric-1)*length(session_id)+session;
            NotUglyTable.Name{num_volume} = [names_metric{metric} '_' session_id{session}];
            for mouse = 1:length(mouses)
                session_name = [ExpID '_' mouses{mouse} '_' session_id{session}];
                if isfield(AllActs, session_name)
                    NotUglyTable.Data(mouse, num_volume) = AllActs.(session_name)(act).(names_metric{metric});
                else
                    NotUglyTable.Data(mouse, num_volume) = NaN;
                end
            end
        end
    end
    
    % создание итоговой таблицы
    NotUglyTable.Table = array2table(NotUglyTable.Data, 'VariableNames', NotUglyTable.Name);
    NotUglyTable.Table = [newColumns, NotUglyTable.Table];
    writetable(NotUglyTable.Table, sprintf('%s\\%s_Behavior_%s.csv',PathOut, ExpID, acts{act}));
    clear 'NotUglyTable';
end

% таблица дистанции
column_count = 0;
for session = 1:length(session_id)
    NotUglyTable.Name{column_count+1} = session_id{session};
    for mouse = 1:length(mouses)
        this_name = [mouses{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mouses{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            NotUglyTable.Data(mouse, column_count+1) = Distance(ismember(FileNames, this_name));
        else
            NotUglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end
NotUglyTable.Table = array2table(NotUglyTable.Data, 'VariableNames', NotUglyTable.Name);
NotUglyTable.Table = [newColumns, NotUglyTable.Table];
writetable(NotUglyTable.Table, sprintf('%s\\%s_Behavior_distance.csv',PathOut, ExpID));
clear 'NotUglyTable';

% таблица скорости
column_count = 0;
for session = 1:length(session_id)
    NotUglyTable.Name{column_count+1} = session_id{session};
    for mouse = 1:length(mouses)
        this_name = [mouses{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mouses{mouse} '_' session_id{session}];
        if isfield(AllActs, session_name)
            NotUglyTable.Data(mouse, column_count+1) = Velocity(ismember(FileNames, this_name));
        else
            NotUglyTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end
NotUglyTable.Table = array2table(NotUglyTable.Data, 'VariableNames', NotUglyTable.Name);
NotUglyTable.Table = [newColumns, NotUglyTable.Table];
writetable(NotUglyTable.Table, sprintf('%s\\%s_Behavior_velocity.csv',PathOut, ExpID));
clear 'NotUglyTable';

save(sprintf('%s\\%s_Behavior.mat',PathOut, ExpID));

%% paths and filenames
ExpID = 'BOF';

ExpID1 = 'BOWL';

PathVideo = sprintf('e:\\Projects\\%s\\BehaviorData\\2_Combined\\',ExpID1);
PathDLC = sprintf('e:\\Projects\\%s\\BehaviorData\\4_DLC\\',ExpID1);
PathPreset = sprintf('e:\\Projects\\%s\\BehaviorData\\3_Preset\\',ExpID1);
PathMat = sprintf('e:\\Projects\\%s\\BehaviorData\\6_Behav_mat\\',ExpID1);

PathOut = sprintf('e:\Projects\%s\BehaviorData\5_Behavior\',ExpID1);

FileNames = {
    'D01_1D' 'D03_1D' 'D04_1D' 'D07_1D' 'D14_1D' 'D17_1D' 'F01_1D' 'F04_1D' 'F05_1D' 'F06_1D' ...
    'F07_1D' 'F08_1D' 'F09_1D' 'F11_1D' 'F14_1D' 'F15_1D' 'F26_1D' 'F28_1D' 'F29_1D' 'F30_1D' ...
    'F34_1D' 'F36_1D' 'F37_1D' 'F38_1D' 'F40_1D' 'F43_1D' 'F48_1D' 'F52_1D' 'F54_1D' ...
    'D01_2D' 'D03_2D' 'D04_2D' 'D07_2D' 'D14_2D' 'D17_2D' 'F01_2D' 'F04_2D' 'F05_2D' 'F06_2D' ...
    'F07_2D' 'F08_2D' 'F09_2D' 'F11_2D' 'F14_2D' 'F15_2D' 'F26_2D' 'F28_2D' 'F29_2D' 'F30_2D' ...
    'F34_2D' 'F36_2D' 'F37_2D' 'F38_2D' 'F40_2D' 'F43_2D' 'F48_2D' 'F52_2D' 'F54_2D' ...
    'D01_3D' 'D03_3D' 'D04_3D' 'D07_3D' 'D14_3D' 'D17_3D' 'F01_3D' 'F04_3D' 'F05_3D' 'F06_3D' ...
    'F07_3D' 'F08_3D' 'F09_3D' 'F11_3D' 'F14_3D' 'F15_3D' 'F26_3D' 'F28_3D' 'F29_3D'          ...
    'F34_3D' 'F36_3D' 'F37_3D' 'F38_3D' 'F40_3D' 'F43_3D' 'F48_3D' 'F52_3D' 'F54_3D' ...
    'D01_4D' 'D03_4D' 'D04_4D' 'D07_4D' 'D14_4D' 'D17_4D' 'F01_4D' 'F04_4D' 'F05_4D' 'F06_4D' ...
    'F07_4D' 'F08_4D' 'F09_4D' 'F11_4D' 'F14_4D' 'F15_4D' 'F26_4D' 'F28_4D' 'F29_4D' 'F30_4D' ...
    'F34_4D' 'F36_4D' 'F37_4D' 'F38_4D' 'F40_4D' 'F43_4D' 'F48_4D' 'F52_4D' 'F54_4D' ...
    'D01_5D' 'D03_5D' 'D04_5D' 'D07_5D' 'D14_5D' 'D17_5D' 'F01_5D' 'F04_5D' 'F05_5D' 'F06_5D' ...
    'F07_5D' 'F08_5D' 'F09_5D' 'F11_5D' 'F14_5D' 'F15_5D' 'F26_5D' 'F28_5D' 'F29_5D' 'F30_5D' ...
    'F34_5D' 'F36_5D' 'F37_5D' 'F38_5D' 'F40_5D' 'F43_5D' 'F48_5D' 'F52_5D' 'F54_5D' ...
    };

MouseGroup = {
    'bowl' 'control' 'bowl' 'control' 'bowl' 'control' 'bowl' 'bowl' 'control' 'control' ...
    'bowl' 'control' 'control' 'control' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'bowl' 'bowl' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'control' 'bowl' 'control' 'bowl' 'control' 'bowl' 'bowl' 'control' 'control' ...
    'bowl' 'control' 'control' 'control' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'bowl' 'bowl' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'control' 'bowl' 'control' 'bowl' 'control' 'bowl' 'bowl' 'control' 'control' ...
    'bowl' 'control' 'control' 'control' 'control' 'control' 'control' 'bowl' 'bowl' 	 ...
    'bowl' 'bowl' 'bowl' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'control' 'bowl' 'control' 'bowl' 'control' 'bowl' 'bowl' 'control' 'control' ...
    'bowl' 'control' 'control' 'control' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'bowl' 'bowl' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'control' 'bowl' 'control' 'bowl' 'control' 'bowl' 'bowl' 'control' 'control' ...
    'bowl' 'control' 'control' 'control' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'bowl' 'bowl' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    };

FilesNumber = length(FileNames);

%% variables initiation
% AllActs = struct();

%% main part

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
%     [~, ~, ~] = BehaviorAnalyzerBOWL(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);

    load(sprintf('%s\\%s_%s_WorkSpace.mat',PathMat, ExpID, FileNames{file}), 'Acts');
    

    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs.(table_name) = Acts;
    
    % variables calculaion    
    
    clear 'Acts'
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
    'D01' 'D03' 'D04' 'D07' 'D14' 'D17' 'F01' 'F04' 'F05' 'F06' ...
    'F07' 'F08' 'F09' 'F11' 'F14' 'F15' 'F26' 'F28' 'F29' 'F30' ...
    'F34' 'F36' 'F37' 'F38' 'F40' 'F43' 'F48' 'F52' 'F54' ...
};

groups = {
    'bowl' 'control' 'bowl' 'control' 'bowl' 'control' 'bowl' 'bowl' 'control' 'control' ...
    'bowl' 'control' 'control' 'control' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    'bowl' 'bowl' 'bowl' 'control' 'control' 'control' 'bowl' 'bowl' 'bowl' ...
    };

lines = {
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' '5xFAD' '5xFAD' '5xFAD' '5xFAD' ...
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
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


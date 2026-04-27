ExpID = '3DM';

PathVideo = sprintf('e:\\Projects\\%s\\BehaviorData\\3wave\\2_Combined\\',ExpID);
PathDLC = sprintf('e:\\Projects\\%s\\BehaviorData\\3wave\\3_DLC\\',ExpID);
PathPreset = sprintf('e:\\Projects\\%s\\BehaviorData\\3wave\\4_Preset\\',ExpID);
PathMat = sprintf('e:\\Projects\\%s\\BehaviorData\\3wave\\6_Behav_mat\\',ExpID);

PathOut = sprintf('e:\\Projects\\%s\\BehaviorData\\3wave\\5_Behavior\\',ExpID);

FileNames = {
'J03_1D' 'J03_2D' 'J03_3D' 'J03_4D' 'J03_5D' 'J03_6D' 'J03_7D' ...
'J09_1D' 'J09_2D' 'J09_3D' 'J09_4D' 'J09_5D' 'J09_6D' 'J09_7D' ...
'J10_1D' 'J10_2D' 'J10_3D' 'J10_4D' 'J10_5D' 'J10_6D' 'J10_7D' ...
'J17_1D' 'J17_2D' 'J17_3D' 'J17_4D' 'J17_5D' 'J17_6D' 'J17_7D' ...
'J20_1D' 'J20_2D' 'J20_3D' 'J20_4D' 'J20_5D' 'J20_6D' 'J20_7D' ...
'J53_1D' 'J53_2D' 'J53_3D' 'J53_4D' 'J53_5D' 'J53_6D' 'J53_7D' ...
'J54_1D' 'J54_2D' 'J54_3D' 'J54_4D' 'J54_5D' 'J54_6D' 'J54_7D' ...
'J55_1D' 'J55_2D' 'J55_3D' 'J55_4D' 'J55_5D' 'J55_6D' 'J55_7D' ...
    };

most_frequent = [
    2 2 2 2 3 2 2 ...
    2 2 2 15 4 4 3 ...
    2 2 3 2 3 3 2 ...
    2 2 2 6 2 2 2 ...
    2 2 2 2 23 2 29 ...
    2 10 2 2 3 3 6 ...
    2 2 2 3 2 2 2 ...
    2 2 3 2 3 2 3 ...
    ];

FilesNumber = length(FileNames);

mice = { 
'J03' 'J09' 'J10' 'J17' 'J20' 'J53' 'J54' 'J55'
    };

groups = {
'light' 'dark' 'light' 'dark' 'light' 'dark' 'light' 'dark'
    };

lines = {
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6'
};

%% main part, analyzing

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_Resnet101_3DMMar25shuffle3_snapshot_370.csv', ExpID, FileNames{file});
    FilenamePreset = '3DM_preset_main.mat';
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzer3DM(most_frequent(file), PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);

end

%% collect data

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), lines(:), 'VariableNames', {'mouse', 'group', 'line'});

% сессии в конкретном эксперименте
session_id = {'1D' '2D' '3D' '4D'};

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

%% collect data

for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'n_frames', 'Options');
    
    for line = 1:size(Acts,2)    
        Acts(line).ActDuration = round(Acts(line).ActPercent*n_frames/Options.FrameRate/100,2);
    end
    
    table_name = FileNames{file};   
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    
    Distance(file) = round(BodyPartsTraces(Point.Tailbase).AverageDistance*100);
    Velocity(file) = BodyPartsTraces(Point.Tailbase).AverageSpeed;
    
    clear 'Acts' 'BodyPartsTraces' 'Point'
end

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), lines(:), 'VariableNames', {'mouse', 'group', 'line'});

% сессии в конкретном эксперименте
session_id = {'1D' '2D' '3D' '4D' '5D' '6D' '7D'};

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

%% collect data

for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'n_frames', 'Options');
    
    for line = 1:size(Acts,2)    
        Acts(line).ActDuration = round(Acts(line).ActPercent*n_frames/Options.FrameRate/100,2);
    end
    
    table_name = FileNames{file};   
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    
    Distance(file) = round(BodyPartsTraces(Point.Tailbase).AverageDistance*100);
    Velocity(file) = BodyPartsTraces(Point.Tailbase).AverageSpeed;
    
    clear 'Acts' 'BodyPartsTraces' 'Point'
end

%% Create structure of outputs data

% структура всевозможных поведенческих актов
behavior_acts_struct = behavior_act_params();
behavior_acts = fieldnames(behavior_acts_struct);

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов не всегда одинаковый, например BOF)
numFiles = size(AllActs,2);
exp_acts = {};
for file = 1:numFiles
    this_acts = {AllActs(file).Acts.ActName};
    exp_acts = union(exp_acts, this_acts);
end

exp_acts = behavior_acts(ismember(behavior_acts, exp_acts));
%% Create Super-Duper-Yummy Table

% добавить все метрики актов
num_volume = 1;
for act = 1:length(exp_acts)    
    names_metric = behavior_acts_struct.(exp_acts{act});
    for metric = 1:length(names_metric)
        for session = 1:length(session_id)
            SuperTable.Name{num_volume} = [exp_acts{act} '_' char(names_metric(metric)) '_' session_id{session}];
            SuperTable.ActID{num_volume} = exp_acts{act};
            SuperTable.TrialID{num_volume} = session_id{session};
            SuperTable.MetricID{num_volume} = char(names_metric(metric));
            for mouse = 1:length(mice)
                session_name = [mice{mouse} '_' session_id{session}];
                session_idx = find(strcmp({AllActs.SessionName}, session_name));
                if any(strcmp({AllActs.SessionName}, session_name)) && any(strcmp(exp_acts{act}, {AllActs(strcmp({AllActs.SessionName}, session_name)).Acts.ActName}))
                    act_idx = find(strcmp(exp_acts{act}, {AllActs(strcmp({AllActs.SessionName}, session_name)).Acts.ActName}));
                    SuperTable.Data(mouse, num_volume) = AllActs(session_idx).Acts(act_idx).(names_metric{metric});
                else
                    SuperTable.Data(mouse, num_volume) = NaN;
                end
            end
            num_volume = num_volume + 1;
        end
    end
end
SuperTable.MetricID = strrep(SuperTable.MetricID, 'ActPercent', 'Percent');
SuperTable.MetricID = strrep(SuperTable.MetricID, 'ActNumber', 'Count');
SuperTable.MetricID = strrep(SuperTable.MetricID, 'ActMeanTime', 'MeanTime');
SuperTable.MetricID = strrep(SuperTable.MetricID, 'ActDuration', 'Duration');

% добавить дистанцию
column_count = length(SuperTable.Name);
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['distance_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'distance';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 'cm';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Distance(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% добавить скорость
column_count = length(SuperTable.Name);
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['velocity_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'velocity';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 'cm/s';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Velocity(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

%% сохрание таблицы целиком

% SuperTable.Data(isnan(SuperTable.Data)) = 0;

% создание и сохранение итоговой таблицы
SuperTable.Table = array2table(SuperTable.Data, 'VariableNames', SuperTable.Name);
SuperTable.Table = [mice_info, SuperTable.Table];

% сортировка по группе
SuperTable.Table = sortrows(SuperTable.Table, 'line');
SuperTable.Table = sortrows(SuperTable.Table, 'group');

writetable(SuperTable.Table, sprintf('%s\\%s_Behavior.csv',PathOut, ExpID));

%% %%%%%%%% составление супер-четкой таблицы %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% сохранение типа "1 лист = 1 сессия"

for session = 1:length(session_id)
    
    session_idx = find(strcmp(SuperTable.TrialID, session_id{session}));
    this_session_table_data = SuperTable.Data(:,session_idx);
    
    % сортировка по группе
    [mice_info_sorted, Idx] = sortrows(mice_info, 'group');
    
    % Преобразуем данные в ячеечный массив для объединения с заголовками
    data_cell = num2cell(this_session_table_data(Idx,:));
    
    % Объединяем заголовки и данные в один массив
    full_table = [ ...
        [cell(1, size(mice_info,2)) SuperTable.ActID(:,session_idx)]; ...
        [cell(1, size(mice_info,2)) SuperTable.TrialID(:,session_idx)]; ...
        [mice_info.Properties.VariableNames SuperTable.MetricID(:,session_idx)]; ...
        [table2cell(mice_info_sorted) data_cell] ...
        ];    
    
    writecell(full_table, sprintf('%s\\%s_Behavior_sorted_session.xlsx',PathOut, ExpID), 'Sheet', sprintf('%s', session_id{session}));
end

% вся таблица в последний лист
[mice_info_sorted, Idx] = sortrows(mice_info, 'group');
data_cell = num2cell(SuperTable.Data(Idx,:));

MegaFullTable = [ ...
    [cell(1, size(mice_info,2)) SuperTable.ActID]; ...
    [cell(1, size(mice_info,2)) SuperTable.TrialID]; ...
    [mice_info.Properties.VariableNames SuperTable.MetricID]; ...
    [table2cell(mice_info_sorted) data_cell] ...
    ];

writecell(MegaFullTable, sprintf('%s\\%s_Behavior_sorted_session.xlsx',PathOut, ExpID), 'Sheet', 'All');
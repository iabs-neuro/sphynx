%% paths and filenames

ExpID = 'BOF';

PathMat = sprintf('w:\\Projects\\%s\\BehaviorData\\6_MAT\\', ExpID);
PathOut = sprintf('w:\\Projects\\%s\\BehaviorData\\', ExpID);

FileNames = {
    'H02_1T','H03_1T','H04_1T','H06_1T','H07_1T','H10_1T','H11_1T','H12_1T','H13_1T','H14_1T','H15_1T','H16_1T','H17_1T','H19_1T','H22_1T','H26_1T','H27_1T','H31_1T','H32_1T','H33_1T','H39_1T',...
    'H02_2T','H03_2T','H04_2T','H06_2T','H07_2T','H10_2T','H11_2T','H12_2T','H13_2T','H14_2T','H15_2T','H16_2T','H17_2T','H19_2T','H22_2T','H26_2T','H27_2T','H31_2T','H32_2T','H33_2T','H39_2T',...
    'H02_3T','H03_3T','H04_3T','H06_3T','H07_3T','H10_3T','H11_3T','H12_3T','H13_3T','H14_3T','H15_3T','H16_3T','H17_3T','H19_3T','H22_3T','H26_3T','H27_3T','H31_3T','H32_3T','H33_3T','H39_3T',...
    'H02_4T','H03_4T','H04_4T','H06_4T','H07_4T','H10_4T','H11_4T','H12_4T','H13_4T','H14_4T','H15_4T','H16_4T','H17_4T','H19_4T','H22_4T','H26_4T','H27_4T','H31_4T','H32_4T','H33_4T','H39_4T',...
    'H02_5T','H03_5T','H04_5T','H06_5T','H07_5T','H10_5T','H11_5T','H12_5T','H13_5T','H14_5T','H15_5T','H16_5T','H17_5T','H19_5T','H22_5T','H26_5T','H27_5T','H31_5T','H32_5T','H33_5T','H39_5T'
    };
FilesNumber = length(FileNames);

mice = {
    'H02' 'H03' 'H04' 'H06' 'H07' 'H10' 'H11' 'H12' 'H13' 'H14' 'H15' 'H16' 'H17' 'H19' 'H22' 'H26' 'H27' 'H31' 'H32' 'H33' 'H39'
    };

groups = {
    'TR' 'TR' 'TR' 'AC' 'AC' 'AC' 'TR' 'TR' 'AC' 'TR' 'AC' 'AC' 'AC' 'TR' 'TR' 'TR' 'AC' 'TR' 'TR' 'AC' 'AC'
    };

% сессии в конкретном эксперименте
session_id = {'1T' '2T' '3T' '4T' '5T'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), 'VariableNames', {'mouse', 'group'});

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
Duration = zeros(1,FilesNumber);
AllActs = struct('SessionName', '',  'Acts', []);

%% main part
for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'Options');
    
    % add velocity into Acts
    for line = 1:size(Acts,2)
        Acts(line).ActDuration = Acts(line).ActPercent*Options.Duration/100;
    end
    
    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    Distance(file) = BodyPartsTraces(Point.Center).AverageDistance;
    Velocity(file) = BodyPartsTraces(Point.Center).AverageSpeed;
    
    Duration(file) = Options.Duration;
    
    clear 'Acts' 'BodyPartsTraces' 'Point' 'Options';
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

% необходимые метрики
% names_metric = {'ActNumber' 'ActPercent' 'ActMeanTime' 'Distance' 'ActMeanDistance' 'ActVelocity' 'ActDuration'};

%% Create Super-Duper-Yummy Table

% добавить все метрики актов
num_volume = 1;
for act = 1:length(exp_acts)
    for session = 1:length(session_id)
        names_metric = behavior_acts_struct.(exp_acts{act});
        for metric = 1:length(names_metric)
            SuperTable.Name{num_volume} = [exp_acts{act} '_' char(names_metric(metric)) '_' session_id{session}];
            SuperTable.ActID{num_volume} = exp_acts{act};
            SuperTable.TrialID{num_volume} = session_id{session};
            SuperTable.MetricID{num_volume} = char(names_metric(metric));
            for mouse = 1:length(mice)
                session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
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

% добавить дистанцию
column_count = length(SuperTable.Name);
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['distance_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'distance';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 'm';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
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
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Velocity(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% добавить время сессии
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['duration_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'duration';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 's';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Duration(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

%% сохрание таблицы целиком
% создание и сохранение итоговой таблицы
SuperTable.Table = array2table(SuperTable.Data, 'VariableNames', SuperTable.Name);
SuperTable.Table = [mice_info, SuperTable.Table];

% сортировка по группе
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


%% сохранение типа "1 лист = 1 акт"






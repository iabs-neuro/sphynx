%% paths and filenames

ExpID = '3DM';

PathMat = 'w:\Projects\3DM\BehaviorData\6_MAT\';
PathOut = 'w:\Projects\3DM\BehaviorData\';

% for ALL DAYS
FileNames = {
    'D14_1D_1T' 'D14_2D_1T' 'D14_3D_1T' 'D14_4D_1T' 'D14_5D_1T' 'D14_6D_1T' 'D14_7D_1T' ...
    'D17_1D_1T' 'D17_2D_1T' 'D17_3D_1T' 'D17_4D_1T' 'D17_5D_1T' 'D17_6D_1T' 'D17_7D_1T' ...
    'F26_1D_1T' 'F26_2D_1T' 'F26_3D_1T' 'F26_4D_1T' 'F26_5D_1T' 'F26_6D_1T' 'F26_7D_1T' ...
    'F28_1D_1T' 'F28_2D_1T' 'F28_3D_1T' 'F28_4D_1T' 'F28_5D_1T' 'F28_6D_1T' 'F28_7D_1T' ...
    'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T' 'F29_6D_1T' 'F29_7D_1T' ...
    'F30_1D_1T' 'F30_2D_1T' 'F30_3D_1T' 'F30_4D_1T' 'F30_5D_1T' 'F30_6D_1T' 'F30_7D_1T' ...
    'F31_1D_1T' 'F31_2D_1T' 'F31_3D_1T' 'F31_4D_1T' 'F31_5D_1T' 'F31_6D_1T' 'F31_7D_1T' ...
    'F35_1D_1T' 'F35_2D_1T' 'F35_3D_1T' 'F35_4D_1T' 'F35_5D_1T' 'F35_6D_1T' 'F35_7D_1T' ...
    'F36_1D_1T'             'F36_3D_1T' 'F36_4D_1T' 'F36_5D_1T'             'F36_7D_1T' ...
    'F37_1D_1T' 'F37_2D_1T' 'F37_3D_1T' 'F37_4D_1T' 'F37_5D_1T' 'F37_6D_1T' 'F37_7D_1T' ...
    'F38_1D_1T'             'F38_3D_1T' 'F38_4D_1T' 'F38_5D_1T' 'F38_6D_1T' 'F38_7D_1T' ...
    'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T' 'F40_6D_1T' 'F40_7D_1T' ...
                'F43_2D_1T' 'F43_3D_1T' 'F43_4D_1T' 'F43_5D_1T' 'F43_6D_1T' 'F43_7D_1T' ...
                'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T' 'F48_6D_1T' 'F48_7D_1T' ...
    'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T' 'F52_6D_1T' 'F52_7D_1T' ...
    'F54_1D_1T' 'F54_2D_1T' 'F54_3D_1T' 'F54_4D_1T' 'F54_5D_1T' 'F54_6D_1T' 'F54_7D_1T' ...
    };

FilesNumber = length(FileNames);

mice = {
    'D14' 'D17' 'F31' 'F35' 'F37' 'F43' 'F48' 'F52' 'F54' 'F26' 'F28' 'F29' 'F30' 'F36' 'F38' 'F40'
    };

groups = {
    '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' ''
    };

% сессии в конкретном эксперименте
session_id = {'1D_1T' '2D_1T' '3D_1T' '4D_1T' '5D_1T' '6D_1T' '7D_1T'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), 'VariableNames', {'mouse', 'group'});

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
Duration = zeros(1,FilesNumber);            % no start box
Duration_total = zeros(1,FilesNumber);      % all time (1800 seconds should be)
Height_up = zeros(1,FilesNumber);
Height_down = zeros(1,FilesNumber);
Height = zeros(1,FilesNumber);

%% main part
for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'session');
    
    Acts = replaceNaNinStruct(Acts);
    
    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    
    Duration(file) = session.duration;                  % no start box
    Duration_total(file) = session.duration_total;      % all time (1800 seconds should be)
    
    Distance(file) = session.total_distance;
    Velocity(file) = session.mean_velocity;
    
    Height_up(file) = session.total_height_up;
    Height_down(file) = session.total_height_down;
    Height(file) = session.total_height;
    
    clear 'Acts' 'session';
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
    SuperTable.Name{column_count+1} = ['duration_session_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'duration_session';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 's';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Duration_total(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% добавить время в лабиринте
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['duration_maze_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'duration_maze';
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

% добавить набор высоты
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['height_up_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'height_up';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 's';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Height_up(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end


% добавить спуск высоты
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['height_down_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'height_down';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 's';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Height_down(ismember(FileNames, this_name));
        else
            SuperTable.Data(mouse, column_count+1) = NaN;
        end
    end
    column_count = column_count + 1;
end

% добавить пройденный путь по высоте
for session = 1:length(session_id)
    SuperTable.Name{column_count+1} = ['height_' session_id{session}];
    SuperTable.ActID{column_count+1} = 'height';
    SuperTable.TrialID{column_count+1} = session_id{session};
    SuperTable.MetricID{column_count+1} = 'cm';
    for mouse = 1:length(mice)
        this_name = [mice{mouse} '_' session_id{session}];
        session_name = [ExpID '_' mice{mouse} '_' session_id{session}];
        session_idx = find(strcmp({AllActs.SessionName}, session_name));
        if any(strcmp({AllActs.SessionName}, session_name))
            SuperTable.Data(mouse, column_count+1) = Height(ismember(FileNames, this_name));
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




%% paths and filenames

ExpID = '3DM';

PathMat = 'e:\Projects\3DM\BehaviorData\7_Mat_files\';
PathOut = 'e:\Projects\3DM\BehaviorData\';

% for ALL DAYS
FileNames = {
%     'D14_1D' 'D14_2D' 'D14_3D' 'D14_4D' 'D14_5D' 'D14_6D' 'D14_7D' ...
%     'D17_1D' 'D17_2D' 'D17_3D' 'D17_4D' 'D17_5D' 'D17_6D' 'D17_7D' ...
%     'F26_1D' 'F26_2D' 'F26_3D' 'F26_4D' 'F26_5D' 'F26_6D' 'F26_7D' ...
%     'F28_1D' 'F28_2D' 'F28_3D' 'F28_4D' 'F28_5D' 'F28_6D' 'F28_7D' ...
%     'F29_1D' 'F29_2D' 'F29_3D' 'F29_4D' 'F29_5D' 'F29_6D' 'F29_7D' ...
%     'F30_1D' 'F30_2D' 'F30_3D' 'F30_4D' 'F30_5D' 'F30_6D' 'F30_7D' ...
%     'F31_1D' 'F31_2D' 'F31_3D' 'F31_4D' 'F31_5D' 'F31_6D' 'F31_7D' ...
%     'F35_1D' 'F35_2D' 'F35_3D' 'F35_4D' 'F35_5D' 'F35_6D' 'F35_7D' ...
%     'F36_1D'          'F36_3D' 'F36_4D' 'F36_5D'          'F36_7D' ...
%     'F37_1D' 'F37_2D' 'F37_3D' 'F37_4D' 'F37_5D' 'F37_6D' 'F37_7D' ...
%     'F38_1D'          'F38_3D' 'F38_4D' 'F38_5D' 'F38_6D' 'F38_7D' ...
%     'F40_1D' 'F40_2D' 'F40_3D' 'F40_4D' 'F40_5D' 'F40_6D' 'F40_7D' ...
%              'F43_2D' 'F43_3D' 'F43_4D' 'F43_5D' 'F43_6D' 'F43_7D' ...
%              'F48_2D' 'F48_3D' 'F48_4D' 'F48_5D' 'F48_6D' 'F48_7D' ...
%     'F52_1D' 'F52_2D' 'F52_3D' 'F52_4D' 'F52_5D' 'F52_6D' 'F52_7D' ...
%     'F54_1D' 'F54_2D' 'F54_3D' 'F54_4D' 'F54_5D' 'F54_6D' 'F54_7D' ...
    'J01_1D' 'J01_2D' 'J01_3D' 'J01_4D' 'J01_5D' 'J01_6D' 'J01_7D' ...
    'J03_1D' 'J03_2D' 'J03_3D' 'J03_4D' 'J03_5D' 'J03_6D' 'J03_7D' ...
    'J05_1D' 'J05_2D' 'J05_3D' 'J05_4D' 'J05_5D' 'J05_6D' 'J05_7D' ...
    'J06_1D' 'J06_2D' 'J06_3D' 'J06_4D' 'J06_5D' 'J06_6D' 'J06_7D' ...
    'J09_1D' 'J09_2D' 'J09_3D' 'J09_4D' 'J09_5D' 'J09_6D' 'J09_7D' ...
    'J10_1D' 'J10_2D' 'J10_3D' 'J10_4D' 'J10_5D' 'J10_6D' 'J10_7D' ...
    'J12_1D' 'J12_2D' 'J12_3D' 'J12_4D' 'J12_5D' 'J12_6D' 'J12_7D' ...
    'J13_1D' 'J13_2D' 'J13_3D' 'J13_4D' 'J13_5D' 'J13_6D' 'J13_7D' ...
    'J14_1D' 'J14_2D' 'J14_3D' 'J14_4D' 'J14_5D' 'J14_6D' 'J14_7D' ...
    'J17_1D' 'J17_2D' 'J17_3D' 'J17_4D' 'J17_5D' 'J17_6D' 'J17_7D' ...
    'J19_1D' 'J19_2D' 'J19_3D' 'J19_4D' 'J19_5D' 'J19_6D' 'J19_7D' ...
    'J20_1D' 'J20_2D' 'J20_3D' 'J20_4D' 'J20_5D' 'J20_6D' 'J20_7D' ...
    'J24_1D' 'J24_2D' 'J24_3D' 'J24_4D' 'J24_5D' 'J24_6D' 'J24_7D' ...
    'J52_1D' 'J52_2D' 'J52_3D' 'J52_4D' 'J52_5D' 'J52_6D' 'J52_7D' ...
    'J53_1D' 'J53_2D' 'J53_3D' 'J53_4D' 'J53_5D' 'J53_6D' 'J53_7D' ...
    'J54_1D' 'J54_2D' 'J54_3D' 'J54_4D' 'J54_5D' 'J54_6D' 'J54_7D' ...
    'J55_1D' 'J55_2D' 'J55_3D' 'J55_4D' 'J55_5D' 'J55_6D' 'J55_7D' ...
    'J57_1D' 'J57_2D' 'J57_3D' 'J57_4D' 'J57_5D' 'J57_6D' 'J57_7D' ...
    'J59_1D' 'J59_2D' 'J59_3D' 'J59_4D' 'J59_5D' 'J59_6D' 'J59_7D' ...
    'J61_1D' 'J61_2D' 'J61_3D' 'J61_4D' 'J61_5D' 'J61_6D' 'J61_7D' ...
    };

FilesNumber = length(FileNames);

mice = {
    'J01' 'J05' 'J06' 'J09' 'J10' 'J12' 'J13' 'J14' 'J17' 'J19' 'J24' 'J52' 'J53' 'J54' 'J55' 'J57' 'J59'
    };

groups = {
    'light' 'dark' 'dark' 'dark' 'light' 'light' 'light' 'dark' 'dark' 'light' 'light' 'light' 'dark' 'light' 'dark' 'dark' 'light'
    };

lines = {
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
};

% сессии в конкретном эксперименте
session_id = {'1D' '2D' '3D' '4D' '5D' '6D' '7D'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), lines(:), 'VariableNames', {'mouse', 'group', 'line'});

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

writetable(SuperTable.Table, sprintf('%s\\%s_Behavior_box_lover.csv',PathOut, ExpID));

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

    writecell(full_table, sprintf('%s\\%s_Behavior_sorted_session_box_lover.xlsx',PathOut, ExpID), 'Sheet', sprintf('%s', session_id{session}));
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

writecell(MegaFullTable, sprintf('%s\\%s_Behavior_sorted_session_box_lover.xlsx',PathOut, ExpID), 'Sheet', 'All');


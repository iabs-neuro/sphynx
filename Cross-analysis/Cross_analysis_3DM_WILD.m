%% paths and filenames

ExpID = '3DM';

PathMat = 'w:\Projects\3DM\Comparasion\3DMaze\6_Mat\';
PathOut = 'w:\Projects\3DM\Comparasion\3DMaze\';

% for ALL DAYS
FileNames = {
    'AA04_1D_1T' 'AA04_2D_1T' 'AA04_3D_1T' 'AA05_1D_1T' 'AA05_2D_1T' 'AA05_3D_1T' ...
    'AA06_1D_1T' 'AA06_2D_1T' 'AA06_3D_1T' 'AA06_4D_1T' 'AA07_1D_1T' 'AA07_2D_1T' 'AA07_3D_1T' 'AA07_4D_1T' ...
    'AA08_1D_1T' 'AA08_2D_1T' 'AA08_3D_1T' 'AA08_4D_1T' 'AA09_1D_1T' 'AA09_2D_1T' 'AA09_3D_1T' 'AA09_4D_1T' ...
    'AA10_1D_1T' 'AA10_2D_1T' 'AA10_3D_1T' 'AA11_1D_1T' 'AA11_2D_1T' 'AA11_3D_1T' 'AA11_4D_1T' ...
    'AA12_1D_1T' 'AA12_2D_1T' 'AA12_3D_1T' 'AA13_1D_1T' 'AA13_2D_1T' 'AA13_3D_1T' 'AA13_4D_1T' ...
    'AA14_1D_1T' 'AA14_2D_1T' 'AA14_3D_1T'              'CG05_2D_1T' 'CG05_3D_1T' 'CG05_4D_1T' ...
                 'CG06_2D_1T'              'CG08_1D_1T' 'CG08_2D_1T' 'CG08_3D_1T' ...
    'CG09_1D_1T' 'CG09_2D_1T'              'CG09_4D_1T' 'CG11_1D_1T' 'CG11_2D_1T' 'CG11_3D_1T' ...
    'CG14_1D_1T' 'CG14_2D_1T' 'CG14_3D_1T' 'CG14_4D_1T'                                        ...
    'CG20_1D_1T' 'CG20_2D_1T' 'CG20_3D_1T' 'CG20_4D_1T' 'CG22_1D_1T' 'CG22_2D_1T' 'CG22_3D_1T' ...
    'LM01_1D_1T' 'LM01_2D_1T' 'LM01_3D_1T' 'LM01_4D_1T' 'LM02_1D_1T' 'LM02_2D_1T' 'LM02_3D_1T' ...
    'LM03_1D_1T' 'LM03_2D_1T' 'LM03_3D_1T' 'LM04_1D_1T' 'LM04_2D_1T' 'LM04_3D_1T' 'LM04_4D_1T' ...
    'LM05_1D_1T' 'LM05_2D_1T' 'LM05_3D_1T' 'LM05_4D_1T' 'LM06_1D_1T' 'LM06_2D_1T' 'LM06_3D_1T' ...
    'LM07_1D_1T' 'LM07_2D_1T' 'LM07_3D_1T' 'LM07_4D_1T' 'LM08_1D_1T' 'LM08_2D_1T' 'LM08_3D_1T' ...
    'LM09_1D_1T' 'LM09_2D_1T' 'LM09_3D_1T' 'LM09_4D_1T' 'LM10_1D_1T' 'LM10_2D_1T' 'LM10_3D_1T' ...
    'SU03_1D_1T' 'SU03_2D_1T'              'SU04_1D_1T' 'SU04_2D_1T' 'SU04_3D_1T' 'SU04_4D_1T' ...
    'SU06_1D_1T' 'SU06_2D_1T' 'SU06_3D_1T' 'SU13_1D_1T' 'SU13_2D_1T' 'SU13_3D_1T' 'SU13_4D_1T' ...
    'SU14_1D_1T' 'SU14_2D_1T' 'SU14_3D_1T' 'SU15_1D_1T' 'SU15_2D_1T' 'SU15_3D_1T' ...
    'SU16_1D_1T' 'SU16_2D_1T' 'SU16_3D_1T' 'SU16_4D_1T' 'SU19_1D_1T' 'SU19_2D_1T' 'SU19_3D_1T' 'SU19_4D_1T'
    };

FilesNumber = length(FileNames);

mice = {
    'AA06' 'AA04' 'AA05' 'AA07' 'AA08' 'AA09' 'AA10' 'AA11' 'AA12' 'AA13' 'AA14' ...
    'CG05' 'CG06' 'CG08' 'CG09' 'CG11' 'CG14'        'CG20' 'CG22' ...
    'LM01' 'LM02' 'LM03' 'LM04' 'LM05' 'LM06' 'LM07' 'LM08' 'LM09' 'LM10' ...
    'SU03' 'SU04' 'SU06' 'SU13' 'SU14' 'SU15' 'SU16' 'SU19'
    };

groups = {
    'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' ...
    'CG' 'CG' 'CG' 'CG' 'CG' 'CG'      'CG' 'CG' ...
    'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' ...
    'SU' 'SU' 'SU' 'SU' 'SU' 'SU' 'SU' 'SU'};

% сессии в конкретном эксперименте
session_id = {'1D_1T' '2D_1T' '3D_1T' '4D_1T'};

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

writetable(SuperTable.Table, sprintf('%s\\%s_WILD_Behavior.csv',PathOut, ExpID));

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

    writecell(full_table, sprintf('%s\\%s_WILD_Behavior_sorted_session.xlsx',PathOut, ExpID), 'Sheet', sprintf('%s', session_id{session}));
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

writecell(MegaFullTable, sprintf('%s\\%s_WILD_Behavior_sorted_session.xlsx',PathOut, ExpID), 'Sheet', 'All');




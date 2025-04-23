%% paths and filenames

ExpID = '2DM';

PathMat = sprintf('w:\\Projects\\3DM\\Comparision\\%s\\6_MAT\\', ExpID);
PathOut = sprintf('w:\\Projects\\3DM\\Comparision\\%s\\', ExpID);

FileNames = {
    'AA04_1D',	'AA04_2D',	'AA04_3D',	'AA04_4D',	'AA05_1D',	'AA05_2D',  'AA05_3D',	'AA05_4D',	'AA06_1D',	'AA06_2D',	'AA06_3D',	'AA07_1D',	'AA07_2D',	'AA07_3D',	'AA08_1D',	'AA08_2D',	'AA08_3D',	'AA09_1D'	'AA09_2D',	'AA09_3D',	'AA10_1D',	'AA10_2D',	'AA10_3D',	'AA10_4D',	'AA11_1D',	'AA11_2D',	'AA11_3D',	'AA12_1D',	'AA12_2D',	'AA12_3D',	'AA12_4D',	'AA13_1D',	'AA13_2D',	'AA13_3D',	'AA14_1D',	'AA14_2D',	'AA14_3D',	'AA14_4D', ...
    'CG05_1D',	'CG05_2D',	'CG05_3D',	'CG06_1D',	'CG06_2D',	'CG06_3D',	'CG06_4D',	'CG08_1D',	'CG08_2D',	'CG08_3D',	'CG08_4D',	'CG09_1D',	'CG09_2D',	'CG09_3D',	'CG11_1D',	'CG11_2D',	'CG11_3D',	'CG11_4D',	'CG14_1D',	'CG14_2D',	'CG14_3D',	'CG15_1D',	'CG15_2D',	'CG15_3D',	'CG15_4D',	'CG20_1D',	'CG20_2D',	'CG20_3D',	'CG22_1D',	'CG22_2D',	'CG22_3D',	'CG22_4D', ...
    'LM01_1D',	'LM01_2D',	'LM01_3D',	'LM02_1D',	'LM02_2D',	'LM02_3D',	'LM02_4D',	'LM03_1D',	'LM03_2D',	'LM03_3D',	'LM03_4D',	'LM04_1D',	'LM04_2D',	'LM04_3D',	'LM05_1D',	'LM05_2D',	'LM05_3D',	'LM06_1D',	'LM06_2D',	'LM06_3D',	'LM06_4D',	'LM07_1D',	'LM07_2D',	'LM07_3D',	'LM08_1D',	'LM08_2D',	'LM08_3D',	'LM08_4D',	'LM09_1D',	'LM09_2D',	'LM09_3D',	'LM10_1D',	'LM10_2D',	'LM10_3D',	'LM10_4D', ...
    'SU03_1D',	'SU03_2D',	'SU03_3D',	'SU03_4D',	'SU04_1D',	'SU04_2D',	'SU04_3D',	'SU06_1D',	'SU06_2D',	'SU06_3D',	'SU06_4D',	'SU13_1D',	'SU13_2D',	'SU13_3D',	'SU14_1D',	'SU14_2D',	'SU14_3D',	'SU14_4D',	'SU15_1D',	'SU15_2D',	'SU15_3D',	'SU15_4D',	'SU16_1D',	'SU16_2D',	'SU16_3D',	'SU19_1D',	'SU19_2D',  'SU19_3D'
    };

FilesNumber = length(FileNames);

mice = {
    'AA04' 'AA05' 'AA06' 'AA07' 'AA08' 'AA09' 'AA10' 'AA11' 'AA12' 'AA13' 'AA14' ...
    'CG05' 'CG06' 'CG08' 'CG09' 'CG11' 'CG14' 'CG15' 'CG20' 'CG22' ...
    'LM01' 'LM02' 'LM03' 'LM04' 'LM05' 'LM06' 'LM07' 'LM08' 'LM09' 'LM10' ...
    'SU03' 'SU04' 'SU06' 'SU13' 'SU14' 'SU15' 'SU16' 'SU19' ...
    };

groups = {
    'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' 'AA' ...
    'CG' 'CG' 'CG' 'CG' 'CG' 'CG' 'CG' 'CG' 'CG' ...
    'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' 'LM' ...
    'SU' 'SU' 'SU' 'SU' 'SU' 'SU' 'SU' 'SU'
    };

% сессии в конкретном эксперименте
session_id = {'1D_1T' '2D_1T' '3D_1T' '4D_1T'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), 'VariableNames', {'mouse', 'group'});

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
Duration = zeros(1,FilesNumber);
AllActs = struct('SessionName', '',  'Acts', []);

%% main part
for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_%s_1T_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'Options');
 
    table_name = sprintf('%s_%s_1T', ExpID, FileNames{file});
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    Distance(file) = round(BodyPartsTraces(Point.Center).AverageDistance*100);
    Velocity(file) = BodyPartsTraces(Point.Center).AverageSpeed;
    
    Duration(file) = round(Options.Duration);
    
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
        this_name = [mice{mouse} '_' session_id{session}(1:end-3)];
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
        this_name = [mice{mouse} '_' session_id{session}(1:end-3)];
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
        this_name = [mice{mouse} '_' session_id{session}(1:end-3)];
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

%% сохранение типа "1 лист = 1 акт"






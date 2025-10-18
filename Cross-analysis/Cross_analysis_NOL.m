%% paths and filenames

ExpID = 'NOL';

PathMat = 'w:\Projects\NOL\BehaviorData\6_MAT\';
PathOut = 'w:\Projects\NOL\BehaviorData\';

% for ALL DAYS
FileNames = {
    '1L-test' '1L-training' '1R-test' '1R-training' '2L-test' '2L-training' '2R-test' ...
    '2R-training' '3L-test' '3L-training' '3R-test' '3R-training' '4L-test' '4L-training' ...
    '4R-test' '4R-training' '5L-test' '5L-training' '5R-test' '5R-training' ...
    };

FilesNumber = length(FileNames);

mice = {
    '1L' '1R' '2L' '2R' '3L' '3R' '4L' '4R' '5L' '5R'
    };

groups = {
    '' '' '' '' '' '' '' '' '' ''
    };

% сессии в конкретном эксперименте
session_id = {'training' 'test'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), 'VariableNames', {'mouse', 'group'});

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

%% main part
for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_WorkSpace.mat', PathMat, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'Options');
 
    table_name = FileNames{file};
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts; 
    
    Distance(file) = round(BodyPartsTraces(Point.Center).AverageDistance*100);
    Velocity(file) = BodyPartsTraces(Point.Center).AverageSpeed;
    
    clear 'Acts' 'BodyPartsTraces' 'Point' 'Options'
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
                session_name = [mice{mouse} '-' session_id{session}];
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
        this_name = [mice{mouse} '-' session_id{session}];
        session_name = [mice{mouse} '-' session_id{session}];
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
        this_name = [mice{mouse} '-' session_id{session}];
        session_name = [mice{mouse} '-' session_id{session}];
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

%% new sorting

% Получаем идентификаторы актов, дней и метрик из соответствующих строк
act_ids = MegaFullTable(1, size(mice_info,2)+1:end);  % Строка с ActID
day_ids = MegaFullTable(2, size(mice_info,2)+1:end);  % Строка с TrialID
metric_ids = MegaFullTable(3, size(mice_info,2)+1:end); % Строка с MetricID

% Определяем пары актов, которые должны стоять рядом
act_pairs = {
    'objectinside', 'objectinteraction';
    'object_control_inside', 'object_control_interaction'
};

% Создаем структуру для хранения информации о столбцах
columns_info = struct();
for i = 1:length(act_ids)
    columns_info(i).act = act_ids{i};
    columns_info(i).day = day_ids{i};
    columns_info(i).metric = metric_ids{i};
    columns_info(i).original_idx = i;
    columns_info(i).end_letter = columns_info(i).act(end);
end

% Сортируем столбцы сначала по дню, затем по метрике, затем по акту
[~, sort_idx] = sortrows(...
    [vertcat({columns_info.day})' vertcat({columns_info.metric})' vertcat({columns_info.end_letter})'], ...
    [1, 2, 3]);

sorted_columns = columns_info(sort_idx);

% Теперь переупорядочиваем столбцы так, чтобы связанные акты стояли рядом
new_order = sort_idx;
% processed = false(1, length(sorted_columns));

% for i = 1:length(sorted_columns)
%     if ~processed(i)
%         current_col = sorted_columns(i);
%         
%         % Ищем парный столбец
%         pair_found = false;
%         for p = 1:size(act_pairs, 1)
%             if strcmp(current_col.act, act_pairs{p,1})
%                 target_act = act_pairs{p,2};
%                 pair_found = true;
%             elseif strcmp(current_col.act, act_pairs{p,2})
%                 target_act = act_pairs{p,1};
%                 pair_found = true;
%             end
%             
%             if pair_found
%                 % Ищем столбец с тем же днем и метрикой, но другим актом
%                 pair_idx = find(...
%                     strcmp({sorted_columns.day}, current_col.day) & ...
%                     strcmp({sorted_columns.metric}, current_col.metric) & ...
%                     strcmp({sorted_columns.act}, target_act) & ...
%                     ~processed, 1);
%                 
%                 if ~isempty(pair_idx)
%                     new_order = [new_order, i, pair_idx];
%                     processed(i) = true;
%                     processed(pair_idx) = true;
%                     break;
%                 end
%             end
%         end
%         
%         if ~pair_found || isempty(pair_idx)
%             new_order = [new_order, i];
%             processed(i) = true;
%         end
%     end
% end

% Применяем новый порядок к отсортированным столбцам
final_columns = sorted_columns;

% Собираем новую таблицу
% 1. Оставляем первые столбцы с mice_info без изменений
mice_info_cols = 1:size(mice_info,2);
sorted_MegaFullTable = MegaFullTable(:, mice_info_cols);

% 2. Добавляем переупорядоченные столбцы с данными
for i = 1:length(final_columns)
    original_idx = final_columns(i).original_idx + size(mice_info,2);
    sorted_MegaFullTable = [sorted_MegaFullTable, MegaFullTable(:, original_idx)];
end

writecell(sorted_MegaFullTable, sprintf('%s\\%s_Behavior_sorted_acts.xlsx',PathOut, ExpID), 'Sheet', 'All');

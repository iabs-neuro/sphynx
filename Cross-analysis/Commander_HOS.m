%% paths and filenames
ExpID = 'HOS';

PathVideo = sprintf('e:\\Projects\\%s\\BehaviorData_3wave\\2_Combined\\',ExpID);
PathDLC = sprintf('e:\\Projects\\%s\\BehaviorData_3wave\\3_DLC\\',ExpID);
PathPreset = sprintf('e:\\Projects\\%s\\BehaviorData_3wave\\4_Preset\\',ExpID);
PathMat = sprintf('e:\\Projects\\%s\\BehaviorData_3wave\\6_Behav_mat\\',ExpID);

PathOut = sprintf('e:\\Projects\\%s\\BehaviorData_3wave\\',ExpID);

FileNames = {
    'D01_1D' 'D01_2D' 'D01_3D' 'D01_4D' 'D01_5D' 'D03_1D' 'D03_2D' 'D03_3D' 'D03_4D' 'D03_5D' ...
    'D04_1D' 'D04_2D' 'D04_3D' 'D04_4D' 'D04_5D' 'D07_1D' 'D07_2D' 'D07_3D' 'D07_4D' 'D07_5D' ...
    'D08_1D' 'D08_2D' 'D08_3D' 'D08_4D' 'D08_5D' 'D11_1D' 'D11_2D' 'D11_3D' 'D11_4D' 'D11_5D' ...
    'D14_1D' 'D14_2D' 'D14_3D' 'D14_4D' 'D14_5D' 'D17_1D' 'D17_2D' 'D17_3D' 'D17_4D' 'D17_5D' ...
    ...
    'F01_1D' 'F01_2D' 'F01_3D' 'F01_4D' 'F01_5D' 'F04_1D' 'F04_2D' 'F04_3D' 'F04_4D' 'F04_5D' ...
    'F06_1D' 'F06_2D' 'F06_3D' 'F06_4D' 'F06_5D' 'F08_1D' 'F08_2D' 'F08_3D' 'F08_4D' 'F08_5D' ...
    'F09_1D' 'F09_2D' 'F09_3D' 'F09_4D' 'F09_5D' 'F11_1D' 'F11_2D' 'F11_3D' 'F11_4D' 'F11_5D' ...
    'F14_1D' 'F14_2D' 'F14_3D' 'F14_4D' 'F14_5D' 'F15_1D' 'F15_2D' 'F15_3D' 'F15_4D' 'F15_5D' ...
    'F26_1D' 'F26_2D' 'F26_3D' 'F26_4D' 'F26_5D' 'F28_1D' 'F28_2D' 'F28_3D' 'F28_4D' 'F28_5D' ...
    'F29_1D' 'F29_2D' 'F29_3D' 'F29_4D' 'F29_5D' 'F30_1D' 'F30_2D' 'F30_3D' 'F30_4D' 'F30_5D' ...
    'F34_1D' 'F34_2D' 'F34_3D' 'F34_4D' 'F34_5D' 'F36_1D' 'F36_2D' 'F36_3D' 'F36_4D' 'F36_5D' ...
    'F37_1D' 'F37_2D' 'F37_3D' 'F37_4D' 'F37_5D' 'F38_1D' 'F38_2D' 'F38_3D' 'F38_4D' 'F38_5D' ...
    'F40_1D' 'F40_2D' 'F40_3D' 'F40_4D' 'F40_5D' 'F43_1D' 'F43_2D' 'F43_3D' 'F43_4D' 'F43_5D' ...
    'F48_1D' 'F48_2D' 'F48_3D' 'F48_4D' 'F48_5D' 'F52_1D' 'F52_2D' 'F52_3D' 'F52_4D' 'F52_5D' ...
    'F54_1D' 'F54_2D' 'F54_3D' 'F54_4D' 'F54_5D' ...
    ...
    'J01_1D' 'J01_2D' 'J01_3D' 'J01_4D' 'J01_5D' 'J05_1D' 'J05_2D' 'J05_3D' 'J05_4D' 'J05_5D' ...
    'J06_1D' 'J06_2D' 'J06_3D' 'J06_4D' 'J06_5D' 'J13_1D' 'J13_2D' 'J13_3D' 'J13_4D' 'J13_5D' ...
    'J14_1D' 'J14_2D' 'J14_3D' 'J14_4D' 'J14_5D' 'J19_1D' 'J19_2D' 'J19_3D' 'J19_4D' 'J19_5D' ...
    'J20_1D' 'J20_2D' 'J20_3D' 'J20_4D' 'J20_5D' 'J21_1D' 'J21_2D' 'J21_3D' 'J21_4D' 'J21_5D' ...
    'J24_1D' 'J24_2D' 'J24_3D' 'J24_4D' 'J24_5D' 'J25_1D' 'J25_2D' 'J25_3D' 'J25_4D' 'J25_5D' ...
    'J30_1D' 'J30_2D' 'J30_3D' 'J30_4D' 'J30_5D' 'J52_1D' 'J52_2D' 'J52_3D' 'J52_4D' 'J52_5D' ...
    'J53_1D' 'J53_2D' 'J53_3D' 'J53_4D' 'J53_5D' 'J54_1D' 'J54_2D' 'J54_3D' 'J54_4D' 'J54_5D' ...
    'J58_1D' 'J58_2D' 'J58_3D' 'J58_4D' 'J58_5D' ...
    };

mice = { 
    'D01' 'D03' 'D04' 'D07' 'D11' 'D14' 'D17' ...
    'F01' 'F04' 'F06' 'F09' 'F11' 'F14' 'F15' ...
    'F26' 'F28' 'F29' 'F30' 'F34' 'F36' 'F37' 'F38' 'F40' 'F43' 'F48' 'F52' 'F54' ...
    'J01' 'J05' 'J06' 'J13' 'J14' 'J19' 'J20' 'J21' 'J24' 'J25' ...
    'J30' 'J52' 'J53' 'J54' 'J58' ...
    };

groups = {
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    };

lines = {
    'Equal 5D' 'Diverse 5D' 'Equal 1D' 'Diverse 5D' 'Equal 1D' 'Equal 5D' 'Diverse 5D' ...
    'Diverse 5D' 'Equal 1D' 'Diverse 5D' 'Diverse 5D' 'Equal 5D' 'Equal 1D' 'Equal 5D' ...
    'Equal 1D' 'Equal 5D' 'Equal 1D' 'Diverse 5D' 'Diverse 5D' 'Equal 1D' 'Diverse 5D' 'Equal 5D' 'Equal 5D' 'Equal 5D' 'Diverse 5D' 'Equal 1D' 'Equal 5D' ...
    'Equal 1D' 'Diverse 5D' 'Diverse 5D' 'Equal 5D' 'Diverse 5D' 'Equal 5D' 'Equal 5D' 'Equal 5D' 'Diverse 5D' 'Equal 1D' ...
    'Equal 1D' 'Equal 5D' 'Diverse 5D' 'Equal 1D' 'Equal 1D' ...
};

FilesNumber = length(FileNames);

%% main part

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzerHOS(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
end

%% collect data

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), lines(:), 'VariableNames', {'mouse', 'group', 'line'});

% сессии в конкретном эксперименте
session_id = {'1D' '2D' '3D' '4D' '5D'};

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

%% collect data

for file = 1:length(FileNames)
    
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'n_frames', 'Options');
    
%     for line = 1:size(Acts,2)    
%         Acts(line).ActDuration = round(Acts(line).ActPercent*n_frames/Options.FrameRate/100,2);
%     end
%     
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

% сохранение типа "1 лист = 1 сессия"

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
ExpID = 'LNOF';

PathVideo = sprintf('e:\\Projects\\%s\\BehaviorData\\2_Combined\\',ExpID);
PathDLC = sprintf('e:\\Projects\\%s\\BehaviorData\\3_DLC\\',ExpID);
PathPreset = sprintf('e:\\Projects\\%s\\BehaviorData\\4_Preset\\',ExpID);
PathMat = sprintf('e:\\Projects\\%s\\BehaviorData\\6_BehavSep_mat\\',ExpID);

PathOut = sprintf('e:\\Projects\\%s\\BehaviorData\\5_BehaviorSeparate\\',ExpID);

FileNames = {
    'J01_1D' 'J01_2D' 'J01_3D' 'J01_4D' 'J05_1D' 'J05_2D' 'J05_3D' 'J05_4D' ...
    'J06_1D' 'J06_2D' 'J06_3D' 'J06_4D' 'J12_1D' 'J12_2D' 'J12_3D' 'J12_4D' ...
    'J14_1D' 'J14_2D' 'J14_3D' 'J14_4D' 'J18_1D' 'J18_2D' 'J18_3D' 'J18_4D' ...
    'J19_1D' 'J19_2D' 'J19_3D' 'J19_4D' 'J20_1D' 'J20_2D' 'J20_3D' 'J20_4D' ...
    'J21_1D' 'J21_2D' 'J21_3D' 'J21_4D' 'J23_1D' 'J23_2D' 'J23_3D' 'J23_4D' ...
    'J24_1D' 'J24_2D' 'J24_3D' 'J24_4D' 'J25_1D' 'J25_2D' 'J25_3D' 'J25_4D' ...
                                        'J30_1D' 'J30_2D' 'J30_3D' 'J30_4D' ...
                                        'J52_1D' 'J52_2D' 'J52_3D' 'J52_4D' ...
    'J53_1D' 'J53_2D' 'J53_3D' 'J53_4D' 'J54_1D' 'J54_2D' 'J54_3D' 'J54_4D' ...
    'J55_1D' 'J55_2D' 'J55_3D' 'J55_4D' 'J56_1D' 'J56_2D' 'J56_3D' 'J56_4D' ...
    'J57_1D' 'J57_2D' 'J57_3D' 'J57_4D' 'J58_1D' 'J58_2D' 'J58_3D' 'J58_4D' ...
    'J59_1D' 'J59_2D' 'J59_3D' 'J59_4D' 'J61_1D' 'J61_2D' 'J61_3D' 'J61_4D' ...
    };

FilesNumber = length(FileNames);

fps = {
    30.03,30.03,30.03,30.03,30.03,30.03,30.03,30.03,29.99,29.99, ...
    29.99,66.00,29.99,29.99,29.99,30.00,29.99,29.99,29.99,66.00, ...
    29.99,29.99,29.99,29.99,29.99,29.99,29.99,66.00,65.99,65.99, ...
    65.99,29.99,29.99,29.99,29.99,66.00,29.99,29.99,29.99,29.99, ...
    29.99,29.99,29.99,29.99,30.03,30.03,30.03,30.03,65.99,65.99, ...
    29.99,29.99,65.99,65.99,29.99,29.99,30.03,30.03,30.03,30.03, ...
    29.99,29.99,66.00,29.99,65.99,29.99,65.99,29.99,30.03,30.03, ...
    30.03,30.03,30.03,30.03,30.03,30.03,29.99,29.99,29.99,29.99, ...
    29.99,29.99,29.99,29.99,29.99,29.99,66.00,29.99
    };

%% main part, analyzing

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.mp4', ExpID, FileNames{file});
    FilenameDLC = sprintf('%s_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', ExpID, FileNames{file});
    FilenamePreset = sprintf('%s_%s_Preset.mat', ExpID, FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    if groups{file} == "60min"
        for trial = 1:6
            t1 = round((trial-1)/6*fps{file}*60*60+1);
            t2 = round((trial)/6*fps{file}*60*60+1);
            fprintf('Processing of %s_%s. Trial: %d\n', ExpID, FileNames{file}, trial);
            fprintf('Time periods: %d-%d frames\n', t1, t2);
            [~, ~, ~] = BehaviorAnalyzer(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, t1, t2, PathPreset, FilenamePreset);
            
        end
    else
        for trial = 1:3
            t1 = round((trial-1)/3*fps{file}*30*60+1);
            t2 = round((trial)/3*fps{file}*30*60+1);
            fprintf('Processing of %s_%s. Trial: %d\n', ExpID, FileNames{file}, trial);
            fprintf('Time periods: %d-%d frames\n', t1, t2);
            [~, ~, ~] = BehaviorAnalyzer(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, t1, t2, PathPreset, FilenamePreset);
            
        end
    end
    
end

%% collect data

FileNames = {
'J01_1D_1T' 'J01_1D_2T' 'J01_1D_3T' 'J01_1D_4T' 'J01_1D_5T' 'J01_1D_6T' 'J01_2D_1T' 'J01_2D_2T' 'J01_2D_3T' 'J01_2D_4T' 'J01_2D_5T' 'J01_2D_6T' 'J01_3D_1T' 'J01_3D_2T' 'J01_3D_3T' 'J01_3D_4T' 'J01_3D_5T' 'J01_3D_6T' 'J01_4D_1T' 'J01_4D_2T' 'J01_4D_3T' 'J01_4D_4T' 'J01_4D_5T' 'J01_4D_6T' 'J05_1D_1T' 'J05_1D_2T' 'J05_1D_3T' 'J05_1D_4T' 'J05_1D_5T' 'J05_1D_6T' 'J05_2D_1T' 'J05_2D_2T' 'J05_2D_3T' 'J05_2D_4T' 'J05_2D_5T' 'J05_2D_6T' 'J05_3D_1T' 'J05_3D_2T' 'J05_3D_3T' 'J05_3D_4T' 'J05_3D_5T' 'J05_3D_6T' 'J05_4D_1T' 'J05_4D_2T' 'J05_4D_3T' 'J05_4D_4T' 'J05_4D_5T' 'J05_4D_6T' 'J06_1D_1T' 'J06_1D_2T' 'J06_1D_3T' 'J06_2D_1T' 'J06_2D_2T' 'J06_2D_3T' 'J06_3D_1T' 'J06_3D_2T' 'J06_3D_3T' 'J06_4D_1T' 'J06_4D_2T' 'J06_4D_3T' 'J12_1D_1T' 'J12_1D_2T' 'J12_1D_3T' 'J12_2D_1T' 'J12_2D_2T' 'J12_2D_3T' 'J12_3D_1T' 'J12_3D_2T' 'J12_3D_3T' 'J12_4D_1T' 'J12_4D_2T' 'J12_4D_3T' 'J14_1D_1T' 'J14_1D_2T' 'J14_1D_3T' 'J14_2D_1T' 'J14_2D_2T' 'J14_2D_3T' 'J14_3D_1T' 'J14_3D_2T' 'J14_3D_3T' 'J14_4D_1T' 'J14_4D_2T' 'J14_4D_3T' 'J18_1D_1T' 'J18_1D_2T' 'J18_1D_3T' 'J18_2D_1T' 'J18_2D_2T' 'J18_2D_3T' 'J18_3D_1T' 'J18_3D_2T' 'J18_3D_3T' 'J18_4D_1T' 'J18_4D_2T' 'J18_4D_3T' 'J19_1D_1T' 'J19_1D_2T' 'J19_1D_3T' 'J19_2D_1T' 'J19_2D_2T' 'J19_2D_3T' 'J19_3D_1T' 'J19_3D_2T' 'J19_3D_3T' 'J19_4D_1T' 'J19_4D_2T' 'J19_4D_3T' 'J20_1D_1T' 'J20_1D_2T' 'J20_1D_3T' 'J20_1D_4T' 'J20_1D_5T' 'J20_1D_6T' 'J20_2D_1T' 'J20_2D_2T' 'J20_2D_3T' 'J20_2D_4T' 'J20_2D_5T' 'J20_2D_6T' 'J20_3D_1T' 'J20_3D_2T' 'J20_3D_3T' 'J20_3D_4T' 'J20_3D_5T' 'J20_3D_6T' 'J20_4D_1T' 'J20_4D_2T' 'J20_4D_3T' 'J20_4D_4T' 'J20_4D_5T' 'J20_4D_6T' 'J21_1D_1T' 'J21_1D_2T' 'J21_1D_3T' 'J21_2D_1T' 'J21_2D_2T' 'J21_2D_3T' 'J21_3D_1T' 'J21_3D_2T' 'J21_3D_3T' 'J21_4D_1T' 'J21_4D_2T' 'J21_4D_3T' 'J23_1D_1T' 'J23_1D_2T' 'J23_1D_3T' 'J23_2D_1T' 'J23_2D_2T' 'J23_2D_3T' 'J23_3D_1T' 'J23_3D_2T' 'J23_3D_3T' 'J23_4D_1T' 'J23_4D_2T' 'J23_4D_3T' 'J24_1D_1T' 'J24_1D_2T' 'J24_1D_3T' 'J24_2D_1T' 'J24_2D_2T' 'J24_2D_3T' 'J24_3D_1T' 'J24_3D_2T' 'J24_3D_3T' 'J24_4D_1T' 'J24_4D_2T' 'J24_4D_3T' 'J25_1D_1T' 'J25_1D_2T' 'J25_1D_3T' 'J25_1D_4T' 'J25_1D_5T' 'J25_1D_6T' 'J25_2D_1T' 'J25_2D_2T' 'J25_2D_3T' 'J25_2D_4T' 'J25_2D_5T' 'J25_2D_6T' 'J25_3D_1T' 'J25_3D_2T' 'J25_3D_3T' 'J25_3D_4T' 'J25_3D_5T' 'J25_3D_6T' 'J25_4D_1T' 'J25_4D_2T' 'J25_4D_3T' 'J25_4D_4T' 'J25_4D_5T' 'J25_4D_6T' 'J30_1D_1T' 'J30_1D_2T' 'J30_1D_3T' 'J30_1D_4T' 'J30_1D_5T' 'J30_1D_6T' 'J30_2D_1T' 'J30_2D_2T' 'J30_2D_3T' 'J30_2D_4T' 'J30_2D_5T' 'J30_2D_6T' 'J30_3D_1T' 'J30_3D_2T' 'J30_3D_3T' 'J30_3D_4T' 'J30_3D_5T' 'J30_3D_6T' 'J30_4D_1T' 'J30_4D_2T' 'J30_4D_3T' 'J30_4D_4T' 'J30_4D_5T' 'J30_4D_6T' 'J52_1D_1T' 'J52_1D_2T' 'J52_1D_3T' 'J52_1D_4T' 'J52_1D_5T' 'J52_1D_6T' 'J52_2D_1T' 'J52_2D_2T' 'J52_2D_3T' 'J52_2D_4T' 'J52_2D_5T' 'J52_2D_6T' 'J52_3D_1T' 'J52_3D_2T' 'J52_3D_3T' 'J52_3D_4T' 'J52_3D_5T' 'J52_3D_6T' 'J52_4D_1T' 'J52_4D_2T' 'J52_4D_3T' 'J52_4D_4T' 'J52_4D_5T' 'J52_4D_6T' 'J53_1D_1T' 'J53_1D_2T' 'J53_1D_3T' 'J53_1D_4T' 'J53_1D_5T' 'J53_1D_6T' 'J53_2D_1T' 'J53_2D_2T' 'J53_2D_3T' 'J53_2D_4T' 'J53_2D_5T' 'J53_2D_6T' 'J53_3D_1T' 'J53_3D_2T' 'J53_3D_3T' 'J53_3D_4T' 'J53_3D_5T' 'J53_3D_6T' 'J53_4D_1T' 'J53_4D_2T' 'J53_4D_3T' 'J53_4D_4T' 'J53_4D_5T' 'J53_4D_6T' 'J54_1D_1T' 'J54_1D_2T' 'J54_1D_3T' 'J54_2D_1T' 'J54_2D_2T' 'J54_2D_3T' 'J54_3D_1T' 'J54_3D_2T' 'J54_3D_3T' 'J54_4D_1T' 'J54_4D_2T' 'J54_4D_3T' 'J55_1D_1T' 'J55_1D_2T' 'J55_1D_3T' 'J55_1D_4T' 'J55_1D_5T' 'J55_1D_6T' 'J55_2D_1T' 'J55_2D_2T' 'J55_2D_3T' 'J55_2D_4T' 'J55_2D_5T' 'J55_2D_6T' 'J55_3D_1T' 'J55_3D_2T' 'J55_3D_3T' 'J55_3D_4T' 'J55_3D_5T' 'J55_3D_6T' 'J55_4D_1T' 'J55_4D_2T' 'J55_4D_3T' 'J55_4D_4T' 'J55_4D_5T' 'J55_4D_6T' 'J56_1D_1T' 'J56_1D_2T' 'J56_1D_3T' 'J56_1D_4T' 'J56_1D_5T' 'J56_1D_6T' 'J56_2D_1T' 'J56_2D_2T' 'J56_2D_3T' 'J56_2D_4T' 'J56_2D_5T' 'J56_2D_6T' 'J56_3D_1T' 'J56_3D_2T' 'J56_3D_3T' 'J56_3D_4T' 'J56_3D_5T' 'J56_3D_6T' 'J56_4D_1T' 'J56_4D_2T' 'J56_4D_3T' 'J56_4D_4T' 'J56_4D_5T' 'J56_4D_6T' 'J57_1D_1T' 'J57_1D_2T' 'J57_1D_3T' 'J57_1D_4T' 'J57_1D_5T' 'J57_1D_6T' 'J57_2D_1T' 'J57_2D_2T' 'J57_2D_3T' 'J57_2D_4T' 'J57_2D_5T' 'J57_2D_6T' 'J57_3D_1T' 'J57_3D_2T' 'J57_3D_3T' 'J57_3D_4T' 'J57_3D_5T' 'J57_3D_6T' 'J57_4D_1T' 'J57_4D_2T' 'J57_4D_3T' 'J57_4D_4T' 'J57_4D_5T' 'J57_4D_6T' 'J58_1D_1T' 'J58_1D_2T' 'J58_1D_3T' 'J58_2D_1T' 'J58_2D_2T' 'J58_2D_3T' 'J58_3D_1T' 'J58_3D_2T' 'J58_3D_3T' 'J58_4D_1T' 'J58_4D_2T' 'J58_4D_3T' 'J59_1D_1T' 'J59_1D_2T' 'J59_1D_3T' 'J59_2D_1T' 'J59_2D_2T' 'J59_2D_3T' 'J59_3D_1T' 'J59_3D_2T' 'J59_3D_3T' 'J59_4D_1T' 'J59_4D_2T' 'J59_4D_3T' 'J61_1D_1T' 'J61_1D_2T' 'J61_1D_3T' 'J61_2D_1T' 'J61_2D_2T' 'J61_2D_3T' 'J61_3D_1T' 'J61_3D_2T' 'J61_3D_3T' 'J61_4D_1T' 'J61_4D_2T' 'J61_4D_3T'
    };
mice = { 
    'J01' 'J05' 'J06' 'J12' 'J14' 'J18' 'J19' 'J20' 'J21' 'J23' ...
    'J24' 'J25' 'J30' 'J52' 'J53' 'J54' 'J55' 'J56' 'J57' 'J58' ...
    'J59' 'J61'
    };

groups = {
    '60min' '60min' '30min' '30min' '30min' '30min' '30min' '60min' '30min' '30min' ...
    '30min' '60min' '60min' '60min' '60min' '30min' '60min' '60min' '60min' '30min' ...
    '30min' '30min'
    };
% groups = repelem(groups1, 4);

lines = {
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    'C57Bl6' 'C57Bl6'
};


% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(mice(:), groups(:), lines(:), 'VariableNames', {'mouse', 'group', 'line'});

% сессии в конкретном эксперименте
session_id = {
    '1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T' '1D_6T' ...
    '2D_1T' '2D_2T' '2D_3T' '2D_4T' '2D_5T' '2D_6T' ...
    '3D_1T' '3D_2T' '3D_3T' '3D_4T' '3D_5T' '3D_6T' ...
    '4D_1T' '4D_2T' '4D_3T' '4D_4T' '4D_5T' '4D_6T' ...
    };

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

%% collect data

for file = 1:length(FileNames)
    file
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

session_id2 = {
    '1D'     '2D'     '3D'    '4D' 
    };

for session = 1:length(session_id2)
    
%     session_idx = find(strcmp(SuperTable.TrialID, session_id2{session}));
    session_idx = find(contains(SuperTable.TrialID, session_id2{session}));
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
    
    writecell(full_table, sprintf('%s\\%s_Behavior_sorted_session.xlsx',PathOut, ExpID), 'Sheet', sprintf('%s', session_id2{session}));
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
%% paths and names

ExpID  ='NOF';
pathMat = 'w:\Projects\NOF\ActivityData\PC_mat\';
pathMatched = 'w:\Projects\NOF\ActivityData\Match\';
pathout = 'w:\Projects\NOF\ActivityData\CogMap\';

Filenames = {
    'H01' 'H02' 'H03' 'H06' 'H07' 'H08' 'H09' 'H14' 'H23' 'H26' 'H27' 'H31' 'H32' 'H33' 'H36' 'H39' ...
    };

groups = {
    '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' ...
    };

line = {
    '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' ...
    };

session_id = {'1D' '2D' '3D' '4D'};

day_count = length(session_id);
data = cell(1,day_count);
pathin = cell(1,day_count);
cells_informative = struct( ...
    'name', [], ...                                             % имя мыши
    'cells_informative_count', [], ... 
    'cells_informative_percent', [], ... 
    'matched_indeces', [], ...
  	'matched_n_cell_matched', [], ...
    'matched_inform', [], ...
   	'matched_count', [], ...
    'matched_percent', [], ...
    'intersect_indexes', [], ...                                % индексы нейронов в пересечении множеств информативных клеток (матрица сравнений)
    'intersect_count', zeros(day_count), ...                    % количество нейронов в пересечении множеств информативных клеток (матрица сравнений)
    'intersect_count_common', zeros(day_count), ...             % количество нейронов информативное между сессиями
    'intersect_percent_matched', zeros(day_count), ...         	% процент нейронов в пересечении множеств информативных клеток (от активных клеток в первый день)
    'intersect_percent_inform', zeros(day_count), ...         	% процент нейронов в пересечении множеств информативных клеток (от колва информативных клеток в эти дни)    
    'intersect_count_array', [], ...                            % количество нейронов в пересечении множеств информативных клеток (массив, порядок диагональный)
    'intersect_percent_matched_array', [], ...                	% процент нейронов в пересечении множеств информативных клеток от всех сметченных  клеток(массив, порядок диагональный)
    'intersect_percent_inform_array', [], ...                 	% процент нейронов в пересечении множеств информативных клеток от колва информативных клеток в эти дни(массив, порядок диагональный)
    ...
    'intersect_daily_indexes', [], ...                          % индексы нейронов информативные в первый день в других днях
    'intersect_daily_count', zeros(1, day_count-1), ...         % количество нейронов информативные в первый день в других днях
    'intersect_daily_percent', zeros(1, day_count-1), ...       % процент нейронов информативные в первый день в других днях (от активных клеток в первый день)
    ...
    'stability_matrix_r', [], ...                               % попарная стабильность по пирсону карт информативных нейронов (матрица)
    'stability_array_r', [] ...                                 % попарная стабильность по пирсону карт информативных нейронов (массив)
    );
%     'stability_daily_matrix', [], ...
%     'stability_daily_array', [] ...    
stability = [];

%% main part
for file = 1:length(Filenames)
    
    cells_informative(file).name = Filenames{file};
    
    % downloading data
    for day = 1:day_count
        disp([Filenames{file} '_' session_id{day}]);
        [pathin{day}] = sprintf('%s\\WorkSpace_%s_%s_%s.mat',pathMat, ExpID, Filenames{file}, session_id{day});
        [data{day}] = load(pathin{day}, 'mouse', 'cells_MI', 'cellmaps');
        cells_informative(file).cells_informative_count = [cells_informative(file).cells_informative_count data{day}.mouse.cells_informative_count];
        cells_informative(file).cells_informative_percent = [cells_informative(file).cells_informative_percent round(data{day}.mouse.cells_informative_percent)];
    end
    
    % Определение индексов сметченных информативных нейронов
    Matched.Table = table2array(readtable(sprintf('%s\\%s_%s.csv', pathMatched, ExpID, Filenames{file})));
    Matched.non_zero_rows = all(Matched.Table ~= 0, 2);
    Matched.indices_raw = find(Matched.non_zero_rows);
      
    Matched.Indeces = Matched.Table(Matched.indices_raw, :);    
    Matched.Inform_raw = cell(1,4);
    Matched.Inform = cell(1,4);
    Matched.Count = zeros(1,4);
    Matched.Percent = zeros(1,4);
    Matched.N_cell_matched = size(Matched.Indeces,1);
    for day = 1:day_count
        Matched.Inform_raw{day} = intersect(Matched.Indeces(:,day), data{day}.mouse.cells_informative);
        Matched.Count(day) = length(Matched.Inform_raw{day});
        Matched.Percent(day) = round(Matched.Count(day)/Matched.N_cell_matched*100);
        
        [~,indd,~] = intersect(Matched.Indeces(:,day), Matched.Inform_raw{1, day});
%         Matched.Inform{day} = Matched.Indeces(indd,1);
        Matched.Inform{day} = indd;
    end
    cells_informative(file).matched_indeces = Matched.Indeces;
    cells_informative(file).matched_inform = Matched.Inform;
    cells_informative(file).matched_percent = Matched.Percent;
    cells_informative(file).matched_n_cell_matched = Matched.N_cell_matched;
    cells_informative(file).matched_count = Matched.Count;
    
    % Попарное пересечение множеств ифнормативных нейронов (каждое с каждым)
    for i = 1:day_count
        for j = i:day_count
            cells_informative(file).intersect_count(i, j) = length(intersect(Matched.Inform{i}, Matched.Inform{j}));
            cells_informative(file).intersect_count(j, i) = cells_informative(file).intersect_count(i, j);
            
            cells_informative(file).intersect_indexes{i, j} = intersect(Matched.Inform{i}, Matched.Inform{j});
            cells_informative(file).intersect_indexes{j, i} = cells_informative(file).intersect_indexes{i, j};
            
            cells_informative(file).intersect_count_common(i, j) = mean([Matched.Count(i) Matched.Count(j)]);
            cells_informative(file).intersect_count_common(j, i) = cells_informative(file).intersect_count_common(i, j);
        end
    end
    cells_informative(file).intersect_percent_matched = round(cells_informative(file).intersect_count./Matched.N_cell_matched*100);    
    cells_informative(file).intersect_percent_inform = round(cells_informative(file).intersect_count./cells_informative(file).intersect_count_common*100);
        
    cells_informative(file).intersect_count_array = unfold_matrix_diagonal(cells_informative(file).intersect_count);
    cells_informative(file).intersect_percent_matched_array = unfold_matrix_diagonal(cells_informative(file).intersect_percent_matched);
    cells_informative(file).intersect_percent_inform_array = unfold_matrix_diagonal(cells_informative(file).intersect_percent_inform);
    
    % Отслеживание множества ифнормативных нейронов 1го дня (между соседними днями)
    this_indexes = Matched.Inform{1};
    for day = 1:day_count-1
        [this_indexes, ~, ~] = intersect(this_indexes, Matched.Inform{day+1});
        if ~isempty(this_indexes)
            cells_informative(file).intersect_daily_indexes{day} = this_indexes;
        else
            cells_informative(file).intersect_daily_indexes{day} = [];
        end
    end
    
    for interday = 1:length(cells_informative(file).intersect_daily_indexes)
        cells_informative(file).intersect_daily_count(interday) = length(cells_informative(file).intersect_daily_indexes{interday});
        cells_informative(file).intersect_daily_percent(interday) = round(cells_informative(file).intersect_daily_count(interday)./Matched.Count(1)*100,2);
    end
    
    % Стабильность карт информативных нейронов
    for i = 1:day_count
        for j = i:day_count
            ssim = zeros(1,length(cells_informative(file).intersect_indexes{i, j}));
            for ncell = 1:length(cells_informative(file).intersect_indexes{i, j})
                ind_row = cells_informative(file).intersect_indexes{i, j}(ncell);
                ind_i = Matched.Indeces(ind_row,i);
                ind_j = Matched.Indeces(ind_row,j);
                ssim(ncell) = computeSSIM(data{i}.cellmaps(ind_i).firingrate_smoothed, data{j}.cellmaps(ind_j).firingrate_smoothed);
                if i ~= j
                    stability = [stability ssim(ncell)];
                    nameout = sprintf('%s\\ActivityMap_%s_days_%d_%d_Cell_%d_%d.png', pathout, Filenames{file}, i, j, ind_i, ind_j);
                    days = [i, j];
%                     plotMatricesFiringRate(data{i}.cellmaps(ind_i).firingrate_smoothed, data{j}.cellmaps(ind_j).firingrate_smoothed, ind_i, ind_j, days, ssim(ncell), [], 'ssim', nameout)
                end                
            end
            cells_informative(file).stability_matrix_r(i, j) = mean(ssim);
            cells_informative(file).stability_matrix_r(j, i) = cells_informative(file).stability_matrix_r(i, j);
        end
    end
    cells_informative(file).stability_array_r = unfold_matrix_diagonal(cells_informative(file).stability_matrix_r);    
end

%% plots

mouse = data{1, 1}.mouse;

% histogram, Stability (SSIM)
h = figure('Position', mouse.params_main.Screensize);
histogram(stability, 100);
title('Histogram of cell''s Stability, SSIM', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('Stability, SSIM', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);

saveas(h, sprintf('%s\\%s_Histogram_Stability.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_Stability.fig', pathout, ExpID));
delete(h);

%% Create structure of outputs data

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
% mouse_id = sprintf('%s_%s', 'FOF',  Filenames{1});

acts = { ...
    'cells_informative_count' 'cells_informative_percent' 'matched_count' 'matched_percent' ...
    'intersect_count_array' 'intersect_percent_matched_array' 'intersect_percent_inform_array' ...
    'intersect_daily_count' 'intersect_daily_percent' 'stability_array_r'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(Filenames(:), groups(:), line(:), 'VariableNames', {'mouse', 'group', 'line'});


%% Create MAIN Big Ugly Table

% добавить все метрики актов
num_volume = 1;
for act = 1:length(acts)
    if act <= 4
        sessions = 4;
    elseif act > 4 && act <= 7
        sessions = 6;
    elseif act > 7 && act <= 9
        sessions = 3;
    else
        sessions = 6;
    end
    for session = 1:sessions
%         num_volume = (act-1)*sessions+session;
        UglyTable.Name{num_volume} = [acts{act} '_' num2str(session)];
        for mouse = 1:length(Filenames)
            session_name = [Filenames{mouse}];
            session_ind = find(strcmp({cells_informative.name}, session_name));            
            UglyTable.Data(mouse, num_volume) = cells_informative(session_ind).(acts{act})(session);

        end
        num_volume = num_volume + 1;
    end
end

% создание и сохранение итоговой таблицы
UglyTable.Table = array2table(UglyTable.Data, 'VariableNames', UglyTable.Name);
UglyTable.Table = [mice_info, UglyTable.Table];

writetable(UglyTable.Table, sprintf('%s\\%s_Stability.csv',pathout, ExpID));
save(sprintf('%s\\%s_Stability.mat', pathout, ExpID));

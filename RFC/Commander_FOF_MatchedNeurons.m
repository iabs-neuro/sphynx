%% paths and names

pathMat = 'w:\Projects\FOF\ActivityData\PC_mat\';
pathout = 'w:\Projects\FOF\ActivityData\CogMap\';


Filenames = {
    'F01' 'F05' 'F06' 'F08' 'F11' 'F12' 'F07' 'F09' 'F10' 'F14' 'F15' 'F20' ...
    'F29' 'F31' 'F34' 'F36' 'F38' 'F41' 'F53' 'F54' 'F28' 'F30' 'F35' 'F37' 'F40' 'F48' 'F52' ...
    };

groups = {
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' '5xFAD' ...
    'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    };

line = {
    'MK' 'MK' 'MK' 'MK' 'MK' 'MK' 'SAL' 'SAL' 'SAL' 'SAL' 'SAL' 'SAL' ...
    'MK' 'MK' 'MK' 'MK' 'MK' 'MK' 'MK' 'MK' 'SAL' 'SAL' 'SAL' 'SAL' 'SAL' 'SAL' 'SAL'
    };

session_id = {'1D' '2D' '3D'};

pathin = {};
data = {};
day_count = length(session_id);
cells_informative = struct( ...
    'name', [], ...                                             % имя мыши
    'intersect_indexes', [], ...                                % индексы нейронов в пересечении множеств информативных клеток (матрица сравнений)
    'intersect_count', zeros(day_count, day_count), ...         % количество нейронов в пересечении множеств информативных клеток (матрица сравнений)
    'intersect_percent', zeros(day_count, day_count), ...       % процент нейронов в пересечении множеств информативных клеток (от активных клеток в первый день)
    'intersect_count_array', [], ...                            % количество нейронов в пересечении множеств информативных клеток (массив, порядок диагональный)
    'intersect_percent_array', [], ...                          % процент нейронов в пересечении множеств информативных клеток (массив, порядок диагональный)
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

%% main part
for file = 1:length(Filenames)
    
    cells_informative(file).name = Filenames{file};
    % downloading data
    for day = 1:day_count
        disp([Filenames{file}]);
        pathin{day} = sprintf('%s\\WorkSpace_FOF_%s_%s.mat',pathMat, Filenames{file}, session_id{day});
        [data{day}] = load(pathin{day}, 'mouse', 'Cell_IC', 'cellmaps');
    end
    
    % Попарное пересечение множеств ифнормативных нейронов (каждое с каждым)
    for i = 1:day_count
        for j = i:day_count
            cells_informative(file).intersect_count(i, j) = length(intersect(data{i}.mouse.cells_informative, data{j}.mouse.cells_informative));
            cells_informative(file).intersect_count(j, i) = cells_informative(file).intersect_count(i, j);
            
            cells_informative(file).intersect_indexes{i, j} = intersect(data{i}.mouse.cells_informative, data{j}.mouse.cells_informative);
            cells_informative(file).intersect_indexes{j, i} = cells_informative(file).intersect_indexes{i, j};
        end
    end
    cells_informative(file).intersect_percent = round(cells_informative(file).intersect_count./data{1}.mouse.cells_active_count*100,2);
    
    cells_informative(file).intersect_count_array = unfold_matrix_diagonal(cells_informative(file).intersect_count);
    cells_informative(file).intersect_percent_array = unfold_matrix_diagonal(cells_informative(file).intersect_percent);
    
    % Отслеживание множества ифнормативных нейронов 1го дня (между соседними днями)
    this_indexes = data{1}.mouse.cells_informative;
    for day = 1:day_count-1
        [a, ~, this_indexes] = intersect(this_indexes, data{day+1}.mouse.cells_informative);
        if ~isempty(a)
            cells_informative(file).intersect_daily_indexes{day} = a;
        else
            cells_informative(file).intersect_daily_indexes{day} = [];
        end
    end
    
    for interday = 1:length(cells_informative(file).intersect_daily_indexes)
        cells_informative(file).intersect_daily_count(interday) = length(cells_informative(file).intersect_daily_indexes{interday});
        cells_informative(file).intersect_daily_percent(interday) = round(cells_informative(file).intersect_daily_count(interday)./data{1}.mouse.cells_active_count*100,2);
    end
    
    % Стабильность карт информативных нейронов
    for i = 1:day_count
        for j = i:day_count
            r = zeros(1,length(cells_informative(file).intersect_indexes{i, j}));
            p = zeros(1,length(cells_informative(file).intersect_indexes{i, j}));
            for ncell = 1:length(cells_informative(file).intersect_indexes{i, j})
                ind = cells_informative(file).intersect_indexes{i, j}(ncell);
                [r(ncell), p(ncell)] = computePearsonCorrelation(data{i}.cellmaps(ind).firingrate, data{j}.cellmaps(ind).firingrate);
                if i ~= j
                    nameout = sprintf('%s\\ActivityMap_%s_Cell_%d.png', pathout, Filenames{file}, ind);
                    days = [i, j];
%                     plotMatricesFiringRate(data{i}.cellmaps(ind).firingrate, data{j}.cellmaps(ind).firingrate, ind, days, r(ncell), p(ncell), nameout)
                end
            end
            cells_informative(file).stability_matrix_r(i, j) = mean(r(p<0.05 & r>0));
            cells_informative(file).stability_matrix_r(j, i) = cells_informative(file).stability_matrix_r(i, j);
        end
    end
    cells_informative(file).stability_array_r = unfold_matrix_diagonal(cells_informative(file).stability_matrix_r);    
end

%% Create structure of outputs data

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
% mouse_id = sprintf('%s_%s', 'FOF',  Filenames{1});

acts = {'intersect_count_array' 'intersect_percent_array' 'intersect_daily_count' 'intersect_daily_percent' 'stability_array_r'};

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(Filenames(:), groups(:), line(:), 'VariableNames', {'mouse', 'group', 'line'});


%% Create MAIN Big Ugly Table

% добавить все метрики актов
num_volume = 1;
for act = 1:length(acts)
    if act == 3 || act == 4
        sessions = 2;
    else
        sessions = 3;
    end
    for session = 1:sessions
%         num_volume = (act-1)*sessions+session;
        UglyTable.Name{num_volume} = [acts{act} '_' session];
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
ExpID = 'FOF';
writetable(UglyTable.Table, sprintf('%s\\%s_PlaceCellsStability.csv',pathout, ExpID));
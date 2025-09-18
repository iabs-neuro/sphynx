%% paths and names

ExpID  ='MSS';
pathMat = 'w:\Projects\MSS\ActivityData\MAT_PC\';
pathout = 'w:\Projects\MSS\ActivityData\Results_paper\CogMaps\';
path_trace = 'TraceMaps';
path_trace_all = 'TraceMapsAllDays';

mkdir(pathout, path_trace);
mkdir(pathout, path_trace_all);

% all mice
% Filenames_main = {
%     {'F08' 'F11' 'F14'},        {'F26' 'F28' 'F31' 'F35' 'F36' 'F37' 'H31'}, ...
%     {'F01' 'F04' 'F09' 'F12'},  {'F29' 'F38' 'F40' 'F48' 'F52' 'H27' 'H32'}, ...
%     {'F05' 'F15' 'F20'},        {'F30' 'F34' 'F43' 'F53' 'F54' 'H26' 'H33'}
%     };
% 
% groups_main = {
%     {'Single' 'Single' 'Single'},           {'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single'}, ...
%     {'Spaced' 'Spaced' 'Spaced' 'Spaced'},  {'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced'}, ...
%     {'Massed' 'Massed' 'Massed'},           {'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed'} ...
%     };
% 
% line_main = {
%     {'5xFAD' '5xFAD' '5xFAD'},              {'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6'}, ...
%     {'5xFAD' '5xFAD' '5xFAD' '5xFAD'},      {'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6'}, ...
%     {'5xFAD' '5xFAD' '5xFAD'},              {'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6'} ...
%     };

% для анализа с исключенными мышами
Filenames_main = {
    {'F08' 'F11' 'F14'},        {      'F28'       'F35' 'F36' 'F37' 	  }, ...
    {      'F04' 'F09' 'F12'},  {            'F40'       'F52' 'H27' 'H32'}, ...
    {'F05' 'F15' 'F20'},        {'F30'                         'H26' 'H33'}
    };

groups_main = {
    {'Single' 'Single' 'Single'},           {         'Single'          'Single' 'Single' 'Single'         }, ...
    {         'Spaced' 'Spaced' 'Spaced'},  {                  'Spaced'          'Spaced' 'Spaced' 'Spaced'}, ...
    {'Massed' 'Massed' 'Massed'},           {'Massed'                                     'Massed' 'Massed'} ...
    };

line_main = {
    {'5xFAD' '5xFAD' '5xFAD'},              {         'C57Bl6'          'C57Bl6' 'C57Bl6' 'C57Bl6'         }, ...
    {        '5xFAD' '5xFAD' '5xFAD'},      {                  'C57Bl6'          'C57Bl6' 'C57Bl6' 'C57Bl6'}, ...
    {'5xFAD' '5xFAD' '5xFAD'},              {'C57Bl6'                                     'C57Bl6' 'C57Bl6'} ...
    };

session_id_main = {
    {'1D_1T' '1D_1T' '1D_1T' '1D_1T' '1D_1T'},  {'1D_1T' '1D_1T' '1D_1T' '1D_1T' '1D_1T'}, ...
    {'1D_1T' '2D_1T' '3D_1T' '4D_1T' '5D_1T'},  {'1D_1T' '2D_1T' '3D_1T' '4D_1T' '5D_1T'}, ...
    {'1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T'},  {'1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T'} ...
    };

session_id_plot_main = {
    {'1P' '2P' '3P' '4P' '5P'},  {'1P' '2P' '3P' '4P' '5P'}, ...
    {'1D' '2D' '3D' '4D' '5D'},  {'1D' '2D' '3D' '4D' '5D'}, ...
    {'1T' '2T' '3T' '4T' '5T'},  {'1T' '2T' '3T' '4T' '5T'} ...
    };

% params for correction TraceMaps
method = 'gaussian'; % or you can use 'median_noise'
noise_level = 0.1;
kernel_size = 5;
sigma = 1;
visual = 0;

ssim_thrs = 0.5;
ssim_mean_thrs = 0.3;
ssim_chance_lvl = 0.2;

mice_informative = struct( ...
   	'group', [], ...                                           	% группа мыши
    'line', [], ...                                             % линия мыши  
    'cells_informative', [], ...                                % информация помышно
    'locomotion_percent', [], ...                               % процент времени сессии на побежки
    'space_explored', [], ...                                   % процент облследованного пространства   
  	'active_count', [], ...                                 	% количество нейронов активных во все сессии теста (посадки)
   	'PC_count', [], ...                                         % количество клеток места
    'PC_ssim_mean', [], ...                                     % средний ssim клеток места
    'PC_percent', [], ...                                       % процент клеток места
    'CorrMatrix', [], ...                                      	% массив матриц корреляций помышно
    'stability', [], ...                                       	% попарная (каждый с каждым днем) стабильность карт активности нейронов
    'SSIM', [], ...                                             % 
    'SSIM_mean', [] ...                                       	% 
    );


%% main part
for group_id = 1:length(Filenames_main)
% for group_id = 1:2

cells_informative = struct( ...
    'name', [], ...                                             % имя мыши
    'group', [], ...                                           	% группа мыши
    'line', [], ...                                             % линия мыши    
    'locomotion_percent', [], ...                               % процент времени сессии на побежки
    'space_explored', [], ...                                   % процент облследованного пространства
    'occup_maps', [], ...                                       % карты размещения животного
    'intersect_active', [], ...                                 % индексы нейронов активных во все сессии
    'intersect_active_count', [], ...                        	% количество нейронов активных во все сессии
    'similarity', [], ...                                       % индекс схожести попарно между днями (1-2,2-3,3-4,4-5)
    'similarity_mean', [], ...                                  % среднее индексов схожести попарно между днями
    'similarity_mean_days', [], ...                            	% среднее индексов схожести попарно между нейронами
    'PC_ssim', [], ...                                          % ssim клеток места
    'PC_count', [], ...                                         % количество клеток места
    'PC_ssim_mean', [], ...                                     % средний ssim клеток места
    'PC_percent', [], ...                                       % процент клеток места
    ...
    'intersect_indexes', [], ...                                % индексы нейронов в пересечении множеств информативных клеток (матрица сравнений)
    'intersect_count', [], ...                                  % количество нейронов в пересечении множеств информативных клеток (матрица сравнений)
    'intersect_percent', [], ...                                % процент нейронов в пересечении множеств информативных клеток (от активных клеток в первый день)
    'intersect_count_array', [], ...                            % количество нейронов в пересечении множеств информативных клеток (массив, порядок диагональный)
    'intersect_percent_array', [], ...                          % процент нейронов в пересечении множеств информативных клеток (массив, порядок диагональный)
    ...
    'stability_matrix_r', [], ...                               % попарная значимая стабильность по пирсону карт информативных нейронов (матрица)
    'stability_array_r', [] ...                                 % попарная стабильность по пирсону карт информативных нейронов (массив)
    );

Filenames = Filenames_main{group_id};
groups = groups_main{group_id};
line = line_main{group_id};
session_id = session_id_main{group_id};
session_id_plot = session_id_plot_main{group_id};

% var
pathin = {};
data = {};
day_count = length(session_id);

CorrMatrix = zeros(day_count, day_count, length(Filenames));
stability = [];
SSIM = [];
SSIM_mean = [];
SSIM_mean_days = [];

for file = 1:length(Filenames)
    
    %% downloading data
    
    SpaceMaps = {};
    cells_informative(file).name = Filenames{file};
    cells_informative(file).group = groups{file};
    cells_informative(file).line = line{file};
    for day = 1:day_count
        
        disp([Filenames{file}]);
        pathin{day} = sprintf('%s\\WorkSpace_MSS_%s_%s.mat',pathMat, Filenames{file}, session_id{day});
        [data{day}] = load(pathin{day}, 'mouse', 'cells_MI', 'cellmaps', 'cells');
        mouse = data{1, 1}.mouse;
        if all(cells_informative(file).group == 'Single')
            
            % подсчитать процент побежек в сплите сессии                       
            for split = 1 : mouse.params_main.activity_map_split                
                cells_informative(file).locomotion_percent(split) = round(sum(mouse.velocity_binary(mouse.split_frames{split}))/mouse.framerate/mouse.params_main.MinTime/(length(mouse.split_frames{split})/mouse.framerate/mouse.params_main.MinTime)*100,2);                
                cells_informative(file).space_explored(split) = min(100, round(length(find(mouse.occupancy_map.frame_split{split}>mouse.params_main.time_min*mouse.framerate))*mouse.params_main.bin_size_cm^2/mouse.behav_opt.arena_area*100,1));
            end            
            SpaceMaps{day} = correct_trace_map(mouse.occupancy_map.frame_split{day}, method, noise_level, kernel_size, sigma, visual);    
        else            
            cells_informative(file).space_explored(day) = data{day}.mouse.space_explored;
            cells_informative(file).locomotion_percent(day) = data{day}.mouse.locomotion_percent;
            SpaceMaps{day} = correct_trace_map(data{day}.mouse.occupancy_map.time_smoothed_min, method, noise_level, kernel_size, sigma, visual);    
        end
   	end
    cells_informative(file).occup_maps = SpaceMaps;
  
    %% стабильность между всеми днями
    
    % Поиск активных нейронов
    for i = 1:day_count
        for j = i:day_count
            cells_informative(file).intersect_count(i, j) = length(intersect(data{i}.mouse.cells_active, data{j}.mouse.cells_active));
            cells_informative(file).intersect_count(j, i) = cells_informative(file).intersect_count(i, j);
            
            cells_informative(file).intersect_indexes{i, j} = intersect(data{i}.mouse.cells_active, data{j}.mouse.cells_active);
            cells_informative(file).intersect_indexes{j, i} = cells_informative(file).intersect_indexes{i, j};
        end
    end
    cells_informative(file).intersect_percent = round(cells_informative(file).intersect_count./data{1, 1}.mouse.cells_count*100,1);
    cells_informative(file).intersect_count_array = unfold_matrix_diagonal(cells_informative(file).intersect_count);
    cells_informative(file).intersect_percent_array = unfold_matrix_diagonal(cells_informative(file).intersect_percent);
    
    % Стабильность карт нейронов между днями
    ssim_this = [];
    for i = 1:day_count
        for j = i:day_count
            ssim = zeros(1,length(cells_informative(file).intersect_indexes{i, j}));
            for ncell = 1:length(cells_informative(file).intersect_indexes{i, j})
                ind = cells_informative(file).intersect_indexes{i, j}(ncell);
                
                % откорректировать карты активности для корректного расчета метрики
                if all(cells_informative(file).group == 'Single')
                    TraceMap1 = correct_trace_map(data{i}.cellmaps(ind).trace_split_smoothed{i}, method, noise_level, kernel_size, sigma, visual);
                    TraceMap2 = correct_trace_map(data{j}.cellmaps(ind).trace_split_smoothed{j}, method, noise_level, kernel_size, sigma, visual);                                    
                else
                    TraceMap1 = correct_trace_map(data{i}.cellmaps(ind).trace_refined, method, noise_level, kernel_size, sigma, visual);
                    TraceMap2 = correct_trace_map(data{j}.cellmaps(ind).trace_refined, method, noise_level, kernel_size, sigma, visual);
                end
                
                ssim(ncell) = computeSSIM(TraceMap1, TraceMap2);
                
                if isnan(ssim(ncell))
                    ssim(ncell) = ssim_chance_lvl;
                end
                
%                 if i ~= j
%                     ssim_this = [ssim_this ssim(ncell)];
%                     if ssim(ncell)>ssim_thrs
%                         days = [i, j];
%                         nameout = sprintf('%s\\%s\\ActivityMap_%s_%s_%s_Cell_%d_days_%d_%d.png', pathout, path_trace, groups{file}, line{file}, Filenames{file}, ind, days);
%                        	plotMatricesFiringRate(TraceMap1, TraceMap2, ind, ind, days, ssim(ncell), [], 'ssim', nameout);
%                     end
%                 end
            end
%             ssim_this = ssim_this(~isnan(ssim_this));
            stability = [stability ssim_this];
            cells_informative(file).stability_matrix_r(i, j) = mean(ssim);
            cells_informative(file).stability_matrix_r(j, i) = cells_informative(file).stability_matrix_r(i, j);
        end
    end
    cells_informative(file).stability_array_r = unfold_matrix_diagonal(cells_informative(file).stability_matrix_r);
    
    % построение матрицы корреляций
    name_title = sprintf('Correlation matrix across days\n%s\\_%s\\_%s\\_%s', ExpID, groups{file}, line{file}, Filenames{file});
    nameout = sprintf('%s\\%s_%s_%s_CorrMap_SSIM.png', pathout, groups{file}, line{file}, Filenames{file});
    plot_correlation_matrix_color(cells_informative(file).stability_matrix_r, session_id_plot,  'zero_to_one', name_title, nameout);    
    
    CorrMatrix(:,:,file) = cells_informative(file).stability_matrix_r;

    %% стабильность понейронно
    days = 1:day_count;
    
    % поиск нейронов активных во все сесссии    
    cells_informative(file).intersect_active = data{1}.mouse.cells_active;
    SpaceSSIM = zeros(1,day_count-1);
    for day = 2:day_count
        cells_informative(file).intersect_active = intersect(cells_informative(file).intersect_active, data{day}.mouse.cells_active);
        % коррелцяи карты посещений
        SpaceSSIM(day-1) = computeSSIM(SpaceMaps{day-1}, SpaceMaps{day});
    end
    cells_informative(file).intersect_active_count = length(cells_informative(file).intersect_active);
    
    % Стабильность карт нейронов между соседними днями
    ssim_neurons = zeros(cells_informative(file).intersect_active_count, day_count-1);
    for ncell = 1:cells_informative(file).intersect_active_count
        
        % создание скорректированной карты активности на каждый день
        TraceMaps = {};
        for day = 1:day_count
            ind = cells_informative(file).intersect_active(ncell);
            if all(cells_informative(file).group == 'Single')
                TraceMaps{day} = correct_trace_map(data{day}.cellmaps(ind).trace_split_smoothed{day}, method, noise_level, kernel_size, sigma, visual);
            else
                TraceMaps{day} = correct_trace_map(data{day}.cellmaps(ind).trace_refined, method, noise_level, kernel_size, sigma, visual);
            end
        end
        
        % расчет метрики схожести карт активности нейрона между сессиями
        for day = 1:day_count-1
            ssim_neurons(ncell, day) = computeSSIM(TraceMaps{day}, TraceMaps{day+1});
        end        
        
        if mean(ssim_neurons(ncell,:))>ssim_mean_thrs
            % построение карт активности нейрона
            nameout = sprintf('%s\\%s\\ActivityMap_%s_%s_%s_Cell_%d.png', pathout, path_trace_all, groups{file}, line{file}, Filenames{file}, ind);        
            days = 1:day_count;
            indx = ones(1,day_count)*ind;
            plotMatricesTraceRate(TraceMaps, indx, days, 'ssim', ssim_neurons(ncell,:), nameout);
        end
        
    end
    
    % построить карту размещений во всех сессиях
    nameout = sprintf('%s\\%s_%s_%s_occupancy_map.png', pathout, groups{file}, line{file}, Filenames{file});
    plotMatricesTraceRate(SpaceMaps, [1 1 1 1 1], days, 'ssim', SpaceSSIM, nameout);
    
    % построить график процента побежек и посещенного пространства
    h = figure('Position', mouse.params_main.Screensize);
    plot(cells_informative(file).locomotion_percent, 'b', 'LineWidth', 3, 'MarkerSize', 8);hold on;
    plot(cells_informative(file).space_explored, 'r', 'LineWidth', 3, 'MarkerSize', 8);    
    title('Исследовательская активность', 'FontSize', mouse.params_main.FontSizeTitle);
    xlabel('Дни', 'FontSize', mouse.params_main.FontSizeLabel);
    ylabel('Процент', 'FontSize', mouse.params_main.FontSizeLabel);
    legend({'Процент побежек', 'Процент обследованного пространства'});
    set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
    ylim([0 100]); % Фиксируем ось Y от 0 до 100
    xlim([1 length(cells_informative(file).locomotion_percent)]); % Автомасштабирование по X
    xticks(1:length(cells_informative(file).locomotion_percent)); % Делаем деления оси X целыми числами
    grid on; % Включаем сетку (опционально)

    saveas(h, sprintf('%s\\%s_%s_%s_behavior_activity.png', pathout, groups{file}, line{file}, Filenames{file}));
    delete(h);
    
    % построить график стабильности
    ssim_neurons(isnan(ssim_neurons)) = ssim_chance_lvl;
    rows_with_zeros = any(ssim_neurons == 0, 2);
    ssim_neurons_clear = ssim_neurons(~rows_with_zeros, :);
    cells_informative(file).similarity = ssim_neurons_clear;
    
    nameout = sprintf('%s\\%s_%s_%s_SSIM_neurons.png', pathout, groups{file}, line{file}, Filenames{file});
    plot_ssim_comparisons(ssim_neurons, nameout);
    
    nameout = sprintf('%s\\%s_%s_%s_SSIM_neurons_cleared.png', pathout, groups{file}, line{file}, Filenames{file});
    mean_ssim = plot_ssim_comparisons(ssim_neurons_clear, nameout);
    cells_informative(file).similarity_mean_days = mean_ssim;
    SSIM_mean_days(file,:) = mean_ssim;
    
    % расчет среднего ssim нейронно
    ssim_mean = mean(ssim_neurons_clear,2);
    cells_informative(file).similarity_mean = ssim_mean;
    
    % определение "клеток места"
    cells_informative(file).PC_ssim = cells_informative(file).similarity_mean(cells_informative(file).similarity_mean>ssim_mean_thrs);
    cells_informative(file).PC_count = length(cells_informative(file).PC_ssim);
    cells_informative(file).PC_percent = round(cells_informative(file).PC_count/cells_informative(file).intersect_active_count*100,2);
    cells_informative(file).PC_ssim_mean = mean(cells_informative(file).PC_ssim);    
    
    h = figure('Position', mouse.params_main.Screensize);
    histogram(cells_informative(file).similarity_mean, 20);
    title('Histogram of mean (across sessions) cell''s Stability, SSIM', 'FontSize', mouse.params_main.FontSizeTitle);
    xlabel('Stability, SSIM', 'FontSize', mouse.params_main.FontSizeLabel);
    ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
    set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
    xlim([0 1]); grid on;
    
    saveas(h, sprintf('%s\\%s_%s_%s_histogram_SSIM_neurons_mean.png', pathout, groups{file}, line{file}, Filenames{file}));
    delete(h);
    
    SSIM = [SSIM; ssim_neurons_clear];
    SSIM_mean = [SSIM_mean; ssim_mean];
    
end

mice_informative(group_id).group = groups{1};
mice_informative(group_id).line = line{1};
mice_informative(group_id).cells_informative = cells_informative;
for file = 1:length(Filenames)
    mice_informative(group_id).locomotion_percent(file,:) = cells_informative(file).locomotion_percent;
    mice_informative(group_id).space_explored(file,:) = cells_informative(file).space_explored;
    mice_informative(group_id).active_count(file,:) = cells_informative(file).intersect_active_count;

    mice_informative(group_id).PC_count(file,:) = cells_informative(file).PC_count;
    mice_informative(group_id).PC_percent(file,:) = cells_informative(file).PC_percent;
    mice_informative(group_id).PC_ssim_mean(file,:) = cells_informative(file).PC_ssim_mean;
    
end
mice_informative(group_id).CorrMatrix = CorrMatrix;
mice_informative(group_id).stability = stability;
mice_informative(group_id).SSIM = SSIM;
mice_informative(group_id).SSIM_mean = SSIM_mean;
mice_informative(group_id).SSIM_mean_days = SSIM_mean_days;

% plot for correlation matrix for whole group
name_title = sprintf('Correlation matrix across days\n%s\\_%s\\_%s', ExpID, groups{file}, line{file});
nameout = sprintf('%s\\%s_%s_CorrMap_SSIM.png', pathout, groups{file}, line{file});
plot_correlation_matrix_color(mean(CorrMatrix,3), session_id_plot,  'zero_to_one', name_title, nameout);

% plot for stability (SSIM) for whole group
h = figure('Position', mouse.params_main.Screensize);
histogram(stability, 100);

title(sprintf('Histogram of cell''s stability, SSIM\n%s\\_%s\\_%s', ExpID, groups{file}, line{file}), 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('Stability, SSIM', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
xlim([0 1]); grid on;

saveas(h, sprintf('%s\\%s_%s_Histogram_Stability.png', pathout, groups{file}, line{file}));
delete(h);

% plot for stability (SSIM) for whole group across sessions
h = figure('Position', mouse.params_main.Screensize);
histogram(SSIM_mean, 100);

title(sprintf('Histogram of cell''s stability, SSIM across days\n%s\\_%s\\_%s', ExpID, groups{file}, line{file}), 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('Stability, SSIM', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);

saveas(h, sprintf('%s\\%s_%s_Histogram_SSIM_mean.png', pathout, groups{file}, line{file}));
delete(h);

% построить гистограмму всех нейронов от всех мышей группы
nameout = sprintf('%s\\%s_%s_SSIM_neurons_all.png', pathout, groups{file}, line{file});
plot_ssim_comparisons(SSIM, nameout);

% построить гистограмму средней похожести нейронов для группы
nameout = sprintf('%s\\%s_%s_SSIM_neurons.png', pathout, groups{file}, line{file});
plot_ssim_comparisons(mice_informative(group_id).SSIM_mean_days, nameout);
    
end

save(sprintf('%s\\MSS_train_result.mat',pathout));

% %% Create structure of outputs data
% 
% % узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% % для этого берем набор актов из например первой мышесессии
% % mouse_id = sprintf('%s_%s', 'FOF',  Filenames{1});
% 
% acts = {'intersect_count_array' 'intersect_percent_array' 'intersect_daily_count' 'intersect_daily_percent' 'stability_array_r'};
% 
% % создание столбцов с id мышей и группой (и линией) в начале таблицы
% mice_info = table(Filenames(:), groups(:), line(:), 'VariableNames', {'mouse', 'group', 'line'});
% 

% %% Create MAIN Big Ugly Table
% 
% % добавить все метрики актов
% num_volume = 1;
% for act = 1:length(acts)
%     if act == 3 || act == 4
%         sessions = 2;
%     else
%         sessions = 3;
%     end
%     for session = 1:sessions
%         %         num_volume = (act-1)*sessions+session;
%         UglyTable.Name{num_volume} = [acts{act} '_' session];
%         for mouse = 1:length(Filenames)
%             
%             session_name = [Filenames{mouse}];
%             session_ind = find(strcmp({cells_informative.name}, session_name));
%             
%             UglyTable.Data(mouse, num_volume) = cells_informative(session_ind).(acts{act})(session);
%             
%         end
%         num_volume = num_volume + 1;
%     end
%     
% end
% 
% % создание и сохранение итоговой таблицы
% UglyTable.Table = array2table(UglyTable.Data, 'VariableNames', UglyTable.Name);
% UglyTable.Table = [mice_info, UglyTable.Table];
% 
% writetable(UglyTable.Table, sprintf('%s\\%s_PlaceCellsStability.csv',pathout, ExpID));

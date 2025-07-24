%% paths and names

ExpID  ='NOF';
pathMat = 'w:\Projects\NOF\ActivityData\PC_mat\';
pathout = 'w:\Projects\NOF\ActivityData\';

FileNames = {
    'H01_1D','H02_1D','H03_1D','H06_1D','H07_1D','H08_1D','H09_1D','H14_1D','H23_1D',...
    'H26_1D','H27_1D','H31_1D','H32_1D','H33_1D','H36_1D','H39_1D',...
    'H01_2D','H02_2D','H03_2D','H06_2D','H07_2D','H08_2D','H09_2D','H14_2D','H23_2D'...
    'H26_2D','H27_2D','H31_2D','H32_2D','H33_2D','H36_2D','H39_2D',...
    'H01_3D','H02_3D','H03_3D','H06_3D','H07_3D','H08_3D','H09_3D','H14_3D','H23_3D',...
    'H26_3D','H27_3D','H31_3D','H32_3D','H33_3D','H36_3D','H39_3D',...
    'H01_4D','H02_4D','H03_4D','H06_4D','H07_4D','H08_4D','H09_4D','H14_4D','H23_4D',...
    'H26_4D','H27_4D','H31_4D','H32_4D','H33_4D','H36_4D','H39_4D',...
    };

micename = {
    'H01' 'H02' 'H03' 'H06' 'H07' 'H08' 'H09' 'H14' 'H23' 'H26' 'H27' 'H31' 'H32' 'H33' 'H36' 'H39' ...
    };

groups = {
    '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' ...
    };

line = {
    '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' ...
    };

session_id = {'1D' '2D' '3D' '4D'};

% local parameters
center = 16;

%% variables

mice = struct( ...
    ...
    'name', '', ...                                                     - полное имя мышесессии
    'exp', '', ...                                                      - experiment identifier (e.g. 'FOF', 'NOF', '3DM')
    'group', '', ...                                                    - experimental group of animal (e.g. 'Control', 'FAD')
    'id', '', ...                                                       - mouse identifier (e.g. 'F01', 'H39')
    'day', '', ...                                                      - day number of registration (e.g. '1D', '6D')
    'trial', '', ...                                                    - trial number of registration (e.g. '1T', '6T')
    ...
    'duration_s', zeros(1,length(FileNames)), ...
    'framerate', zeros(1,length(FileNames)), ...
    'size_map', [], ...
    'xkcorr', zeros(1,length(FileNames)), ...
    ...
    'cells_count', zeros(1,length(FileNames)), ...                   	- всего нейронов
    'cells_active_count', zeros(1,length(FileNames)), ...            	- количество активных нейронов
    'cells_active_percent', zeros(1,length(FileNames)), ...             - процент активных нейронов
    'cells_active_firingrate', [], ...                                	- гистограмма частоты кальциевых событий в минуту активных нейронов
    'cells_active_firingrate_mean', zeros(1,length(FileNames)), ...   	- частота кальциевых событий в минуту активных нейронов
    'cells_active_MI_bit_event', [], ...                               	- гистограмма для MI активных нейронов (bit/Ca2+)
    'cells_active_MI_bit_time', [], ...                                	- гистограмма для MI активных нейронов (bit/min)
    'cells_active_MI_zscored', [], ...                              	- гистограмма для MI активных нейронов (z-scored)
    'cells_active_MI_bit_event_mean', zeros(1,length(FileNames)), ...  	- среднее значение MI активных нейронов (bit/Ca2+)
    'cells_active_MI_bit_time_mean', zeros(1,length(FileNames)), ...   	- среднее значение MI активных нейронов (bit/min)
    'cells_active_MI_zscored_mean', zeros(1,length(FileNames)), ...     - среднее значение MI активных нейронов (z-scored)
    ...
    'space_explored', zeros(1,length(FileNames)), ...                   - процент исследованного пространства
    ...
    'cells_informative_count', zeros(1,length(FileNames)), ...       	- количество информативных клеток
    'cells_informative_percent', zeros(1,length(FileNames)), ...       	- процент инормативных клеток от числа активных
    ...
    'cells_informative_MI_bit_event', [], ...                        	- гистограмма для MI всех активных нейронов (bit/Ca2+)
    'cells_informative_MI_bit_time', [], ...                           	- гистограмма для MI всех активных нейронов (bit/min)
    'cells_informative_MI_zscored', [], ...                          	- гистограмма для MI информативных нейронов (z-scored)
    ...
    'cells_informative_MI_bit_event_mean', zeros(1,length(FileNames)), ...  	- среднее значение MI для информативных клеток (bit/Ca2+)
    'cells_informative_MI_bit_time_mean', zeros(1,length(FileNames)), ...       - среднее значение MI для информативных клеток (bit/min)
    'cells_informative_MI_zscored_mean', zeros(1,length(FileNames)) ...        - среднее значение MI для информативных клеток (z-scored)
    );

%% main part
cells_active_firingrate = [];
cells_active_MI_bit_event  = []; 
cells_active_MI_bit_time  = [];
cells_active_MI_zscored = [];
cells_informative_MI_bit_event =[];
cells_informative_MI_bit_time = []; 
cells_informative_MI_zscored = [];
mice_active_indx = [];

for file = 1:length(FileNames)
    disp(FileNames{file});
    
    pathin = sprintf('%s\\WorkSpace_%s_%s.mat', pathMat, ExpID, FileNames{file});
    load(pathin, 'mouse');
    
    % defining struct
    mice(file).name = FileNames{file};
    mice(file).exp = mouse.exp;
    mice(file).group = mouse.group;
    mice(file).id = mouse.id;
    mice(file).day = mouse.day;
    mice(file).trial = mouse.trial;
    
    % check
    mice(file).size_map = mouse.size_map;
    mice(file).xkcorr = mouse.behav_opt.x_kcorr;
    mice(file).duration_s = mouse.duration_s;
    mice(file).framerate = mouse.framerate;
    
    mice(file).space_explored = mouse.space_explored;
    
    mice(file).cells_count = mouse.cells_count;
    mice(file).cells_active_count = mouse.cells_active_count;
    mice(file).cells_active_percent = mouse.cells_active_percent;
    mice(file).cells_active_firingrate = mouse.cells_active_firingrate;
    mice(file).cells_active_firingrate_mean = mouse.cells_active_firingrate_mean;
    
    mice(file).cells_active_MI_bit_event = mouse.cells_active_MI_bit_event;
    mice(file).cells_active_MI_bit_time = mouse.cells_active_MI_bit_time;
    mice(file).cells_active_MI_zscored = mouse.cells_active_MI_zscored;
    
    mice(file).cells_active_MI_bit_event_mean = mouse.cells_active_MI_bit_event_mean;
    mice(file).cells_active_MI_bit_time_mean = mouse.cells_active_MI_bit_time_mean;
    mice(file).cells_active_MI_zscored_mean = mouse.cells_active_MI_zscored_mean;
    
    mice(file).cells_informative_count = mouse.cells_informative_count;
    mice(file).cells_informative_percent = mouse.cells_informative_percent;
    
    mice(file).cells_informative_MI_bit_event = mouse.cells_informative_MI_bit_event;
    mice(file).cells_informative_MI_bit_time = mouse.cells_informative_MI_bit_time;
    mice(file).cells_informative_MI_zscored = mouse.cells_informative_MI_zscored;
    
    mice(file).cells_informative_MI_bit_event_mean = mouse.cells_informative_MI_bit_event_mean;
    mice(file).cells_informative_MI_bit_time_mean = mouse.cells_informative_MI_bit_time_mean;
    mice(file).cells_informative_MI_zscored_mean = mouse.cells_informative_MI_zscored_mean;
    
    cells_active_firingrate = [cells_active_firingrate mouse.cells_active_firingrate];
    cells_active_MI_bit_event  = [cells_active_MI_bit_event  mouse.cells_active_MI_bit_event];
    cells_active_MI_bit_time  = [cells_active_MI_bit_time  mouse.cells_active_MI_bit_time];
    cells_active_MI_zscored = [cells_active_MI_zscored mouse.cells_active_MI_zscored];
    cells_informative_MI_bit_event =[cells_informative_MI_bit_event  mouse.cells_informative_MI_bit_event];
    cells_informative_MI_bit_time = [cells_informative_MI_bit_time  mouse.cells_informative_MI_bit_time];
    cells_informative_MI_zscored = [cells_informative_MI_zscored mouse.cells_informative_MI_zscored];
    
end

save(sprintf('%s\\%s_PC.mat', pathout, ExpID));

%% plots

% histogram, FiringRate (Ca2+/min)
h = figure('Position', mouse.params_main.Screensize);
histogram(cells_active_firingrate, 200);
title('Histogram of cell''s FiringRate, Ca^{2+}/min', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('FiringRate, Ca^{2+}/min', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_FiringRate.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_FiringRate.fig', pathout, ExpID));
delete(h);


% histogram, MI (bit/Ca2+)
h = figure('Position', mouse.params_main.Screensize);
histogram(cells_active_MI_bit_event, 'BinMethod','fd');
title('Histogram of cell''s MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_event.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_event.fig', pathout, ExpID));
delete(h);

% histogram, MI (bit/min)
h = figure('Position', mouse.params_main.Screensize);
histogram(cells_active_MI_bit_time, 'BinMethod','fd');
title('Histogram of cell''s MI, bit/min', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_time.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_time.fig', pathout, ExpID));
delete(h);

% histogram, MI (z-scored)
h = figure('Position', mouse.params_main.Screensize);
histogram(cells_active_MI_zscored, 'BinMethod','fd');
title('Histogram of cell''s MI, z-scored', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, z-scored', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_MI_zscored.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_MI_zscored.fig', pathout, ExpID));
delete(h);

% MI, bit/Ca2+ and MI, z-scored
h = figure('Position', mouse.params_main.Screensize);
scatter(cells_active_MI_bit_event, cells_active_MI_zscored, mouse.params_main.MarksizeSpikes, 'k', 'filled');
yline(mouse.params_main.S_sigma, 'r--', 'LineWidth', 2);
title('MI (bit/Ca^{2+}) and MI (z-scored)', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('MI, z-scored', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);

saveas(h, sprintf('%s\\%s_MI_event_zscored.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_MI_event_zscored.fig', pathout, ExpID));
delete(h);

% MI, bit/min and MI, z-scored
h = figure('Position', mouse.params_main.Screensize);
scatter(cells_active_MI_bit_time, cells_active_MI_zscored, mouse.params_main.MarksizeSpikes, 'k', 'filled');
yline(mouse.params_main.S_sigma, 'r--', 'LineWidth', 2);
title('MI (bit/min) and MI (z-scored)', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('MI, z-scored', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);

saveas(h, sprintf('%s\\%s_MI_time_zscored.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_MI_time_zscored.fig', pathout, ExpID));
delete(h);

% MI, bit/min and MI, bit/event
h = figure('Position', mouse.params_main.Screensize, 'Color', 'w');
main_ax = axes('Position', [0.15 0.15 0.8 0.8]);
scatter(cells_active_MI_bit_time, cells_active_MI_bit_event, mouse.params_main.MarksizeSpikes, 'k', 'filled'); hold on;
scatter(cells_informative_MI_bit_time, cells_informative_MI_bit_event, mouse.params_main.MarksizeSpikes, 'r', 'filled'); hold on;

title('MI (bit/min) and MI (z-scored)', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel, 'TickDir', 'in', 'Box', 'on');

ax_xdist = axes('Position', [0.15 0.15 0.8 0.1]);
histogram(cells_active_MI_bit_time, 'BinMethod', 'fd', 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
ax_xdist.XAxis.Visible = 'off'; ax_xdist.YAxis.Visible = 'off'; ax_xdist.Color = 'none'; ax_xdist.YAxisLocation = 'right';

ax_xdist = axes('Position', [0.15 0.15 0.8 0.1]);
histogram(cells_informative_MI_bit_time, 'BinMethod', 'fd', 'FaceColor', [0.2 0.6 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
ax_xdist.XAxis.Visible = 'off'; ax_xdist.YAxis.Visible = 'off'; ax_xdist.Color = 'none'; ax_xdist.YAxisLocation = 'right';

ax_ydist = axes('Position', [0.15 0.15 0.1 0.8]);
histogram(cells_active_MI_bit_event, 'BinMethod', 'fd', 'Orientation', 'horizontal', 'FaceColor', [0.9 0.4 0.3], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
ax_ydist.XAxis.Visible = 'off'; ax_ydist.YAxis.Visible = 'off'; ax_ydist.Color = 'none';

ax_ydist = axes('Position', [0.15 0.15 0.1 0.8]);
histogram(cells_informative_MI_bit_event, 'BinMethod', 'fd', 'Orientation', 'horizontal', 'FaceColor', [0.9 0.4 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
ax_ydist.XAxis.Visible = 'off'; ax_ydist.YAxis.Visible = 'off'; ax_ydist.Color = 'none';

linkaxes([main_ax, ax_xdist], 'x');
linkaxes([main_ax, ax_ydist], 'y');

saveas(h, sprintf('%s\\%s_MI_time_event2.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_MI_time_event2.fig', pathout, ExpID));
delete(h);

%% Create structure of outputs data

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
% mouse_id = sprintf('%s_%s', 'FOF',  FileNames{1});

acts = {'cells_count' 'cells_active_count' 'cells_active_percent' 'cells_active_firingrate_mean' ...
    'cells_active_MI_bit_event_mean' 'cells_active_MI_bit_time_mean' 'cells_active_MI_zscored_mean' 'space_explored' 'cells_informative_count' ....
    'cells_informative_percent' 'cells_informative_MI_zscored_mean' 'cells_informative_MI_bit_event_mean' 'cells_informative_MI_bit_time_mean' ...
    };

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(micename(:), groups(:), line(:), 'VariableNames', {'mouse', 'group', 'line'});


%% Create MAIN Big Ugly Table

% добавить все метрики актов
for act = 1:length(acts)
    for session = 1:length(session_id)
        num_volume = (act-1)*length(session_id)+session;
        UglyTable.Name{num_volume} = [acts{act} '_' session_id{session}];
        for mouse = 1:length(micename)
            session_name = [micename{mouse} '_' session_id{session}];
            session_ind = find(strcmp({mice.name}, session_name));
            if ~isempty(session_ind)
                UglyTable.Data(mouse, num_volume) = mice(session_ind).(acts{act});
            else
                UglyTable.Data(mouse, num_volume) = NaN;
            end
        end
    end
end

% создание и сохранение итоговой таблицы
UglyTable.Table = array2table(UglyTable.Data, 'VariableNames', UglyTable.Name);
UglyTable.Table = [mice_info, UglyTable.Table];

writetable(UglyTable.Table, sprintf('%s\\%s_PlaceCells.csv',pathout, ExpID));

save(sprintf('%s\\%_PC.mat', pathout, ExpID));

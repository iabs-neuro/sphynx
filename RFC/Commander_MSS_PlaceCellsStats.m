%% paths and names

pathMat = 'w:\Projects\MSS\ActivityData\MAT_PC\';
pathout = 'w:\Projects\MSS\ActivityData\Results_paper\CogMap\';
ExpID  ='MSS';

% All days
FileNames = {
    'D01_1D_1T' 'D01_2D_1T' 'F01_1D_1T' 'F01_2D_1T' 'F01_3D_1T' 'F01_4D_1T' 'F01_5D_1T' 'F01_6D_1T' 'F04_1D_1T' 'F04_2D_1T'  ...
    'F04_3D_1T' 'F04_4D_1T' 'F04_5D_1T' 'F04_6D_1T' 'F05_1D_1T' 'F05_1D_2T' 'F05_1D_3T' 'F05_1D_4T' 'F05_1D_5T' 'F05_2D_1T'  ...
    'F06_1D_2T' 'F06_1D_3T' 'F06_1D_4T' 'F06_1D_5T' 'F06_2D_1T' 'F08_1D_1T' 'F08_2D_1T' 'F09_1D_1T' 'F09_2D_1T' 'F09_3D_1T'  ...
    'F09_4D_1T' 'F09_5D_1T' 'F09_6D_1T' 'F10_1D_1T' 'F10_2D_1T' 'F11_1D_1T' 'F11_2D_1T' 'F12_1D_1T' 'F12_2D_1T' 'F12_3D_1T'  ...
    'F12_4D_1T' 'F12_5D_1T' 'F12_6D_1T' 'F14_1D_1T' 'F14_2D_1T' 'F15_1D_1T' 'F15_1D_2T' 'F15_1D_3T' 'F15_1D_4T' 'F15_1D_5T'  ...
    'F15_2D_1T' 'F20_1D_1T' 'F20_1D_2T' 'F20_1D_3T' 'F20_1D_4T' 'F20_1D_5T' 'F20_2D_1T' 'F26_1D_1T' 'F26_2D_1T' 'F28_1D_1T'  ...
    'F28_2D_1T' 'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T' 'F29_6D_1T' 'F30_1D_1T' 'F30_1D_2T' 'F30_1D_3T'  ...
    'F30_1D_4T' 'F30_1D_5T' 'F30_2D_1T' 'F31_1D_1T' 'F31_2D_1T' 'F34_1D_1T' 'F34_1D_2T' 'F34_1D_3T' 'F34_1D_4T' 'F34_1D_5T'  ...
    'F34_2D_1T' 'F35_1D_1T' 'F35_2D_1T' 'F36_1D_1T' 'F36_2D_1T' 'F37_1D_1T' 'F37_2D_1T' 'F38_1D_1T' 'F38_2D_1T' 'F38_3D_1T'  ...
    'F38_4D_1T' 'F38_5D_1T' 'F38_6D_1T' 'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T' 'F40_6D_1T' 'F43_1D_1T'  ...
    'F43_1D_2T' 'F43_1D_3T' 'F43_1D_4T' 'F43_1D_5T' 'F43_2D_1T' 'F48_1D_1T' 'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T'  ...
    'F48_6D_1T' 'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T' 'F52_6D_1T' 'F53_1D_1T' 'F53_1D_2T' 'F53_1D_3T'  ...
    'F53_1D_4T' 'F53_1D_5T' 'F53_2D_1T' 'F54_1D_1T' 'F54_1D_2T' 'F54_1D_3T' 'F54_1D_4T' 'F54_1D_5T' 'F54_2D_1T' 'H26_1D_1T'  ...
    'H26_1D_2T' 'H26_1D_3T' 'H26_1D_4T' 'H26_1D_5T' 'H26_2D_1T' 'H27_1D_1T' 'H27_2D_1T' 'H27_3D_1T' 'H27_4D_1T' 'H27_5D_1T'  ...
    'H27_6D_1T' 'H31_1D_1T' 'H31_2D_1T' 'H32_1D_1T' 'H32_2D_1T' 'H32_3D_1T' 'H32_4D_1T' 'H32_5D_1T' 'H32_6D_1T' 'H33_1D_1T'  ...
    'H33_1D_2T' 'H33_1D_3T' 'H33_1D_4T' 'H33_1D_5T' 'H33_2D_1T' ...
    };

% local parameters
center = 16;

%% variables and main struct

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
    'cells_informative_firingrate', [], ...                            	- гистограмма частоты кальциевых событий в минуту информативных нейронов
    'cells_informative_firingrate_mean', 0, ...                         - частота кальциевых событий в минуту информативных нейронов
    'cells_informative_count', 0, ...                                   - количество информативных клеток
    'cells_informative_percent', 0, ...                                 - процент инормативных клеток от числа активных
    ...
    'cells_informative_MI_bit_event', [], ...                        	- гистограмма для MI всех активных нейронов (bit/Ca2+)
    'cells_informative_MI_bit_time', [], ...                           	- гистограмма для MI всех активных нейронов (bit/min)
    'cells_informative_MI_zscored', [], ...                          	- гистограмма для MI информативных нейронов (z-scored)
    ...
    'cells_informative_MI_bit_event_mean', 0, ...                       - среднее значение MI для информативных клеток (bit/Ca2+)
    'cells_informative_MI_bit_time_mean', 0, ...                        - среднее значение MI для информативных клеток (bit/min)
    'cells_informative_MI_zscored_mean', 0, ...                         - среднее значение MI для информативных клеток (z-scored)
    ...
    'Area_hist', [], ...                                                - гистрограмма для площади полей места в см^2
    'Area_average', 0, ...                     - средняя площадь ифнормативных полей места
    ...
    'Max_FR_hist', [], ...                                              - максимальное значение активности в поле информативных клеток
    'Max_FR_average', 0, ...                   - средняя высота поля активности для информативных нейронов
    ...
    'Volume_hist', [], ...                                              - объем поля информативного нейрона
    'Volume_average', 0, ...                   - средний объем полей информативных нейронов
    ...
    'Fields_N', 0, ...                                                  - количество информативных полей
    'Fields_N_active_percent', 0, ...                                   - процент информативных полей на количество активных нейронов
    'Fields_N_on_inform_cell', 0, ...                                   - количество информативных полей на количество информативных нейронов
    'Fields_distrib', [], ...                                           - распределение количества полей на клетку
    ...
    'FieldsNumber', 0 ...                     - распределение количества полей места на нейрон
    );

FieldsNumberAllMice = zeros(1, 6);                                      % количество полей на место на всех мышей
BigField = zeros(31,31);                                                % средняя карта активности для всех информативных полей

cells_active_firingrate = [];
cells_active_MI_bit_event  = [];
cells_active_MI_bit_time  = [];
cells_active_MI_zscored = [];

cells_informative_firingrate = [];
cells_informative_MI_bit_event =[];
cells_informative_MI_bit_time = [];
cells_informative_MI_zscored = [];

mice_active_indx = [];

%% main part

for file = 1:length(FileNames)
    disp(FileNames{file});
    
    pathin = sprintf('%s\\WorkSpace_%s_%s.mat', pathMat, ExpID, FileNames{file});
    load(pathin, 'mouse', 'MapFieldsIC', 'FieldsIC');
    
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
    
    if length(mice(file).cells_active_MI_bit_event) ~= length(mice(file).cells_active_MI_zscored)
        disp(['this ' FileNames{file} ]);
    end
    
    mice(file).cells_active_MI_bit_event_mean = mouse.cells_active_MI_bit_event_mean;
    mice(file).cells_active_MI_bit_time_mean = mouse.cells_active_MI_bit_time_mean;
    mice(file).cells_active_MI_zscored_mean = mouse.cells_active_MI_zscored_mean;
    
    mice(file).cells_informative_count = mouse.cells_informative_count;
    mice(file).cells_informative_percent = mouse.cells_informative_percent;

    mice(file).cells_informative_firingrate = mouse.cells_informative_firingrate;
    mice(file).cells_informative_firingrate_mean = mouse.cells_informative_firingrate_mean;

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
    cells_informative_firingrate = [cells_informative_firingrate mouse.cells_informative_firingrate];
    cells_informative_MI_bit_event =[cells_informative_MI_bit_event  mouse.cells_informative_MI_bit_event];
    cells_informative_MI_bit_time = [cells_informative_MI_bit_time  mouse.cells_informative_MI_bit_time];
    cells_informative_MI_zscored = [cells_informative_MI_zscored mouse.cells_informative_MI_zscored];
    
    % fields number calculation
    if ~isempty(MapFieldsIC)
        mice(file).Fields_N = size(MapFieldsIC,3);
       	mice(file).Fields_N_active_percent = round(mice(file).Fields_N/mice(file).cells_active_count*100,1);
        mice(file).Fields_N_on_inform_cell = round(mice(file).Fields_N/mice(file).cells_informative_count,2);
    else
      	mice(file).Fields_N = 0;
       	mice(file).Fields_N_active_percent = 0;
        mice(file).Fields_N_on_inform_cell = 0;
    end
    
    % area/max_FR/volume of inform fields
    if mice(file).Fields_N
        Area_hist_mouse = [];
        Max_FR_hist_mouse = [];
        Volume_hist_mouse = [];
        for area=1:mice(file).Fields_N
            TempField = zeros(31,31);
            Area_hist_mouse = [Area_hist_mouse length(find(MapFieldsIC(:,:,area)>0))*mouse.params_main.bin_size_cm^2];
            Max_FR_hist_mouse = [Max_FR_hist_mouse max(max(MapFieldsIC(:,:,area)))];
            Volume_hist_mouse = [Volume_hist_mouse sum(sum(MapFieldsIC(:,:,area)))*mouse.params_main.bin_size_cm^2];
            [biny, binx] = find(MapFieldsIC(:,:,area) == max(max(MapFieldsIC(:,:,area))));
            SizeX = size(MapFieldsIC,2);
            SizeY = size(MapFieldsIC,1);
            TempField(center-biny+1:center+SizeY-biny,center-binx+1:center+SizeX-binx) = MapFieldsIC(:,:,area);
            BigField = BigField+TempField;
        end
        mice(file).Area_hist = [mice(file).Area_hist Area_hist_mouse];
        mice(file).Max_FR_hist = [mice(file).Max_FR_hist Max_FR_hist_mouse];
        mice(file).Volume_hist = [mice(file).Volume_hist Volume_hist_mouse];
        mice(file).Area_average = mean(Area_hist_mouse);
        mice(file).Max_FR_average = mean(Max_FR_hist_mouse);
        mice(file).Volume_average = mean(Volume_hist_mouse);
        
        %fields per active cell calculation
        test_zone5 = zeros(1,mice(file).cells_count);
        for i=1:mice(file).cells_count
            if ~isempty(FieldsIC)
                test_zone5(i) = length(find(FieldsIC(1,:)==i));
            end
        end
        mice(file).Fields_distrib = [mice(file).Fields_distrib test_zone5(test_zone5>0)];
        mice(file).FieldsNumber = [ ...
            mice(file).cells_active_count, ...
            length(find(test_zone5(1,:)==1)), ...
            length(find(test_zone5(1,:)==2)), ...
            length(find(test_zone5(1,:)==3)), ...
            length(find(test_zone5(1,:)==4)), ...
            length(find(test_zone5(1,:)==5)) ...
            ];
        
        FieldsNumberAllMice = FieldsNumberAllMice + mice(file).FieldsNumber;
    else
        mice(file).Area_average = 0;
        mice(file).Max_FR_average = 0;
        mice(file).Volume_average = 0;
    end
    clear 'mouse' 'MapFieldsIC' 'FieldsIC'
end

save(sprintf('%s\\%s_TEST_PC.mat', pathout, ExpID));

%% plots

load(pathin, 'mouse');

% histogram, FiringRate (Ca2+/min)
h = figure('Position', mouse.params_main.Screensize);
histogram(cells_active_firingrate, 20);
title('Histogram of cell''s FiringRate, Ca^{2+}/min', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('FiringRate, Ca^{2+}/min', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_FiringRate.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_FiringRate.fig', pathout, ExpID));
delete(h);

% histogram, MI (bit/Ca2+)
h = figure('Position', mouse.params_main.Screensize);
cells_active_MI_bit_event_hist = cells_active_MI_bit_event(cells_active_MI_bit_event~=0);
histogram(cells_active_MI_bit_event_hist, 'BinMethod','fd');
title('Histogram of cell''s MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_event.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_event.fig', pathout, ExpID));
delete(h);

% histogram, MI (bit/min)
h = figure('Position', mouse.params_main.Screensize);
cells_active_MI_bit_time_hist = cells_active_MI_bit_time(cells_active_MI_bit_time~=0);
histogram(cells_active_MI_bit_time_hist, 'BinMethod','fd');
title('Histogram of cell''s MI, bit/min', 'FontSize', mouse.params_main.FontSizeTitle);
xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_time.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_Histogram_MI_bit_time.fig', pathout, ExpID));
delete(h);

% histogram, MI (z-scored)
h = figure('Position', mouse.params_main.Screensize);
cells_active_MI_zscored_hist = cells_active_MI_zscored(cells_active_MI_zscored~=0);
histogram(cells_active_MI_zscored_hist, 'BinMethod','fd');
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

% ax_xdist = axes('Position', [0.15 0.15 0.8 0.1]);
% histogram(cells_active_MI_bit_time, 'BinMethod', 'fd', 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% ax_xdist.XAxis.Visible = 'off'; ax_xdist.YAxis.Visible = 'off'; ax_xdist.Color = 'none'; ax_xdist.YAxisLocation = 'right';
% 
% ax_xdist = axes('Position', [0.15 0.15 0.8 0.1]);
% histogram(cells_informative_MI_bit_time, 'BinMethod', 'fd', 'FaceColor', [0.2 0.6 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% ax_xdist.XAxis.Visible = 'off'; ax_xdist.YAxis.Visible = 'off'; ax_xdist.Color = 'none'; ax_xdist.YAxisLocation = 'right';
% 
% ax_ydist = axes('Position', [0.15 0.15 0.1 0.8]);
% histogram(cells_active_MI_bit_event, 'BinMethod', 'fd', 'Orientation', 'horizontal', 'FaceColor', [0.9 0.4 0.3], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% ax_ydist.XAxis.Visible = 'off'; ax_ydist.YAxis.Visible = 'off'; ax_ydist.Color = 'none';
% 
% ax_ydist = axes('Position', [0.15 0.15 0.1 0.8]);
% histogram(cells_informative_MI_bit_event, 'BinMethod', 'fd', 'Orientation', 'horizontal', 'FaceColor', [0.9 0.4 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% ax_ydist.XAxis.Visible = 'off'; ax_ydist.YAxis.Visible = 'off'; ax_ydist.Color = 'none';
% 
% linkaxes([main_ax, ax_xdist], 'x');
% linkaxes([main_ax, ax_ydist], 'y');

saveas(h, sprintf('%s\\%s_MI_time_event.png', pathout, ExpID));
saveas(h, sprintf('%s\\%s_MI_time_event.fig', pathout, ExpID));
delete(h);

%% Create structure of outputs data

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
% mouse_id = sprintf('%s_%s', 'FOF',  Filenames{1});

acts = {'cells_count' 'cells_active_count' 'cells_active_percent' 'cells_active_firingrate_mean' ...
    'cells_active_MI_bit_event_mean' 'cells_active_MI_bit_time_mean' 'cells_active_MI_zscored_mean' 'space_explored' 'cells_informative_count' ....
    'cells_informative_percent' 'cells_informative_firingrate_mean' 'cells_informative_MI_zscored_mean' 'cells_informative_MI_bit_event_mean' 'cells_informative_MI_bit_time_mean' ...
    'Area_average' 'Max_FR_average' 'Volume_average' 'Fields_N' 'Fields_N_active_percent' 'Fields_N_on_inform_cell'};

% создание структуры таблицы:
% мыши и группы - два первых столбца
% сессии - последующие столбцы, повторяются (колво метрик)*(кол-во актов) раз

micename = {
    'F08' 'F10' 'F11' 'F14' 'F26' 'F28' 'F31' 'F35' 'F36' 'F37' 'H31' 'D01' ...
    'F01' 'F04' 'F09' 'F12' 'F29' 'F38' 'F40' 'F48' 'F52' 'H27' 'H32' ...
    'F05' 'F06' 'F15' 'F20' 'F30' 'F34' 'F43' 'F53' 'F54' 'H26' 'H33' ...
    };

groups = {
    'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' 'Single' ...
    'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' 'Spaced' ...
    'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' 'Massed' ...
    };

line = {
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    '5xFAD' '5xFAD' '5xFAD' '5xFAD' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' 'C57Bl6' ...
    };

% создание столбцов с id мышей и группой (и линией) в начале таблицы
mice_info = table(micename(:), groups(:), line(:), 'VariableNames', {'mouse', 'group', 'line'});

% сессии в конкретном эксперименте
% session_id = {'1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T' '2D_1T' '3D_1T' '4D_1T' '5D_1T' '6D_1T'};
session_id = {'2D_1T' '6D_1T'};

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

writetable(UglyTable.Table, sprintf('%s\\%s_PlaceCells_Test.csv',pathout, ExpID));
save(sprintf('%s\\%_TEST_PC.mat', pathout, ExpID));


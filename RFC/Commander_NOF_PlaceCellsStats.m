%% paths and names

path = 'w:\Projects\MSS\ActivityData\MAT_PC\';
pathout = 'w:\Projects\MSS\ActivityData\CogMap\';
ExpID  ='MSS';

% All days
Filenames = {
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
    'duration_s', zeros(1,length(Filenames)), ...
    'framerate', zeros(1,length(Filenames)), ...
    'size_map', [], ...
    'xkcorr', zeros(1,length(Filenames)), ...
    ...
    'cells_count', zeros(1,length(Filenames)), ...                   	- всего нейронов
    'cells_active_count', zeros(1,length(Filenames)), ...            	- количество активных нейронов
    'cells_active_percent', zeros(1,length(Filenames)), ...             - процент активных нейронов
    'cells_active_firingrate', [], ...                                	- гистограмма частоты кальциевых событий в минуту активных нейронов
    'cells_active_firingrate_mean', zeros(1,length(Filenames)), ...   	- частота кальциевых событий в минуту активных нейронов
    'cells_active_MI_bit', [], ...                                      - гистограмма для MI активных нейронов (z-scored)
    'cells_active_MI_bit_mean', zeros(1,length(Filenames)), ...         - среднее значение MI активных нейронов (z-scored)
    'cells_active_MI_zscored', [], ...                              	- гистограмма для MI активных нейронов (z-scored)
    'cells_active_MI_zscored_mean', zeros(1,length(Filenames)), ...     - среднее значение MI активных нейронов (z-scored)
    ...
    'space_explored', zeros(1,length(Filenames)), ...                   - процент исследованного пространства
    ...
    'cells_informative_count', zeros(1,length(Filenames)), ...       	- количество информативных клеток
    'cells_informative_percent', zeros(1,length(Filenames)), ...       	- процент инормативных клеток от числа активных
    ...
    'cells_informative_MI_bit', [], ...                               	- гистограмма для MI всех активных нейронов (bit/Ca2+)
    'cells_informative_MI_zscored', [], ...                          	- гистограмма для MI информативных нейронов (z-scored)
    ...
    'cells_informative_MI_zscored_mean', zeros(1,length(Filenames)), ...- среднее значение MI для информативных клеток (z-scored)
    'cells_informative_MI_bit_mean', zeros(1,length(Filenames)), ...  	- среднее значение MI для информативных клеток (bit/Ca2+)
    ...
    'Area_hist', [], ...                                                - гистрограмма для площади полей места в см^2
    'Area_average', zeros(1,length(Filenames)), ...                     - средняя площадь ифнормативных полей места
    ...
    'Max_FR_hist', [], ...                                              - максимальное значение активности в поле информативных клеток
    'Max_FR_average', zeros(1,length(Filenames)), ...                   - средняя высота поля активности для информативных нейронов
    ...
    'Volume_hist', [], ...                                              - объем поля информативного нейрона
    'Volume_average', zeros(1,length(Filenames)), ...                   - средний объем полей информативных нейронов
    ...
    'Fields_N', zeros(1,length(Filenames)), ...                         - количество информативных полей
    'Fields_N_active_percent', zeros(1,length(Filenames)), ...          - процент информативных полей на количество активных нейронов
    'Fields_N_on_inform_cell', zeros(1,length(Filenames)), ...          - количество информативных полей на количество информативных нейронов
    'Fields_distrib', [], ...                                           - распределение количества полей на клетку
    ...
    'FieldsNumber', zeros(length(Filenames), 6) ...                     - распределение количества полей места на нейрон
    );

FieldsNumberAllMice = zeros(1, 6);                                  % количество полей на место на всех мышей
BigField = zeros(31,31);                                            % средняя карта активности для всех информативных полей


%% main part

for file = 1:length(Filenames)
    disp(Filenames{file});
    
    pathin = sprintf('%s\\WorkSpace_MSS_%s.mat',path,Filenames{file});
    load(pathin, 'mouse', 'MapFieldsIC', 'FieldsIC');
    
    % defining struct
    mice(file).name = Filenames{file};
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
    
    mice(file).cells_active_MI_bit = mouse.cells_active_MI_bit;
    mice(file).cells_active_MI_zscored = mouse.cells_active_MI_zscored;
    mice(file).cells_active_MI_bit_mean = mouse.cells_active_MI_bit_mean;
    mice(file).cells_active_MI_zscored_mean = mouse.cells_active_MI_zscored_mean;
    
    mice(file).cells_informative_count = mouse.cells_informative_count;
    mice(file).cells_informative_percent = mouse.cells_informative_percent;
    mice(file).cells_informative_MI_bit = mouse.cells_informative_MI_bit;
    mice(file).cells_informative_MI_bit_mean = mouse.cells_informative_MI_bit_mean;
    mice(file).cells_informative_MI_zscored = mouse.cells_informative_MI_zscored;
    mice(file).cells_informative_MI_zscored_mean = mouse.cells_informative_MI_zscored_mean;
    
    % fields number calculation
    mice(file).Fields_N = size(MapFieldsIC,3);
    mice(file).Fields_N_active_percent = round(mice(file).Fields_N/mice(file).cells_active_count*100,1);
    mice(file).Fields_N_on_inform_cell = round(mice(file).Fields_N/mice(file).cells_informative_count,2);
    
    % area/max_FR/volume of inform fields
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
    
    clear 'mouse' 'MapFieldsIC' 'FieldsIC'
end

save(sprintf('%s\\WorkSpace_final.mat',pathout));

%% Create structure of outputs data

% узнать набор актов (acts) в эксперименте (в рамках одного эксперимента набор актов одинаковый)
% для этого берем набор актов из например первой мышесессии
% mouse_id = sprintf('%s_%s', 'FOF',  Filenames{1});

acts = {'cells_count' 'cells_active_count' 'cells_active_percent' 'cells_active_firingrate_mean' ...
    'cells_active_MI_bit_mean' 'cells_active_MI_zscored_mean' 'space_explored' 'cells_informative_count' ....
    'cells_informative_percent' 'cells_informative_MI_zscored_mean' 'cells_informative_MI_bit_mean' ...
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
session_id = {'1D_1T' '1D_2T' '1D_3T' '1D_4T' '1D_5T' '2D_1T' '3D_1T' '4D_1T' '5D_1T' '6D_1T'};
% session_id = {'1D_1T' '2DT' '3DT' '4DT' '5DT' '6D_1T'};

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

%% all histograms

% BigFieldCntrl = BigField./sum(Fields_N);
% FieldsNumberAllMiceCntrl = FieldsNumberAllMice;
% Cells_MI_all_zscored_Cntrl = Cells_MI_all_zscored;
% Cells_MI_all_bit_Cntrl = Cells_MI_all_bit;
% FiringRate_hist_Cntrl = FiringRate_hist;
% Fields_N_Cntrl = Fields_N;
% Area_hist_Cntrl = Area_hist;
% Max_FR_hist_Cntrl = Max_FR_hist;
% Volume_hist_Cntrl = Volume_hist;
%
% BigFieldFad = BigField./sum(Fields_N);
% FieldsNumberAllMiceFad = FieldsNumberAllMice;
% Cells_MI_all_zscored_Fad = Cells_MI_all_zscored;
% Cells_MI_all_bit_Fad = Cells_MI_all_bit;
% FiringRate_hist_Fad = FiringRate_hist;
% Fields_N_FAD = Fields_N;
% Area_hist_FAD = Area_hist;
% Max_FR_hist_FAD = Max_FR_hist;
% Volume_hist_FAD = Volume_hist;
%
% %% histogram of fields per active cell
% fake = log10(FieldsNumberAllMiceCntrl);
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% h1 = histogram('BinEdges',[-0.5:1:3.5],'BinCounts',log10(FieldsNumberAllMiceFad)); hold on;
% h2 = histogram('BinEdges',[-0.5:1:3.5],'BinCounts',fake);hold on;
%
% % h1.BinWidth = 1;hold on;
% h2.FaceColor = 'c';
% h2.EdgeColor = 'k';
% % h2.BinWidth = 1;
% h1.FaceColor = 'r';
% h1.EdgeColor = 'k';
%
% title('Количество полей места на активную клетку','FontSize', 16);
% xlabel('Количество полей','FontSize', 16);
% ylabel('Log10(Количество активных клеток)','FontSize', 16);
% grid on;
%
% legend('5xFAD','С57');
%
% % Сохранение фигуры в формате .fig
% savefig(h, sprintf('%s\\FieldsPerCell_hist.fig', pathout));
%
% % Сохранение фигуры в формате .png
% saveas(h, sprintf('%s\\FieldsPerCell_hist.png', pathout));
%
% % save(sprintf('%s\\WorkSpace_final.mat',pathout));
%
%% sum profile of fields calculation

% TheBigField = [BigFieldCntrl(9:23,10:21) BigFieldFad(9:23,10:21)];
% 
% hss = fspecial('gaussian', 5, 1);
% BigFieldNorm_sm = conv2(TheBigField, single(hss), 'same');
% %
% Map = BigFieldNorm_sm;
% Map = TheBigField;
Map = BigField;

h = figure('Position', get(0, 'Screensize'));
[X,Y] = meshgrid(1:size(Map,2),1:size(Map,1));
C = double(Map);
surf(X,Y,Map,C);
colorbar;

%% Увеличение разрешения сетки
[X, Y] = meshgrid(1:0.5:size(Map, 2), 1:0.5:size(Map, 1)); % Более плотная сетка
C = interp2(1:size(Map, 2), 1:size(Map, 1), Map, X, Y, 'spline'); % Интерполяция значений

% Построение поверхности
h = figure('Position', get(0, 'Screensize'));
% surf(X, Y, C, C, 'EdgeColor', 'none'); % 'EdgeColor', 'none' для сглаживания
surf(X, Y, C, C); % 'EdgeColor', 'none' для сглаживания
colorbar;
% shading interp; % Сглаживание цветов
view(3); % 3D вид
%
% %% histogram of area
%
% Area_hist_Cntrl_sm = Area_hist_Cntrl;
% Area_hist_FAD_sm = Area_hist_FAD;
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% h1 = histogram(Area_hist_Cntrl_sm,'Normalization','pdf');hold on;
% h2 = histogram(Area_hist_FAD_sm,'Normalization','pdf'); hold on;
%
% h1.BinWidth = 10;hold on;
% h1.FaceColor = 'c';
% h1.EdgeColor = 'k';
% h2.BinWidth = 10;
% h2.FaceColor = 'r';
% h2.EdgeColor = 'k';
%
% title('Распределение площади полей места','FontSize', 16);
% xlabel('Площадь полей, см^2','FontSize', 16);
% ylabel('Вероятность','FontSize', 16);
% grid on;
%
% y = 0:1:max([Area_hist_Cntrl_sm Area_hist_FAD_sm]);
% [~,mu_C,sigma_C] = zscore(Area_hist_Cntrl_sm);
% [~,mu_F,sigma_F] = zscore(Area_hist_FAD_sm);
%
% f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
% f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
% plot(y,f_C, 'c' ,'LineWidth',3);hold on;
% plot(y,f_F, 'r','LineWidth',3);
%
% legend('С57','5xFAD', 'С57, PDF', '5xFAD, PDF');
% savefig(h, sprintf('%s\\Area_hist.fig', pathout));
% saveas(h, sprintf('%s\\Area_hist.png', pathout));
%
% % save(sprintf('%s\\WorkSpace_final.mat',pathout));
%
% %% histogram of peak FR of field
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% h1 = histogram(Max_FR_hist_Cntrl,'Normalization','pdf');hold on;
% h2 = histogram(Max_FR_hist_FAD,'Normalization','pdf'); hold on;
%
% h1.BinWidth = 1;hold on;
% h1.FaceColor = 'c';
% h1.EdgeColor = 'k';
% h2.BinWidth = 1;
% h2.FaceColor = 'r';
% h2.EdgeColor = 'k';
%
% title('Распределение пиков активности полей места','FontSize', 16);
% xlabel('Частота Ca2+ событий, Ca2+/мин','FontSize', 16);
% ylabel('Вероятность','FontSize', 16);
% grid on;
%
% y = 0:0.1:max([Max_FR_hist_Cntrl Max_FR_hist_FAD]);
% [~,mu_C,sigma_C] = zscore(Max_FR_hist_Cntrl);
% [~,mu_F,sigma_F] = zscore(Max_FR_hist_FAD);
%
% f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
% f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
% plot(y,f_C, 'c' ,'LineWidth',3);hold on;
% plot(y,f_F, 'r','LineWidth',3);
%
% legend('С57','5xFAD', 'С57, PDF', '5xFAD, PDF');
%
% savefig(h, sprintf('%s\\Max_FR_hist.fig', pathout));
% saveas(h, sprintf('%s\\Max_FR_hist.png', pathout));
%
% % save(sprintf('%s\\WorkSpace_final.mat',pathout));
%
% %% histogram of fields volume
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% Volume_hist_Cntrl_sm = Volume_hist_Cntrl;
% Volume_hist_FAD_sm = Volume_hist_FAD;
%
% h1 = histogram(Volume_hist_Cntrl_sm,'Normalization','pdf');hold on;
% h2 = histogram(Volume_hist_FAD_sm,'Normalization','pdf'); hold on;
%
% h1.BinWidth = 100;hold on;
% h1.FaceColor = 'c';
% h1.EdgeColor = 'k';
% h2.BinWidth = 100;
% h2.FaceColor = 'r';
% h2.EdgeColor = 'k';
%
% title('Распределение объема полей места','FontSize', 16);
% xlabel('Объем поля, Ca2+/мин*см^2','FontSize', 16);
% ylabel('Вероятность','FontSize', 16);
% grid on;
%
% y = 0:1:max([Volume_hist_Cntrl_sm Volume_hist_FAD_sm]);
% [~,mu_C,sigma_C] = zscore(Volume_hist_Cntrl_sm);
% [~,mu_F,sigma_F] = zscore(Volume_hist_FAD_sm);
%
% f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
% f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
% plot(y,f_C, 'c' ,'LineWidth',3);hold on;
% plot(y,f_F, 'r','LineWidth',3);
%
% legend('С57','5xFAD', 'С57, PDF', '5xFAD, PDF');
% savefig(h, sprintf('%s\\Volume_hist.fig', pathout));
% saveas(h, sprintf('%s\\Volume_hist.png', pathout));
%
% % save(sprintf('%s\\WorkSpace_final.mat',pathout));
% %% histogram of active cells zscored(MI)
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% h1 = histogram(Cells_MI_all_zscored_Cntrl,'Normalization','pdf');hold on;
% h2 = histogram(Cells_MI_all_zscored_Fad,'Normalization','pdf'); hold on;
%
% h1.BinWidth = 0.25;hold on;
% h1.FaceColor = 'c';
% h1.EdgeColor = 'k';
% h2.BinWidth = 0.25;
% h2.FaceColor = 'r';
% h2.EdgeColor = 'k';
%
% title('Распределение MI активных клеток','FontSize', 16);
% xlabel('z-scored (MI), \sigma','FontSize', 16);
% ylabel('Вероятность','FontSize', 16);
% grid on;
%
% y = min([Cells_MI_all_zscored_Fad Cells_MI_all_zscored_Cntrl]):0.1:max([Cells_MI_all_zscored_Fad Cells_MI_all_zscored_Cntrl]);
% [~,mu_C,sigma_C] = zscore(Cells_MI_all_zscored_Cntrl);
% [~,mu_F,sigma_F] = zscore(Cells_MI_all_zscored_Fad);
%
% f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
% f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
% plot(y,f_C, 'c' ,'LineWidth',3);hold on;
% plot(y,f_F, 'r','LineWidth',3);
%
% legend('С57','5xFAD', 'С57, PDF', '5xFAD, PDF');
% savefig(h, sprintf('%s\\IC_hist.fig', pathout));
% saveas(h, sprintf('%s\\IC_hist.png', pathout));
%
% % save(sprintf('%s\\WorkSpace_final.mat',pathout));
%
% %% histogram of active cells MI (bit/Ca2+)
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% h1 = histogram(Cells_MI_all_bit_Cntrl,'Normalization','pdf');hold on;
% h2 = histogram(Cells_MI_all_bit_Fad,'Normalization','pdf'); hold on;
%
% h1.BinWidth = 0.04;hold on;
% h1.FaceColor = 'c';
% h1.EdgeColor = 'k';
% h2.BinWidth = 0.04;
% h2.FaceColor = 'r';
% h2.EdgeColor = 'k';
%
% title('Распределение MI активных клеток','FontSize', 16);
% xlabel('MI, бит/Са2+','FontSize', 16);
% ylabel('Вероятность','FontSize', 16);
% grid on;
%
% y = min([Cells_MI_all_bit_Fad Cells_MI_all_bit_Cntrl]):0.01:max([Cells_MI_all_bit_Fad Cells_MI_all_bit_Cntrl]);
% [~,mu_C,sigma_C] = zscore(Cells_MI_all_bit_Cntrl);
% [~,mu_F,sigma_F] = zscore(Cells_MI_all_bit_Fad);
%
% f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
% f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
% plot(y,f_C, 'c' ,'LineWidth',3);hold on;
% plot(y,f_F, 'r','LineWidth',3);
%
% legend('С57','5xFAD', 'С57, PDF', '5xFAD, PDF');
% savefig(h, sprintf('%s\\IC_hist_bit.fig', pathout));
% saveas(h, sprintf('%s\\IC_hist_bit.png', pathout));
%
% % save(sprintf('%s\\WorkSpace_final.mat',pathout));
%
% %% histogram of active cells zscored(MI)
%
% h = figure; % Создаем фигуру и сохраняем ее в переменную
% h1 = histogram(FiringRate_hist_Cntrl,'Normalization','pdf');hold on;
% h2 = histogram(FiringRate_hist_Fad,'Normalization','pdf'); hold on;
%
% h1.BinWidth = 0.5;hold on;
% h1.FaceColor = 'c';
% h1.EdgeColor = 'k';
% h2.BinWidth = 0.5;
% h2.FaceColor = 'r';
% h2.EdgeColor = 'k';
%
% title('Распределение активности клеток','FontSize', 16);
% xlabel('Частота Ca2+ событий, Са2+/мин','FontSize', 16);
% ylabel('Вероятность','FontSize', 16);
% grid on;
%
% y = 0:0.1:max([FiringRate_hist_Fad FiringRate_hist_Cntrl]);
% [~,mu_C,sigma_C] = zscore(FiringRate_hist_Cntrl);
% [~,mu_F,sigma_F] = zscore(FiringRate_hist_Fad);
%
% f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
% f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
% plot(y,f_C, 'c' ,'LineWidth',3);hold on;
% plot(y,f_F, 'r','LineWidth',3);
%
% legend('С57','5xFAD', 'С57, PDF', '5xFAD, PDF');
% savefig(h, sprintf('%s\\FR_hist.fig', pathout));
% saveas(h, sprintf('%s\\FR_hist.png', pathout));

% save(sprintf('%s\\WorkSpace_final.mat',pathout));

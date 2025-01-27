%% paths and names

path = 'w:\Projects\FOF\ActivityData\PC_mat\';
pathout = 'w:\Projects\FOF\ActivityData\CogMap\';
exp  ='FOF';

% All days
Filenames = {
    'F28_1D', 'F30_1D', 'F35_1D', 'F37_1D', 'F40_1D', 'F48_1D', 'F52_1D',...                        % BL_SL
    'F29_1D', 'F31_1D', 'F34_1D', 'F36_1D', 'F38_1D', 'F41_1D', 'F53_1D', 'F54_1D',...              % BL_MK
    'F07_1D', 'F09_1D', 'F10_1D', 'F14_1D', 'F15_1D', 'F20_1D', ...                                 % FAD-SL
    'F01_1D', 'F05_1D', 'F06_1D', 'F08_1D', 'F11_1D', 'F12_1D', ...                                 % FAD-MK
    'F28_2D', 'F30_2D', 'F35_2D', 'F37_2D', 'F40_2D', 'F48_2D', 'F52_2D',...                        % BL_SL
    'F29_2D', 'F31_2D', 'F34_2D', 'F36_2D', 'F38_2D', 'F41_2D', 'F53_2D', 'F54_2D',...              % BL_MK
    'F07_2D', 'F09_2D', 'F10_2D', 'F14_2D', 'F15_2D', 'F20_2D', ...                                 % FAD-SL
    'F01_2D', 'F05_2D', 'F06_2D', 'F08_2D', 'F11_2D', 'F12_2D', ...                                 % FAD-MK
    'F28_3D', 'F30_3D', 'F35_3D', 'F37_3D', 'F40_3D', 'F48_3D', 'F52_3D',...                        % BL_SL
    'F29_3D', 'F31_3D', 'F34_3D', 'F36_3D', 'F38_3D', 'F41_3D', 'F53_3D', 'F54_3D',...              % BL_MK
    'F07_3D', 'F09_3D', 'F10_3D', 'F14_3D', 'F15_3D', 'F20_3D', ...                                 % FAD-SL
    'F01_3D', 'F05_3D', 'F06_3D', 'F08_3D', 'F11_3D', 'F12_3D'                                      % FAD-MK
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
'cells_count', zeros(1,length(Filenames)), ...                   	- всего нейронов
'cells_active_count', zeros(1,length(Filenames)), ...            	- количество активных нейронов
'cells_active_percent', zeros(1,length(Filenames)), ...             - процент активных нейронов
'cells_active_firingrate', [], ...                                	- гистограмма частоты кальциевых событий в минуту активных нейронов
'cells_active_firingrate_mean', zeros(1,length(Filenames)), ...   	- частота кальциевых событий в минуту активных нейронов
'cells_active_MI_bit', [], ...                                      - гистограмма для MI активных нейронов (z-scored)
'cells_active_MI_bit_mean', [], ...                                 - среднее значение MI активных нейронов (z-scored)
'cells_active_MI_zscored', [], ...                              	- гистограмма для MI активных нейронов (z-scored)
'cells_active_MI_zscored_mean', [], ...                            	- среднее значение MI активных нейронов (z-scored)
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
'FieldsNumber', zeros(length(Filenames), 4), ...                    - распределение количества полей места на нейрон
'FieldsNumberAllMice', zeros(1, 4), ...                             - количество полей на место на всех мышей
...
'BigField', zeros(31,31) ...                                        - средняя карта активности для всех информативных полей
);

%% main part

for file = 1:length(Filenames)

    disp(Filenames{file});
    
    pathin = sprintf('%s\\WorkSpace_FOF_%s.mat',path,Filenames{file});
    load(pathin, 'mouse', 'MapFieldsIC', 'FieldsIC');  

    % defining struct
    mice(file).name = Filenames{file};
    mice(file).exp = mouse.exp;
    mice(file).group = mouse.group;
    mice(file).id = mouse.id;
    mice(file).day = mouse.day;
    mice(file).trial = mouse.trial;

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
    mice(file).Fields_N_active_percent = round(Fields_N(file)/mice(file).cells_active_count*100,1);
    mice(file).Fields_N_on_inform_cell = round(Fields_N(file)/mice(file).cells_informative_count,2);
    
    % area/max_FR/volume of inform fields
    Area_hist_mouse = [];
    Max_FR_hist_mouse = [];
    Volume_hist_mouse = [];
    for area=1:Fields_N(file)
        TempField = zeros(31,31);
        Area_hist_mouse = [Area_hist_mouse length(find(MapFieldsIC(:,:,area)>0))*mouse.params_main.bin_size_cm^2];
        Max_FR_hist_mouse = [Max_FR_hist_mouse max(max(MapFieldsIC(:,:,area)))];
        Volume_hist_mouse = [Volume_hist_mouse sum(sum(MapFieldsIC(:,:,area)))*mouse.params_main.bin_size_cm^2];
        [biny, binx] = find(MapFieldsIC(:,:,area) == max(max(MapFieldsIC(:,:,area))));
        SizeX = size(MapFieldsIC,2);
        SizeY = size(MapFieldsIC,1);
        TempField(center-biny+1:center+SizeY-biny,center-binx+1:center+SizeX-binx) = MapFieldsIC(:,:,area);
        mice(file).BigField = mice(file).BigField+TempField;
    end
    mice(file).Area_hist = [mice(file).Area_hist Area_hist_mouse];
    mice(file).Max_FR_hist = [mice(file).Max_FR_hist Max_FR_hist_mouse];
    mice(file).Volume_hist = [mice(file).Volume_hist Volume_hist_mouse];
    mice(file).Area_average = mean(Area_hist_mouse);
    mice(file).Max_FR_average = mean(Max_FR_hist_mouse);
    mice(file).Volume_average = mean(Volume_hist_mouse);
    
    %fields per active cell calculation
    test_zone5 = zeros(1,n_cells);
    for i=1:n_cells
        test_zone5(i) = length(find(FieldsIC(1,:)==i));
    end
    mice(file).Fields_distrib = [mice(file).Fields_distrib test_zone5(test_zone5>0)];
    mice(file).FieldsNumber = [length(g_cell), length(find(test_zone5(1,:)==1)), length(find(test_zone5(1,:)==2)), length(find(test_zone5(1,:)==3))];
    
%     FieldsNumberAllMice = FieldsNumberAllMice + FieldsNumber(file,:);
    
    clear 'mouse' 'MapFieldsIC' 'FieldsIC'
end

save(sprintf('%s\\WorkSpace_final.mat',pathout));
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
% %% sum profile of fields calculation
% 
% TheBigField = [BigFieldCntrl(9:23,10:21) BigFieldFad(9:23,10:21)];
% 
% hss = fspecial('gaussian', 5, 1);
% BigFieldNorm_sm = conv2(TheBigField, single(hss), 'same');
% 
% Map = BigFieldNorm_sm;
% % Map = TheBigField;
% 
% h = figure('Position', get(0, 'Screensize'));
% [X,Y] = meshgrid(1:size(Map,2),1:size(Map,1));
% C = double(Map);
% surf(X,Y,Map,C);
% colorbar;
% 
% %% Увеличение разрешения сетки
% [X, Y] = meshgrid(1:0.5:size(Map, 2), 1:0.5:size(Map, 1)); % Более плотная сетка
% C = interp2(1:size(Map, 2), 1:size(Map, 1), Map, X, Y, 'spline'); % Интерполяция значений
% 
% % Построение поверхности
% h = figure('Position', get(0, 'Screensize'));
% % surf(X, Y, C, C, 'EdgeColor', 'none'); % 'EdgeColor', 'none' для сглаживания
% surf(X, Y, C, C); % 'EdgeColor', 'none' для сглаживания
% colorbar;
% % shading interp; % Сглаживание цветов
% view(3); % 3D вид
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

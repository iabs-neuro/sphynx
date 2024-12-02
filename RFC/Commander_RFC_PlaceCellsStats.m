%% paths and names

path = 'w:\Projects\RFC\ActivityData\PC_mat\';
pathout = 'w:\Projects\RFC\BehaviorData\6_CogMap\';

% 1D
Filenames = {
    'F28_1D', 'F30_1D', 'F40_1D', 'F32_1D', 'F37_1D', 'F48_1D', 'F35_1D', 'F52_1D',... % BL_SL
    'F26_1D', 'F29_1D', 'F34_1D', 'F36_1D', 'F38_1D', 'F31_1D', 'F41_1D', 'F53_1D', 'F54_1D',... % BL_MK
    'F20_1D', 'F04_1D', 'F07_1D', 'F14_1D', 'F09_1D', 'F15_1D',... % FAD-SL
    'F01_1D', 'F06_1D','F08_1D', 'F12_1D', 'F05_1D', 'F19_1D', 'F11_1D' % FAD-MK    
    };

% 3D
% Filenames = {
%     'F28_3D', 'F30_3D', 'F40_3D', 'F32_3D', 'F37_3D', 'F48_3D', 'F35_3D', 'F52_3D',... % BL_SL
%     'F26_3D', 'F29_3D', 'F34_3D', 'F36_3D', 'F38_3D', 'F31_3D', 'F41_3D', 'F53_3D', 'F54_3D',... % BL_MK
%     'F20_3D', 'F04_3D', 'F07_3D', 'F14_3D', 'F09_3D', 'F15_3D',... % FAD-SL
%     'F01_3D', 'F06_3D','F08_3D', 'F12_3D', 'F05_3D', 'F19_3D', 'F11_3D' % FAD-MK
% };

% local parameters
center = 16;
SareaFCbox = 29*24; %area of FC box in cm^2
% min_spike_field = 5; %minimum number of spikes for active neuron
%% main part
Cell_N = []; % Всего нейронов
Cell_ActiveN = []; % Количество активных нейронов
Space = []; % Процент исследованного пространства 
Cells_inform = []; % количество информативных клеток
Cells_hist = []; % гистограмма для MI всех активных нейронов
Area_hist = [];
Max_FR_hist = [];
Volume_hist = [];
Area_N = [];
BigField = zeros(31,31);
FieldsNumber = zeros(1, 4);
FieldsNumberAllMice = zeros(1, 4);

n_area = 0;
n_inf = 0;
for file = 1:length(Filenames)
% for file = 1
    disp(Filenames{file});
    test_zone5 = [];
    N_time_sm = [];
    pathin = sprintf('%s\\WorkSpace_RFC_%s.mat',path,Filenames{file});
    load(pathin,'file_NV', 'N_time_sm', 'Cell_IC','MapFieldsIC','FieldsIC', 'g_cell','n_cells','bin_size_sm','min_spike_field');
    
    %all cells from CNMFe
    Cell_N(file) = size(file_NV, 2);
    
    %all active cells
    ActiveCells = 0;
    for i=1:Cell_N(file)
        spike_t = find(file_NV(:,i));
        if length(spike_t) >= min_spike_field
            ActiveCells =  ActiveCells+1;
        end
    end
    Cell_ActiveN(file) = ActiveCells;
    
    % active space
    if ~isempty(N_time_sm)
        Space(file) = length(find(N_time_sm>0))*bin_size_sm*bin_size_sm/SareaFCbox*100;
    end
    
    % number of inform cells
    Cells_inform(file) = length(find(Cell_IC(2,:)>0));    
    Cells_hist(n_inf+1:n_inf+ActiveCells) = Cell_IC(6,Cell_IC(2,:)>=0);
    n_inf = n_inf + ActiveCells;
    
    % area of inform fields (inform cell, separate field with 5 spikes)
    Area_N(file) = size(MapFieldsIC,3);
    for area=1:Area_N(file)        
        TempField = zeros(31,31);
        Area_hist(n_area+area) = length(find(MapFieldsIC(:,:,area)>0));
        Max_FR_hist(n_area+area) = max(max(MapFieldsIC(:,:,area)));
        Volume_hist(n_area+area) = sum(sum(MapFieldsIC(:,:,area)));
        [biny, binx] = find(MapFieldsIC(:,:,area) == max(max(MapFieldsIC(:,:,area))));
        SizeX = size(MapFieldsIC,2);
        SizeY = size(MapFieldsIC,1);
        TempField(center-biny+1:center+SizeY-biny,center-binx+1:center+SizeX-binx) = MapFieldsIC(:,:,area);
        BigField = BigField+TempField;    
    end
    n_area = n_area + Area_N(file);
    
    %fields per active cell calculation
    
    test_zone5 = zeros(1,n_cells);
    for i=1:n_cells
        test_zone5(i) = length(find(FieldsIC(1,:)==i));
    end
    FieldsNumber(1) = length(g_cell);
    FieldsNumber(2) = length(find(test_zone5(1,:)==1));    
    FieldsNumber(3) = length(find(test_zone5(1,:)==2));
    FieldsNumber(4) = length(find(test_zone5(1,:)==3));
    FieldsNumber
    for i=1:length(FieldsNumber)
        FieldsNumberAllMice(i) = FieldsNumberAllMice(i)+FieldsNumber(i);
    end 
    
    clear 'file_NV' 'N_time_sm' 'Cell_IC' 'MapFieldsIC' 'FieldsNumber' 'test_zone5'
end


% BigFieldCntrl = BigField./sum(Area_N);
% FieldsNumberAllMiceCntrl = FieldsNumberAllMice;
% Cells_hist_Cntrl = Cells_hist;
% Area_N_Cntrl = Area_N;
% Area_hist_Cntrl = Area_hist;
% Max_FR_hist_Cntrl = Max_FR_hist;
% Volume_hist_Cntrl = Volume_hist;

BigFieldFad = BigField./sum(Area_N);
FieldsNumberAllMiceFad = FieldsNumberAllMice;
Cells_hist_FAD = Cells_hist;
Area_N_FAD = Area_N;
Area_hist_FAD = Area_hist;
Max_FR_hist_FAD = Max_FR_hist;
Volume_hist_FAD = Volume_hist;

%% histogram of fields per active cell
fake = log10(FieldsNumberAllMiceCntrl);

h1 = histogram('BinEdges',[-0.5:1:3.5],'BinCounts',log10(FieldsNumberAllMiceFad)); hold on;
h2 = histogram('BinEdges',[-0.5:1:3.5],'BinCounts',fake);hold on;

% h1.BinWidth = 1;hold on;
h2.FaceColor = 'c';
h2.EdgeColor = 'k';
% h2.BinWidth = 1;
h1.FaceColor = 'r';
h1.EdgeColor = 'k';

title('Количество полей места на активную клетку','FontSize', 16);
xlabel('Количество полей','FontSize', 16);
ylabel('Log10(Количество активных клеток)','FontSize', 16);
grid on;

legend('3xFAD','Контроль');
savefig(sprintf('%s\\FieldsPerCell_hist.fig', pathout));

save(sprintf('%s\\WorkSpace_final.mat',pathout));

%% sum profile of fields calculation
% 
% TheBigField = [BigFieldCntrl(10:22,10:22) BigFieldFad(10:22,10:22)];
% 
% hss = fspecial('gaussian', 5, 1);
% BigFieldNorm_sm = conv2(TheBigField, single(hss), 'same'); 
% 
% % Map = BigFieldNorm_sm;
% Map = TheBigField;
% 
% h = figure('Position', get(0, 'Screensize'));   
% [X,Y] = meshgrid(1:size(Map,2),1:size(Map,1));
% C = double(Map);
% surf(X,Y,Map,C);
% colorbar;

%% histogram of area 
Area_hist_Cntrl_sm = Area_hist_Cntrl*2.5*2.5;
Area_hist_FAD_sm = Area_hist_FAD*2.5*2.5;

h1 = histogram(Area_hist_Cntrl_sm,'Normalization','pdf');hold on;
h2 = histogram(Area_hist_FAD_sm,'Normalization','pdf'); hold on;

h1.BinWidth = 10;hold on;
h1.FaceColor = 'c';
h1.EdgeColor = 'k';
h2.BinWidth = 10;
h2.FaceColor = 'r';
h2.EdgeColor = 'k';

title('Распределение площади полей места','FontSize', 16);
xlabel('Площадь полей, см^2','FontSize', 16);
ylabel('Вероятность','FontSize', 16);
grid on;

y = 0:1:200;
[~,mu_C,sigma_C] = zscore(Area_hist_Cntrl_sm);
[~,mu_F,sigma_F] = zscore(Area_hist_FAD_sm);

f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
plot(y,f_C, 'c' ,'LineWidth',3);hold on;
plot(y,f_F, 'r','LineWidth',3);

legend('Контроль','5xFAD', 'Контроль, PDF', '5xFAD, PDF');
savefig(sprintf('%s\\Area_hist.fig', pathout));

save(sprintf('%s\\WorkSpace_final.mat',pathout));

%% histogram of peak FR of field 

h1 = histogram(Max_FR_hist_Cntrl,'Normalization','pdf');hold on;
h2 = histogram(Max_FR_hist_FAD,'Normalization','pdf'); hold on;

h1.BinWidth = 1;hold on;
h1.FaceColor = 'c';
h1.EdgeColor = 'k';
h2.BinWidth = 1;
h2.FaceColor = 'r';
h2.EdgeColor = 'k';

title('Распределение пиков активности полей места','FontSize', 16);
xlabel('Частота Ca2+ событий, Ca2+/мин','FontSize', 16);
ylabel('Вероятность','FontSize', 16);
grid on;

y = 0:0.1:25;
[~,mu_C,sigma_C] = zscore(Max_FR_hist_Cntrl);
[~,mu_F,sigma_F] = zscore(Max_FR_hist_FAD);

f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
plot(y,f_C, 'c' ,'LineWidth',3);hold on;
plot(y,f_F, 'r','LineWidth',3);

legend('Контроль','3xFAD', 'Контроль, PDF', '3xFAD, PDF');
savefig(sprintf('%s\\Max_FR_hist.fig', pathout));

save(sprintf('%s\\WorkSpace_final.mat',pathout));

%% histogram of fields volume
Volume_hist_Cntrl_sm = Volume_hist_Cntrl*2.5*2.5;
Volume_hist_FAD_sm = Volume_hist_FAD*2.5*2.5;

h1 = histogram(Volume_hist_Cntrl_sm,'Normalization','pdf');hold on;
h2 = histogram(Volume_hist_FAD_sm,'Normalization','pdf'); hold on;

h1.BinWidth = 25;hold on;
h1.FaceColor = 'c';
h1.EdgeColor = 'k';
h2.BinWidth = 25;
h2.FaceColor = 'r';
h2.EdgeColor = 'k';

title('Распределение объема полей места','FontSize', 16);
xlabel('Объем поля, Ca2+/мин*см^2','FontSize', 16);
ylabel('Вероятность','FontSize', 16);
grid on;

y = 0:1:800;
[~,mu_C,sigma_C] = zscore(Volume_hist_Cntrl_sm);
[~,mu_F,sigma_F] = zscore(Volume_hist_FAD_sm);

f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
plot(y,f_C, 'c' ,'LineWidth',3);hold on;
plot(y,f_F, 'r','LineWidth',3);

legend('Контроль','3xFAD', 'Контроль, PDF', '3xFAD, PDF');
savefig(sprintf('%s\\Volume_hist.fig', pathout));

save(sprintf('%s\\WorkSpace_final.mat',pathout));
%% histogram of active cells IC

h1 = histogram(Cells_hist_Cntrl,'Normalization','pdf');hold on;
h2 = histogram(Cells_hist_FAD,'Normalization','pdf'); hold on;

h1.BinWidth = 0.25;hold on;
h1.FaceColor = 'c';
h1.EdgeColor = 'k';
h2.BinWidth = 0.25;
h2.FaceColor = 'r';
h2.EdgeColor = 'k';

title('Распределение IC активных клеток','FontSize', 16);
xlabel('z-scored (IC), \sigma','FontSize', 16);
ylabel('Вероятность','FontSize', 16);
grid on;

y = -3:0.1:5;
[~,mu_C,sigma_C] = zscore(Cells_hist_Cntrl);
[~,mu_F,sigma_F] = zscore(Cells_hist_FAD);

f_C = exp(-(y-mu_C).^2./(2*sigma_C^2))./(sigma_C*sqrt(2*pi));
f_F = exp(-(y-mu_F).^2./(2*sigma_F^2))./(sigma_F*sqrt(2*pi));
plot(y,f_C, 'c' ,'LineWidth',3);hold on;
plot(y,f_F, 'r','LineWidth',3);

legend('Контроль','5xFAD', 'Контроль, PDF', '5xFAD, PDF');
savefig(sprintf('%s\\IC_hist.fig', pathout));

save(sprintf('%s\\WorkSpace_final.mat',pathout));


%% original parhs
% FilenamesFAD1D = {
%     'FA_01_EXPO','FA_02_EXPO','FA_03_EXPO','FA_04_EXPO','FA_05_EXPO',...
%     'FA_07_EXPO','FA_08_EXPO','FA_09_EXPO'};
% 
% FilenamesFAD7D = {
%     'FA_01_TEST','FA_02_TEST','FA_03_TEST','FA_04_TEST','FA_05_TEST',...
%     'FA_07_TEST','FA_09_TEST'};
% 
% FilenamesCntrl1D = {
%     'BE_01_EXPO','BE_02_EXPO','FS_01_EXPO','FS_03_EXPO','FS_05_EXPO',...
%     'FS_07_EXPO','FS_08_EXPO','FS_09_EXPO','FS_10_EXPO'};
% 
% FilenamesCntrl7D = {
%     'BE_01_TEST','BE_02_TEST','FS_01_TEST','FS_03_TEST','FS_05_TEST',...
%     'FS_07_TEST','FS_08_TEST','FS_09_TEST','FS_10_TEST'};
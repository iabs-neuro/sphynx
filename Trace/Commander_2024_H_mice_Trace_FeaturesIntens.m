%% paths and names

FreezPath = 'd:\Projects\Trace\FreezResults\';
ProtocolPath = 'd:\Projects\Trace\Trace_behav_Intens_separate.mat';
load(ProtocolPath)

% Trace1DTr00 = 'd:\Projects\Trace\Protocols\Trace_1D_Tr00.csv';
% Trace1DTr20 = 'd:\Projects\Trace\Protocols\Trace_1D_Tr20.csv';
% Trace1DTr60 = 'd:\Projects\Trace\Protocols\Trace_1D_Tr60.csv';
% Trace2D = 'd:\Projects\Trace\Protocols\Trace_2D.csv';

PathOut = 'd:\Projects\Trace\Features_INTENS_shock_correct_separate\';

Tr00 = {'H02_1D','H10_1D','H11_1D','H14_1D'};
Tr20 = {'H03_1D','H15_1D','H16_1D','H19_1D'};
Tr60 = {'H04_1D','H05_1D','H13_1D','H23_1D'};
Tr2D  = {'H02_2D','H03_2D','H04_2D','H05_2D','H10_2D','H11_2D','H13_2D','H14_2D','H15_2D','H16_2D','H19_2D','H23_2D'};

% % 1D Tr00
% FileNames = Tr00;
% Protocol = Trace1DTr00;

% % 1D Tr20
% FileNames = Tr20;
% Protocol = Trace1DTr20;

% 1D Tr60
FileNames = Tr60;
Protocol = Trace1DTr60;

% % 2D 
% FileNames = Tr2D;
% Protocol = Trace2D;


%% features creation new, separate 01/06

for file = 1:length(FileNames)
    
    load(sprintf('%sTRACE_%s_WorkSpace_13_5_36_22.mat',FreezPath,FileNames{file}),'MotIndThresFreez');
    
    Freezing = MotIndThresFreez(2,:);
    n_frames = length(Freezing);
    disp(n_frames);
    Features.Data = [];
    Features.Name = { 
        'freezing', ...
        'baseline1', 'sound1', 'shock2s1','shock6s1','trace11', 'trace12', 'trace13',...
        'baseline2', 'sound2', 'shock2s2','shock6s2','trace21', 'trace22', 'trace23',...
        'baseline3', 'sound3', 'shock2s3','shock6s3','trace31', 'trace32', 'trace33',...
        'baseline4', 'sound4', 'shock2s4','shock6s4','trace41', 'trace42', 'trace43',...
        'baseline5', 'sound5', 'shock2s5','shock6s5','trace51', 'trace52', 'trace53',...
        'baseline6', 'sound6', 'shock2s6','shock6s6','trace61', 'trace62', 'trace63',...
        'baseline7', 'sound7', 'shock2s7','shock6s7','trace71', 'trace72', 'trace73'};
    Features.Data(1:n_frames,1) = Freezing;
    
    for act=1:size(Protocol,1)
        for FeatureName = 1:size(Features.Name,2)
            %if ismember(Protocol.between(act), categorical(Features.Name(FeatureName)))
            if ismember(Protocol.Category(act), categorical(Features.Name(FeatureName)))
                Features.Data(Protocol.Value2(act)+1:Protocol.Value2(act) + Protocol.Value3(act),FeatureName) = 1;
            end
        end
    end
%     disp(Protocol.VarName3(act) + Protocol.VarName4(act));
    disp(Protocol.Value2(act) + Protocol.Value3(act));
    Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);
    writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, FileNames{file}));
end

for i=1:50
    plot(1:n_frames,Features.Data(:,i)*i); hold on;
end

%% Features calculations

for file = 1:length(FileNames)
    
    load(sprintf('%sTRACE_%s_WorkSpace_13_5_36_22.mat',FreezPath,FileNames{file}),'MotIndThresFreez');
    
    Freezing = MotIndThresFreez(2,:);
    n_frames = length(Freezing);
    
    Features.Data = [];
    Features.Name = {'freezing', 'shock', 'sound', 'trace1', 'trace2', 'trace3', 'trace12', 'trace123', 'cstrace1','cstrace2','cstrace3','cstrace12','cstrace123'};
    Features.Data(1:n_frames,1) = Freezing;
    
    
    for act=1:size(Protocol,1)
        for FeatureName = 1:size(Features.Name,2)
            if ismember(Protocol.before(act), categorical(Features.Name(FeatureName)))
                Features.Data(Protocol.VarName3(act)+1:Protocol.VarName3(act) + Protocol.VarName4(act),FeatureName) = 1;
            end
        end
    end
    
    % trace12
    Features.Data(1:n_frames,7) = Features.Data(1:n_frames,4)+Features.Data(1:n_frames,5);
    % trace123
    Features.Data(1:n_frames,8) = Features.Data(1:n_frames,4)+Features.Data(1:n_frames,5)+Features.Data(1:n_frames,6);
    % cstrace1
    Features.Data(1:n_frames,9) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,4);
    % cstrace2
    Features.Data(1:n_frames,10) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,5);
    % cstrace3
    Features.Data(1:n_frames,11) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,6);
    % cstrace12
    Features.Data(1:n_frames,12) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,7);
    % cstrace123
    Features.Data(1:n_frames,13) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,8);

    
    Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);
    writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, FileNames{file}));
end

%% new protocols mat creation
Ttable = Trace1DTr00;

% Создание таблицы Ttable для примера
Ttable.Properties.VariableNames = {'Category', 'Value1', 'Value2', 'Value3'};

% Основной скрипт
% Преобразование категориального столбца в cell массив для обработки
categories = cellstr(Ttable.Category);
newCategories = categories; % Копия категорий для обновления

% Итерируемся по категориям, начиная со второй строки, так как для первой нет предыдущей строки
for i = 2:length(categories)
    if strcmp(categories{i}, 'shock')
        % Добавляем '2s' и последний символ из предыдущей категории
        newCategories{i} = strcat(categories{i}, '2s', categories{i-1}(end));
    end
end

% Преобразуем обратно в категориальный массив и обновляем таблицу
Ttable.Category = categorical(newCategories);

% Инициализация новой таблицы для добавления новых строк
newRows = Ttable(1,:); % Стартуем с первой строки

% Итерируемся для добавления новых строк после обновленных строк
for i = 1:height(Ttable)
    newRows = [newRows; Ttable(i, :)]; % Добавляем текущую строку
    if contains(string(Ttable.Category(i)), 'shock2s')
        % Создаем новую строку с 'shock6s' и последним символом из текущей строки
        symb = char(Ttable.Category(i));
        newCategory = strcat('shock6s', symb(end));
        newRow = {categorical({newCategory}), 6, Ttable.Value2(i), 180};
        newRowTable = cell2table(newRow, 'VariableNames', Ttable.Properties.VariableNames);
        newRows = [newRows; newRowTable]; % Добавляем новую строку
    end
end

% Обновляем исходную таблицу
Trace1DTr00 = newRows;

%% 
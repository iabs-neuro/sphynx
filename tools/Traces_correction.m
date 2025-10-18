%% correcting traces from cnmf with wrong fps
TimeTotal = 600; % in seconds
pathout = 'd:\Projects\СС\Traces_correct\';

PathT = 'd:\Projects\СС\Traces\';

% first iteration
% FilenameT = {
%     'CC_H03_1D','CC_H03_2D','CC_H04_1D','CC_H05_1D','CC_H05_2D',...
%     'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D',...
%     'CC_H12_1D','CC_H12_2D','CC_H15_1D','CC_H15_2D',...
%     'CC_H16_1D','CC_H16_2D','CC_H22_1D','CC_H22_2D',...
%     'CC_H23_1D','CC_H23_2D'
%     };

FilenameT = {
    'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
    'CC_H04_1D','CC_H04_2D','CC_H05_1D','CC_H05_2D','CC_H06_1D','CC_H06_2D',...
    'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
    'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D','CC_H12_1D','CC_H12_2D',...
    'CC_H13_1D','CC_H13_2D','CC_H14_1D','CC_H14_2D','CC_H15_1D','CC_H15_2D',...
    'CC_H16_1D','CC_H16_2D','CC_H17_1D','CC_H17_2D',...
    'CC_H19_1D','CC_H19_2D','CC_H22_1D','CC_H22_2D','CC_H23_1D','CC_H23_2D'
    };
%%
for filename = 1:length(FilenameT)
    disp(FilenameT{filename});
    file = readtable(sprintf('%s%s_traces.csv', PathT,FilenameT{filename}),'ReadVariableNames', true);
    
    % [FilenameTS, PathTS]  = uigetfile('*.csv','Select TS file','d:\_WORK\CC\TimeStamps\');
    % fileTS = readtable(sprintf('%s%s', PathTS,FilenameTS));
    % fileTS = table2array(fileTS);
    
    % fileTSD = diff(fileTS)/10000000;
    % fileTSD = [0; fileTSD];
    % if length(fileTSD) == size(file,1)
    % file(:,1) = fileTSD;
    
    %%
    step = TimeTotal/(size(file,1)-1);
    timeline = [0:step:TimeTotal];
    if length(timeline) == size(file,1)
        file(:,1) = array2table(timeline');
    else
        disp('something wrong');
    end
    %%
    % Новые имена для столбцов
    newNames = cell(1, size(file,2)); % создаем ячейковый массив для хранения новых имен
    newNames{1} = 'time_s';
    for i = 2:size(file,2)
        newNames{i} = num2str(i-2); % генерируем новые имена (0-based)
    end
    % Переименовать столбцы
    file.Properties.VariableNames = newNames;
    %%
    writetable(file, sprintf('%s\\%s_traces.csv',pathout,FilenameT{filename}));
end
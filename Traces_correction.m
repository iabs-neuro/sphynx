%% correcting traces from cnmf with wrong fps
pathout = 'd:\_WORK\CC\Traces_correct\';

% [FilenameT, PathT]  = uigetfile('*.csv','Select trace file','d:\_WORK\CC\Traces\');

PathT = 'd:\_WORK\CC\Traces\';
FilenameT = {
    'CC_H03_1D','CC_H03_2D','CC_H04_1D','CC_H05_1D','CC_H05_2D',...
    'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D',...
    'CC_H12_1D','CC_H12_2D','CC_H15_1D','CC_H15_2D',...
    'CC_H16_1D','CC_H16_2D','CC_H22_1D','CC_H22_2D',...
    'CC_H23_1D','CC_H23_2D'
    };
%%
for filename = 1:length(FilenameT)
    file = readtable(sprintf('%s%s_traces.csv', PathT,FilenameT{filename}),'ReadVariableNames', true);
    
    % [FilenameTS, PathTS]  = uigetfile('*.csv','Select TS file','d:\_WORK\CC\TimeStamps\');
    % fileTS = readtable(sprintf('%s%s', PathTS,FilenameTS));
    % fileTS = table2array(fileTS);
    
    % fileTSD = diff(fileTS)/10000000;
    % fileTSD = [0; fileTSD];
    % if length(fileTSD) == size(file,1)
    % file(:,1) = fileTSD;
    
    %%
    step = 600/(size(file,1)-1);
    timeline = [0:step:600];
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
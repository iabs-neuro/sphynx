%% paths and names

timestamps_folder = 'c:\Users\1\YandexDisk\_Projects\MSS\CalciumData\TimeStampsSepAll\';
traces_folder = 'c:\Users\1\YandexDisk\_Projects\MSS\CalciumData\6_Traces\';
output_folder = 'c:\Users\1\YandexDisk\_Projects\MSS\CalciumData\6_Traces_sep\';

% Проверка входных данных
if ~isfolder(timestamps_folder)
    error('Указанная папка с таймстемпами не существует.');
end
if ~isfolder(traces_folder)
    error('Указанная папка с трейсами не существует.');
end
if ~isfolder(output_folder)
    mkdir(output_folder);
end

% % FOF
% filenames = {
%     'F01', 'F05', 'F06', 'F08', 'F09', 'F10', 'F11', 'F12', 'F14', 'F15',...
%     'F20', 'F28', 'F29', 'F30', 'F31', 'F34', 'F35', 'F37', 'F38', 'F40',...
%     'F41', 'F52', 'F53', 'F54'
%     };

% % FOF
% filenames = {
%     'F07', 'F48', 'F36'};

% % HOS
% filenames = {
%     'D01', 'D03', 'D04', 'D07', 'D08', 'D11', 'D14', 'D17'};

% % MSS
% filenames = {
%     'F08', 'F10', 'F11', 'F14', 'F26', 'F28', 'F31', 'F35', 'F36', 'F37', 'H31', 'D01', ...
%     'F01', 'F04', 'F09', 'F12', 'F29', 'F38', 'F40', 'F48', 'F52', 'H27', 'H32', ...
%     'F05', 'F06', 'F15', 'F20', 'F30', 'F34', 'F43', 'F53', 'F54', 'H26', 'H33'
%     };

% BOF
filenames = {
    'H02' 'H03' 'H04' 'H06' 'H07' 'H10' 'H11' 'H12' 'H13' 'H14' 'H15' 'H16' 'H17' 'H19' 'H22' 'H26' 'H27' 'H31' 'H32' 'H33' 'H39'};

timestamps_count_mouse = zeros(1, length(filenames));

%% main part

for file = 1:length(filenames)
    mask = sprintf('BOF_%s_*_Mini_TS.csv', filenames{file});
    mask_traces = sprintf('BOF_%s_*_traces.csv', filenames{file});
    
    % Получение списка файлов с раздельными таймстемпами
    timestamp_files_sep = dir(fullfile(timestamps_folder, mask));
    if isempty(timestamp_files_sep)
        error('Не найдено файлов, соответствующих паттерну в папке с таймстемпами.');
    end
    timestamps_num = size(timestamp_files_sep,1);
    
    traces_file = dir(fullfile(traces_folder, mask_traces));
    if size(traces_file,1) > 1
        error('Файлов трейсов больше одного на одну мышь');
    end
    
    traces_path = fullfile(traces_folder, traces_file(1).name);
    
    % Чтение количества строк из файлов с таймстемпами
    timestamp_counts = zeros(1, timestamps_num);
    for i = 1:timestamps_num
        file_name = timestamp_files_sep(i).name;
        file_path = fullfile(timestamps_folder, file_name);
        
        if ~isfile(file_path)
            error('Файл %s не найден в папке %s.', file_name, timestamps_folder);
        end
        
        % Подсчет количества строк в файле
        fid = fopen(file_path, 'r');
        line_count = 0;
        while ~feof(fid)
            fgets(fid);
            line_count = line_count + 1;
        end
        fclose(fid);
        
        timestamp_counts(i) = line_count;
    end
    timestamps_count_mouse(file) = sum(timestamp_counts);    
   
    if ~isfile(traces_path)
        error('Файл трейсов %s не найден в папке %s.', traces_file, traces_folder);
    end
    
    % Чтение всего файла с трейсами
    traces_data = readtable(traces_path, 'PreserveVariableNames', false);
    traces_data = traces_data(2:end, :); % Удаление заголовка из данных
    total_rows = height(traces_data);
    
    [~,traces_data_for_header,~] = xlsread(traces_path);
    headerNames = strsplit(traces_data_for_header{1},',');
    
    % Проверка, что сумма строк из timestamp совпадает с количеством строк трейсов
    if sum(timestamp_counts) ~= total_rows
        disp(['Суммарное количество строк в timestamp не совпадает с количеством строк в трейсах. Разница в ' num2str(abs(sum(timestamp_counts) - total_rows)) ' кадр']);
    end
    
    % Разделение файла трейсов на три части и сохранение
    start_row = 1;
    for i = 1:timestamps_num
        end_row = start_row + timestamp_counts(i) - 1;
        end_row = min(end_row, size(traces_data,1));
        part_data.Data = table2array(traces_data(start_row:end_row, :));
        
        for j = 1:length(headerNames)
            part_data.Name{j} = headerNames{j};
        end
        
        % Сохранение файла
        output_file = sprintf('%s_traces.csv', timestamp_files_sep(i).name(1:13));
        
        output_path = fullfile(output_folder, output_file);
        
        part_data.Table = array2table(part_data.Data, 'VariableNames', part_data.Name);
        writetable(part_data.Table, output_path);
        
        fprintf('Файл сохранен: %s\n', output_path);
        start_row = end_row + 1;
    end
    
    clear 'part_data';
end
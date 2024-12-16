%% paths and names

timestamps_folder = 'c:\Users\1\YandexDisk\_Projects\FOF\CalciumData\TimeStampsSep\';
traces_folder = 'c:\Users\1\YandexDisk\_Projects\FOF\CalciumData\6_Traces\';
output_folder = 'c:\Users\1\YandexDisk\_Projects\FOF\CalciumData\6_Traces_sep\';

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

filenames = {
    'F01', 'F05', 'F06', 'F08', 'F09', 'F10', 'F11', 'F12', 'F14', 'F15',...
    'F20', 'F28', 'F29', 'F30', 'F31', 'F34', 'F35', 'F37', 'F38', 'F40',...
    'F41', 'F52', 'F53', 'F54'
    };

timestamps_count_mouse = zeros(1, length(filenames));

%% main part
for file = 2:length(filenames)
    
    mask = sprintf('FOF_%s_*_timestamp.csv', filenames{file});
    
    % Получение списка файлов с таймстемпами
    timestamp_files = dir(fullfile(timestamps_folder, mask));
    if isempty(timestamp_files)
        error('Не найдено файлов, соответствующих паттерну в папке с таймстемпами.');
    end

    % Подготовка для обработки одной мыши (FOF_F01)
    mouse_id = sprintf('FOF_%s', filenames{file});
    timestamp_counts = zeros(1, 3); % Для хранения количества строк для 1D, 2D, 3D

    % Чтение количества строк из файлов с таймстемпами
    for i = 1:3
        file_name = sprintf('%s_%dD_timestamp.csv', mouse_id, i);
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

    % Работа с файлом трейсов
    traces_file = sprintf('%s_1D_traces.csv', mouse_id);
    traces_path = fullfile(traces_folder, traces_file);

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
        error('Суммарное количество строк в timestamp не совпадает с количеством строк в трейсах.');
    end

 % Разделение файла трейсов на три части и сохранение
    start_row = 1;
    for i = 1:3
        end_row = start_row + timestamp_counts(i) - 1;
        part_data.Data = table2array(traces_data(start_row:end_row, :));
     
        for j = 1:length(headerNames)
            part_data.Name{j} = headerNames{j};
        end

        % Сохранение файла
        output_file = sprintf('%s_%dD_traces.csv', mouse_id, i);
        output_path = fullfile(output_folder, output_file);
        
        part_data.Table = array2table(part_data.Data, 'VariableNames', part_data.Name);
        writetable(part_data.Table, output_path);

        fprintf('Файл сохранен: %s\n', output_path);
        start_row = end_row + 1;
    end
    
    clear 'part_data';
end
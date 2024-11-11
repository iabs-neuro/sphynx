%% только видео
% Выберите видео файлы
[filenames, pathname] = uigetfile({'*.avi;*.mp4;*.m4v', 'Video Files (*.avi, *.mp4, *.m4v))'}, 'Выберите видео файлы', 'MultiSelect', 'on', 'd:\Projects\H_mice\RawCombineVideo\');
if isequal(filenames,0) || isequal(pathname,0)
    disp('Отменено.')
    return
end

% Если выбран только один файл, конвертируем его в ячейку, чтобы цикл всё равно работал
if ~iscell(filenames)
    filenames = {filenames};
end

% Создаем ячейку для хранения количества кадров для каждого видео
totalFrames = cell(size(filenames));
totalDuration = cell(size(filenames));
totalFramerate = cell(size(filenames));
realFramerate = cell(size(filenames));

% Обходим все выбранные файлы
TotalTotalFrames = 0;
for i = 1:length(filenames)
    % Полный путь к видео файлу
    videoPath = fullfile(pathname, filenames{i});

    % Создаем объект для чтения видео
    videoObj = VideoReader(videoPath);

    % Получаем общее количество кадров
    totalFrames{i} = videoObj.NumFrames;
    totalDuration{i} = videoObj.Duration;
    videoFramerate{i} = videoObj.Framerate;
    TotalTotalFrames = TotalTotalFrames + totalFrames{i};
    realFramerate{i} = totalFrames{i}/600;
    % Выводим результат для текущего видео
    disp(['Для видео ' filenames{i} ' количество кадров: ' num2str(totalFrames{i})]);
end

disp(['Сумма всех кадров ' num2str(TotalTotalFrames)]);

%% 
% Выберите видео файлы или CSV файлы
[filenames, pathname] = uigetfile({'*.avi;*.mp4;*.csv', 'Supported Files (*.avi, *.mp4, *.csv)'}, 'Выберите видео файлы или CSV файлы', 'MultiSelect', 'on', 'd:\Projects\H_mice\RawCombineVideo\');
if isequal(filenames,0) || isequal(pathname,0)
    disp('Отменено.')
    return
end

% Если выбран только один файл, конвертируем его в ячейку, чтобы цикл всё равно работал
if ~iscell(filenames)
    filenames = {filenames};
end

% Проверяем расширения файлов, чтобы определить тип файлов (видео или CSV)
fileExt = cellfun(@(x) x(end-2:end), filenames, 'UniformOutput', false);

if all(strcmp(fileExt, 'csv'))
    % Обработка CSV файлов
    totalRows = cell(size(filenames));
    TotalTotalRows = 0;
    
    % Обходим все выбранные CSV файлы
    for i = 1:length(filenames)
        % Полный путь к CSV файлу
        csvPath = fullfile(pathname, filenames{i});
        
        % Читаем CSV файл и считаем количество строк
        csvData = readtable(csvPath);
        totalRows{i} = height(csvData);
        TotalTotalRows = TotalTotalRows + totalRows{i};
        
        % Выводим результат для текущего CSV файла
        disp(['Для файла ' filenames{i} ' количество строк: ' num2str(totalRows{i})]);
    end
    
    disp(['Сумма всех строк в CSV файлах: ' num2str(TotalTotalRows)]);
    
elseif all(strcmp(fileExt, 'avi') | strcmp(fileExt, 'mp4'))
    % Обработка видео файлов
    totalFrames = cell(size(filenames));
    totalDuration = cell(size(filenames));
    totalFramerate = cell(size(filenames));
    realFramerate = cell(size(filenames));
    TotalTotalFrames = 0;
    
    % Обходим все выбранные видео файлы
    for i = 1:length(filenames)
        % Полный путь к видео файлу
        videoPath = fullfile(pathname, filenames{i});
        
        % Создаем объект для чтения видео
        videoObj = VideoReader(videoPath);
        
        % Получаем общее количество кадров, длительность и частоту кадров
        totalFrames{i} = videoObj.NumFrames;
        totalDuration{i} = videoObj.Duration;
        totalFramerate{i} = videoObj.Framerate;
        TotalTotalFrames = TotalTotalFrames + totalFrames{i};
        realFramerate{i} = totalFrames{i} / 600;
        
        % Выводим результат для текущего видео
        disp(['Для видео ' filenames{i} ' количество кадров: ' num2str(totalFrames{i})]);
    end
    
    disp(['Сумма всех кадров: ' num2str(TotalTotalFrames)]);
else
    disp('Выбраны файлы разных типов или неподдерживаемые файлы.');
end

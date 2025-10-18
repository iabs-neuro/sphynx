%% только видео

TotalRealTime = 900;

% Выберите видео файлы
[filenames, pathname] = uigetfile({'*.avi;*.mp4;*.m4v;*.tif', 'Video Files (*.avi, *.mp4, *.m4v, *.tif)'}, 'Выберите видео файлы', 'MultiSelect', 'on', 'd:\Projects\H_mice\RawCombineVideo\');
if isequal(filenames, 0) || isequal(pathname, 0)
    disp('Отменено.');
    return
end

% Если выбран только один файл, конвертируем его в ячейку, чтобы цикл всё равно работал
if ~iscell(filenames)
    filenames = {filenames};
end

% Создаем ячейки для хранения информации по каждому файлу
totalFrames = cell(size(filenames));
totalDuration = cell(size(filenames));
totalFramerate = cell(size(filenames));
realFramerate = cell(size(filenames));
totalBitsPerPixel = cell(size(filenames));
totalHeight = cell(size(filenames));
totalWidth = cell(size(filenames));

% Суммарное количество кадров
TotalTotalFrames = 0;

% Обходим все выбранные файлы
for i = 1:length(filenames)
    % Полный путь к видео или TIFF файлу
    filePath = fullfile(pathname, filenames{i});
    
    % Определяем формат файла по его расширению
    [~, ~, ext] = fileparts(filenames{i});
    
    if strcmpi(ext, '.tif')  % Если файл - TIFF
        % Получаем информацию о TIFF файле
        tiffInfo = imfinfo(filePath);
        numFrames = numel(tiffInfo);  % Количество кадров
        duration = numFrames / 20;    % Допустим, что частота кадров TIFF 20 FPS (или можно задать по-другому)
        framerate = 20;
        
        % Записываем данные о TIFF файле
        totalFrames{i} = numFrames;
        totalDuration{i} = duration;
        totalFramerate{i} = framerate;
        realFramerate{i} = numFrames / TotalRealTime;
        
    else  % Если файл - видео
        % Создаем объект для чтения видео
        videoObj = VideoReader(filePath);
        
        % Получаем данные о видео файле
        totalFrames{i} = videoObj.NumFrames;
        totalDuration{i} = videoObj.Duration;
        totalFramerate{i} = videoObj.Framerate;
        totalBitsPerPixel{i} = videoObj.BitsPerPixel;
        totalHeight{i} = videoObj.Height;
        totalWidth{i} = videoObj.Width;
        realFramerate{i} = totalFrames{i} / TotalRealTime;
    end
    
    % Выводим результат для текущего файла
    TotalTotalFrames = TotalTotalFrames + totalFrames{i};
    disp(['Для файла ' filenames{i} ' количество кадров: ' num2str(totalFrames{i})]);
end

disp(['Сумма всех кадров: ' num2str(TotalTotalFrames)]);

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
    totalCols = cell(size(filenames));
    totalTime = cell(size(filenames));
    TotalTotalRows = 0;
    
    % Обходим все выбранные CSV файлы
    for i = 1:length(filenames)
        % Полный путь к CSV файлу
        csvPath = fullfile(pathname, filenames{i});
        
        % Читаем CSV файл и считаем количество строк
        csvData = readtable(csvPath);
        csvDataArray = table2array(csvData);
        totalRows{i} = height(csvData);
        totalCols{i} = width(csvData);
        totalTime{i} = (csvDataArray(end)-csvDataArray(1))/10000000/60; % in minutes
        TotalTotalRows = TotalTotalRows + totalRows{i};
        
        % Выводим результат для текущего CSV файла
        disp(['Для файла ' filenames{i} ' количество строк: ' num2str(totalRows{i}) '. время в минутах: ' num2str(totalTime{i})]);
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
        realFramerate{i} = totalFrames{i} / TotalRealTime;
        
        % Выводим результат для текущего видео
        disp(['Для видео ' filenames{i} ' количество кадров: ' num2str(totalFrames{i})]);
    end
    
    disp(['Сумма всех кадров: ' num2str(TotalTotalFrames)]);
else
    disp('Выбраны файлы разных типов или неподдерживаемые файлы.');
end
%% для подсчета сырых данных в кодеке ffv1
rootPath = 'w:\Projects\RFC\1_Raw\';
% Проверяем, существует ли корневая папка
if ~isfolder(rootPath)
    error('Указанная папка не существует: %s', rootPath);
end

% Получаем список всех папок на втором уровне вложенности, содержащих видеофайлы
mainFolders = dir(fullfile(rootPath, 'RFC_*_*D'));

% Инициализируем структуру для хранения общего количества кадров по папкам
totalFramesByFolder = struct();

% Обходим все папки, начинающиеся с "RFC_*_3D"
totalFramesAll = zeros(length(mainFolders),1);
for i = 1:length(mainFolders)
    % Пропускаем не директории
    if ~mainFolders(i).isdir
        continue;
    end
    
    % Получаем путь к текущей основной папке
    folderPath = fullfile(rootPath, mainFolders(i).name, '**', 'Miniscope');
    
    % Ищем все видеофайлы .avi внутри папки Miniscope
    videoFiles = dir(fullfile(folderPath, '*.avi'));
    
    % Проверяем, если видеофайлы найдены
    if isempty(videoFiles)
        disp(['Нет видеофайлов в папке: ' folderPath]);
        continue;
    end
    
    % Инициализация счетчика кадров для текущей папки
    totalFramesThis = 0;
    
    % Обрабатываем все видеофайлы в папке
    
    for j = 1:length(videoFiles)
        videoPath = fullfile(videoFiles(j).folder, videoFiles(j).name);
        
        % Создаем объект для чтения видео
        FrameThis = getTotalFramesFFmpeg(videoPath);
        
        % Добавляем количество кадров в общий счетчик
        totalFramesThis = totalFramesThis + FrameThis;        
        
    end
    totalFramesAll(i,1) = totalFramesThis;
    % Сохраняем результат в структуре
    totalFramesByFolder.(mainFolders(i).name) = totalFramesThis;
    
    % Выводим количество кадров для текущей папки
    disp(['Папка ' mainFolders(i).name ' содержит ' num2str(totalFramesThis) ' кадров.']);
end

% Общий вывод
disp('Общий подсчет кадров завершен.');

%% пееркодировать tif в mp4
% Укажите путь к многокадровому TIFF-файлу и имя выходного видео
inputTiffFile = 'e:\\RFC_F01_3D_CR_MC.tif';
outputVideoFile = 'e:\\RFC_F01_3D_CR_MC_tif.mp4';

% Создаем объект VideoWriter для MP4
videoObj = VideoWriter(outputVideoFile, 'MPEG-4');
videoObj.FrameRate = 30; % Частота кадров (измените при необходимости)
open(videoObj);

% Чтение многокадрового TIFF и запись каждого кадра в видеофайл
tiffInfo = imfinfo(inputTiffFile);
numFrames = numel(tiffInfo);

for i = 1:numFrames
    % Чтение каждого кадра TIFF
    frame = imread(inputTiffFile, i);
    
    % Если изображение чёрно-белое, преобразуем его в RGB для записи в видео
    if size(frame, 3) == 1
        frame = repmat(frame, 1, 1, 3);
    end
    
    % Записываем кадр в видео
    writeVideo(videoObj, frame);
end

% Закрываем объект VideoWriter
close(videoObj);

disp(['Видео сохранено как ', outputVideoFile]);

%% Run FFmpeg from MATLAB to get frame count
% videoPath = 'w:\Projects\RFC_3D\1_Raw\RFC_F01_3D\2024_10_29\15_22_55\Miniscope\0.avi';
function totalFrames = getTotalFramesFFmpeg(videoPath)
    % Вызов FFmpeg для извлечения данных о видеофайле
    [status, result] = system(['ffmpeg -i "' videoPath '" -map 0:v:0 -c copy -f null - 2>&1']);

    % Если команда FFmpeg выполнилась успешно, продолжаем обработку
    if status == 0
        % Используем регулярное выражение для поиска 'frame=' и извлечения числа
        frameCountMatch = regexp(result, 'frame=\s*(\d+)', 'tokens', 'once');
        if ~isempty(frameCountMatch)
            % Преобразуем извлеченное значение в число
            totalFrames = str2double(frameCountMatch{1});
%             disp(['Количество кадров: ', num2str(totalFrames)]);
        else
            disp('Ошибка: не удалось извлечь количество кадров.');
            totalFrames = NaN;
        end
    else
        disp('Ошибка выполнения FFmpeg.');
        disp(result);  % Показать результат для отладки
        totalFrames = NaN;
    end
end
%% пееркодировать ffv1 в mp4 через ffmpeg в командной строке
% ffmpeg -i w:\Projects\RFC\1_Raw\RFC_F10_1D\2024_10_18\17_24_02\Miniscope\3.avi -c:v libx264 -preset fast -crf 23 w:\Projects\RFC\1_Raw\RFC_F10_1D\2024_10_18\17_24_02\Miniscope\3_avi.mp4

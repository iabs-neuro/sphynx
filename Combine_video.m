%% new
% Укажите путь к папке с видео
videoFolderPath = 'j:\_Projects\STFP\VT\20fps\STFP_4\';

% Укажите путь к таблице с количеством пропускаемых кадров
tableFilePath = 'i:\_STFP\STFP_video_combined.csv';

% Чтение таблицы с количеством пропускаемых кадров
skipTable = readtable(tableFilePath);

% Получаем список всех mp4 и m4v видеофайлов в папке
videoFiles = [dir(fullfile(videoFolderPath, '*.mp4')); dir(fullfile(videoFolderPath, '*.m4v'))];

% Создаем контейнер для группировки видеофайлов по идентификаторам
videosByIdentifier = containers.Map;

% Обходим каждый файл и группируем их по идентификаторам
for i = 1:length(videoFiles)
    % Исходное имя файла
    oldName = videoFiles(i).name;
    
    % Разбиваем имя файла на части по символу подчеркивания
    parts = split(oldName, '_');
    
    % Извлекаем идентификатор (первые 4 части имени файла)
    identifier = strjoin(parts(1:4), '_');
    
    % Если последний элемент перед расширением - число, добавляем в группу
    numberPart = regexp(parts{5}, '^\d+', 'match', 'once');
    if ~isempty(numberPart)
        if isKey(videosByIdentifier, identifier)
            videosByIdentifier(identifier) = [videosByIdentifier(identifier); {oldName}];
        else
            videosByIdentifier(identifier) = {oldName};
        end
    end
end

% Объединение видеофайлов
keys = videosByIdentifier.keys
for i = 1:length(keys)
    identifier = keys{i};
    videoList = videosByIdentifier(identifier);
    
    % Сортировка видео по номеру перед расширением
    videoList = sort(videoList)
    
    % Имя выходного файла
    outputFileName = [identifier '.m4v'];
    outputFilePath = fullfile(videoFolderPath, outputFileName);
    
    % Пропуск кадров согласно таблице
    skipRow = skipTable(strcmp(skipTable.NameSession, identifier), :);
    if isempty(skipRow)
        disp(['Пропуск для идентификатора ' identifier ' не найден.']);
        continue;
    end
    
    % Создание видеообъекта для записи итогового видео с частотой кадров 20 fps
    videoWriter = VideoWriter(outputFilePath, 'MPEG-4');
    videoWriter.FrameRate = 20;
    open(videoWriter);
    
    % Подсчет общего количества кадров для текстового прогресс-бара
    totalFrames = 0;
    for j = 1:length(videoList)
        inputFile = fullfile(videoFolderPath, videoList{j});
        videoReader = VideoReader(inputFile);
        totalFrames = totalFrames + max(0, floor(videoReader.Duration * videoReader.FrameRate) - skipRow{1, j+1});
    end
    
    % Инициализация прогресс-бара
    fprintf('Объединение видео %s: [', outputFileName);
    totalBars = 50;
    progressBars = 0;
    frameCount = 0;
    
    % Чтение и запись кадров с учетом пропуска кадров
    for j = 1:length(videoList)
        inputFile = fullfile(videoFolderPath, videoList{j});
        videoReader = VideoReader(inputFile);
        
        % Пропуск первых N кадров
        skipFrames = skipRow{1, j+1};
        if skipFrames < 0
            skipFrames = 0;
        end
        
        % Чтение и запись кадров
        currentFrame = 0;
        while hasFrame(videoReader)
            frame = readFrame(videoReader);
            currentFrame = currentFrame + 1;
            if currentFrame > skipFrames
                writeVideo(videoWriter, frame);
                frameCount = frameCount + 1;
                % Обновление прогресс-бара
                if frameCount / totalFrames > progressBars / totalBars
                    fprintf('=');
                    progressBars = progressBars + 1;
                end
            end
        end
    end
    
    % Завершение прогресс-бара
    fprintf(']\n');
    
    % Закрытие видеообъекта
    close(videoWriter);
    
    % Вывод сообщения о создании файла
    disp(['Файл ', outputFileName, ' успешно создан.']);
end

%% ffmpeg
% Укажите путь к папке с видео
videoFolderPath = 'j:\_Projects\STFP\VT\20fps\STFP_1\';

% Укажите путь к таблице с количеством пропускаемых кадров
tableFilePath = 'i:\_STFP\STFP_video_combined.csv';

% Чтение таблицы с количеством пропускаемых кадров
skipTable = readtable(tableFilePath);

% Получаем список всех mp4 и m4v видеофайлов в папке
videoFiles = [dir(fullfile(videoFolderPath, '*.mp4')); dir(fullfile(videoFolderPath, '*.m4v'))];

% Создаем контейнер для группировки видеофайлов по идентификаторам
videosByIdentifier = containers.Map;

% Обходим каждый файл и группируем их по идентификаторам
for i = 1:length(videoFiles)
    % Исходное имя файла
    oldName = videoFiles(i).name;
    
    % Разбиваем имя файла на части по символу подчеркивания
    parts = split(oldName, '_');
    
    % Извлекаем идентификатор (первые 4 части имени файла)
    identifier = strjoin(parts(1:4), '_');
    
    % Если последний элемент перед расширением - число, добавляем в группу
    numberPart = regexp(parts{5}, '^\d+', 'match', 'once');
    if ~isempty(numberPart)
        if isKey(videosByIdentifier, identifier)
            videosByIdentifier(identifier) = [videosByIdentifier(identifier); {oldName}];
        else
            videosByIdentifier(identifier) = {oldName};
        end
    end
end

% Объединение видеофайлов
keys = videosByIdentifier.keys;
for i = 1:length(keys)
    identifier = keys{i};
    videoList = videosByIdentifier(identifier);
    
    % Сортировка видео по номеру перед расширением
    videoList = sort(videoList)
    
    % Имя выходного файла
    outputFileName = [identifier '.m4v'];
    outputFilePath = fullfile(videoFolderPath, outputFileName);
    
    % Пропуск кадров согласно таблице
    skipRow = skipTable(strcmp(skipTable.NameSession, identifier), :);
    if isempty(skipRow)
        disp(['Пропуск для идентификатора ' identifier ' не найден.']);
        continue;
    end
    
    % Команды для объединения видео и пропуска кадров
    inputVideos = '';
    filterComplex = '';
    
    for j = 1:length(videoList)
        inputFile = fullfile(videoFolderPath, videoList{j});
        inputVideos = [inputVideos, ' -i ', inputFile];
        
        % Пропуск кадров для текущего видео
        skipFrames = skipRow{1, j+1};
        if skipFrames >= 0
            filterComplex = [filterComplex, '[', num2str(j-1), ':v]trim=start_frame=', num2str(skipFrames), '[v', num2str(j), '];'];
        else
            filterComplex = [filterComplex, '[', num2str(j-1), ':v]null[v', num2str(j), '];'];
        end
    end
    
    % Убираем последние символы и добавляем команду для объединения
    filterComplex = filterComplex(1:end-1);
    concatParts = strjoin(arrayfun(@(x) ['[v', num2str(x), ']'], 1:length(videoList), 'UniformOutput', false), '');
    filterComplex = [filterComplex, concatParts, 'concat=n=', num2str(length(videoList)), ':v=1:a=0 [v]'];
    
    % Формирование команды ffmpeg
    ffmpegCommand = sprintf('ffmpeg %s -filter_complex "%s" -map "[v]" -c:v libx264 -pix_fmt yuv420p %s', inputVideos, filterComplex, outputFilePath);
    
    % Выполнение команды ffmpeg
    status = system(ffmpegCommand);
    if status == 0
        disp(['Файл ', outputFileName, ' успешно создан.']);
    else
        disp(['Ошибка при создании файла ', outputFileName]);
    end
end


%% old combine
% Укажите путь к папке с видео
videoFolderPath = 'j:\_Projects\STFP\VT\20fps\STFP_1\';

% Укажите путь к таблице с количеством пропускаемых кадров
tableFilePath = 'i:\_STFP\STFP_video_combined.csv';

% Чтение таблицы с количеством пропускаемых кадров
skipTable = readtable(tableFilePath);

% Получаем список всех mp4 и m4v видеофайлов в папке
videoFiles = [dir(fullfile(videoFolderPath, '*.mp4')); dir(fullfile(videoFolderPath, '*.m4v'))];

% Группируем файлы по мышам и дням
videosByMouseAndDay = containers.Map;

for i = 1:length(videoFiles)
    % Исходное имя файла
    oldName = videoFiles(i).name;
    
    % Извлекаем информацию о мыши и дне
    tokens = regexp(oldName, 'Stfp (\d+) D(\d+)', 'tokens');
    if isempty(tokens)
        continue;
    end
    mouseNumber = str2double(tokens{1}{1});
    dayNumber = str2double(tokens{1}{2});
    
    key = sprintf('A%02d_D%d', mouseNumber, dayNumber);
    if isKey(videosByMouseAndDay, key)
        videosByMouseAndDay(key) = [videosByMouseAndDay(key); {oldName}];
    else
        videosByMouseAndDay(key) = {oldName};
    end
end

% Объединение видеофайлов
keys = videosByMouseAndDay.keys;
for i = 1:length(keys)
    key = keys{i};
    videoList = sort(videosByMouseAndDay(key));
    
    % Имя мыши и номер дня
    tokens = regexp(key, 'A(\d+)_D(\d+)', 'tokens');
    mouseNumber = str2double(tokens{1}{1});
    dayNumber = str2double(tokens{1}{2});
    
    % Имя выходного файла
    outputFileName = sprintf('STFP_A%02d_D%d.m4v', mouseNumber, dayNumber);
    outputFilePath = fullfile(videoFolderPath, outputFileName);
    
    % Пропуск кадров согласно таблице
    sessionName = sprintf('stfp%dD%d', mouseNumber, dayNumber);
    skipRow = skipTable(strcmp(skipTable.Var1, sessionName), :);
    if isempty(skipRow)
        disp(['Пропуск для сессии ' sessionName ' не найден.']);
        continue;
    end
    
    % Команды для объединения видео и пропуска кадров
    inputVideos = '';
    filterComplex = '';
    
    for j = 1:length(videoList)
        inputFile = fullfile(videoFolderPath, videoList{j});
        inputVideos = [inputVideos, ' -i ', inputFile];
        
        % Пропуск кадров для текущего видео
        skipFrames = skipRow{1, j+1};
        if skipFrames >= 0
            filterComplex = [filterComplex, '[', num2str(j-1), ':v]trim=start=', num2str(skipFrames/30), '[v', num2str(j), '];'];
        else
            filterComplex = [filterComplex, '[', num2str(j-1), ':v]null[v', num2str(j), '];'];
        end
    end
    
    % Убираем последние символы
    filterComplex = filterComplex(1:end-1);
    filterComplex = [filterComplex, ' ', strjoin(arrayfun(@(x) ['[v', num2str(x), ']'], 1:length(videoList), 'UniformOutput', false)), 'concat=n=', num2str(length(videoList)), ':v=1:a=0 [v]'];
    
    % Формирование команды ffmpeg
    ffmpegCommand = sprintf('ffmpeg %s -filter_complex "%s" -map "[v]" -c:v libx264 -pix_fmt yuv420p %s', inputVideos, filterComplex, outputFilePath);
    
    % Выполнение команды ffmpeg
    status = system(ffmpegCommand);
    if status == 0
        disp(['Файл ', outputFileName, ' успешно создан.']);
    else
        disp(['Ошибка при создании файла ', outputFileName]);
    end
end

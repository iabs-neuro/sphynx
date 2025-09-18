function neuron_activity_video(videoFile, videoPath, csvFile, csvPath, outPath)
% vvp 16.10.24

%%
if nargin<5
    [videoFile, videoPath] = uigetfile('*.mp4', 'Выберите видеофайл (MP4)','w:\Projects\3DM\BehaviorData\2_Combined\');
    [csvFile, csvPath] = uigetfile('*.csv', 'Выберите файл с активностью нейронов (CSV)', 'c:\Users\1\YandexDisk\_Projects\3DM\CalciumData\6_Traces\');
    [vtFile, vtPath] = uigetfile('*.csv', 'Выберите файл с видеотрекингом (CSV)', 'w:\Projects\3DM\BehaviorData\8_Features\');
    outPath = 'w:\Projects\3DM\ActivityData\';
end

if isequal(videoFile, 0) || isequal(csvFile, 0) || isequal(vtFile, 0)
    disp('Файл не был выбран.');
    return;
end

%% Полные пути к файлам
videoFilePath = fullfile(videoPath, videoFile);
csvFilePath = fullfile(csvPath, csvFile);
vtFilePath = fullfile(vtPath, vtFile);

% Чтение видеофайла
video = VideoReader(videoFilePath);
frameRate = video.FrameRate;  % Частота кадров видео (30 фпс)

% Чтение CSV файла с активностью нейронов
data = readtable(csvFilePath);
numNeurons = size(data, 2) - 1;  % Количество нейронов (столбцы, кроме первого)
numFrames = size(data, 1) - 1;   % Количество кадров (строки, кроме первой)

% Чтение CSV файла с видеотрекингом
dataVT = readtable(vtFilePath);
numFramesVT = size(dataVT, 1);   % Количество кадров (строки, кроме первой)

%% Проверка соответствия количества кадров в видео и таблице
if video.NumFrames ~= numFrames
    fprintf('Количество кадров в видео (%d) и в кальции (%d)\n', video.NumFrames, numFrames);
end

%% Для каждого нейрона создаем новое видео
% for neuronIdx = 1:numNeurons
for neuronIdx = [171 434 454 270 451 462 513 602 713 577 218]
    neuronIdx = neuronIdx+1;
    neuronActivity = table2array(data(2:end, neuronIdx));  % Активность нейрона
    PointsLine = []; % массив кадров для траектории (кумулятивно)
    
    % Рассчитываем медиану и медианное отклонение активности нейрона
    neuronMedian = median(neuronActivity);
    medAbsDev = mad(neuronActivity, 1);  % Медианное отклонение
    
    % Пороговое значение для активности (медиана + 4*медианное отклонение)
    threshold = neuronMedian + 4 * medAbsDev;
    
    [Indexes, ~, ~,~, TimeLineCalcium, FrameRate] = synchronizer((1:video.NumFrames)', neuronActivity, 'Bonsai', 1800);
    length_line = round(FrameRate);
%     length_line = round(FrameRate/2);    
    [selectedFrames, ~, ~,~,~,~] = RefineLine(neuronActivity > threshold, length_line, length_line);
    
%     % debugging plots
%     h = figure; 
%     plot(TimeLineCalcium, neuronActivity); hold on;
%     plot(TimeLineCalcium, ones(1,numFrames)*threshold); hold on;
%     plot(TimeLineCalcium, neuronActivity./max(neuronActivity)); hold on;
%     plot(TimeLineCalcium, neuronActivity > threshold); hold on
%     plot(TimeLineCalcium, selectedFrames*2); hold on
%     delete(h);
    
    % Находим индексы кадров, где активность выше порога
    selectedFramesIdxNeuro = find(selectedFrames);
    selectedFramesIdx = Indexes(selectedFramesIdxNeuro);
%     selectedFramesIdx = Indexes(logical(selectedFrames));
    
%     if isempty(selectedFramesIdx)
%         fprintf('Для нейрона %d нет кадров, превышающих порог.\n', neuronIdx - 1);
%         continue;
%     end
    
    % Создание видео для нейрона
    outputFileName = sprintf('%s\\neuron_%d_video.mp4',outPath, neuronIdx - 1);
    outputVideo = VideoWriter(outputFileName, 'MPEG-4');
    outputVideo.FrameRate = round(frameRate/2);
    open(outputVideo);
    fprintf('Plotting video for neuron %d/%d\n', neuronIdx - 1, numNeurons);
    
    
    %% optimized code
    % Предварительные вычисления (один раз перед циклом)
neuronActivityNorm = (neuronActivity - min(neuronActivity)) ./ (max(neuronActivity) - min(neuronActivity));
minTime = 1;
maxTime = max(TimeLineCalcium);
frameCount = length(selectedFramesIdx);

% Создаем и настраиваем фигуру один раз (вместо создания/закрытия в цикле)
fig = figure('visible', 'off', 'Renderer', 'painters', 'Position', [100 100 800 200]);
ax = axes('Parent', fig);
plot(ax, TimeLineCalcium, neuronActivityNorm, 'b');
hold(ax, 'on');
redLine = line(ax, [0 0], [0 1], 'Color', 'r', 'LineWidth', 1);
hold(ax, 'off');
xlim(ax, [minTime maxTime]);
ylim(ax, [0 1]);
set(ax, 'XTickLabel', []);
set(ax, 'YTickLabel', []);

% Оптимизация: предварительно вычисляем позиции красной линии
redLinePositions = TimeLineCalcium(selectedFramesIdxNeuro);
    %%
    % Извлечение и запись выбранных кадров в новое видео
    h = waitbar(1/length(selectedFramesIdx), sprintf('Plotting video, frame %d of %d', 0,  length(selectedFramesIdx)));
    for i = 1:length(selectedFramesIdx)
        if ~mod(i,10)
            h = waitbar(i/length(selectedFramesIdx), h, sprintf('Plotting video, frame %d of %d', i,  length(selectedFramesIdx)));
        end
        
        % Установка времени видео
    video.CurrentTime = (selectedFramesIdx(i) - 1) / frameRate;
    
    % Обновляем только красную линию (самая быстрая операция)
    set(redLine, 'XData', [redLinePositions(i) redLinePositions(i)]);
    
    % Получаем кадр графика
    frameGraph = getframe(fig);
    graphImage = frameGraph.cdata;
    
    % Чтение и обработка видео кадра
    frame = readFrame(video);
    
    % Объединение с графиком
    combinedFrame = append_graph_to_frame(frame, graphImage, 0.2);
    
    % Запись в выходное видео
    writeVideo(outputVideo, combinedFrame);    
    
    end
    delete(h);
    close(outputVideo);
    
    fprintf('Видео для нейрона %d сохранено как %s\n', neuronIdx - 1, outputFileName);
end
end

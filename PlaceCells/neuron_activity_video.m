function neuron_activity_video(videoFile, videoPath, csvFile, csvPath, outPath)
% vvp 16.10.24

%%
if nargin<5
    [videoFile, videoPath] = uigetfile('*.mp4', 'Выберите видеофайл (MP4)','w:\Projects\NOF\PlaceCellsData\2_RawCombinedVideo\');
    [csvFile, csvPath] = uigetfile('*.csv', 'Выберите файл таблицы (CSV)', 'w:\Projects\NOF\PlaceCellsData\6_Traces\');
    outPath = 'w:\Projects\NOF\PlaceCellsData\9_NeuronVideo\';
end

if isequal(videoFile, 0) || isequal(csvFile, 0)
    disp('Файл не был выбран.');
    return;
end

%% Полные пути к файлам
videoFilePath = fullfile(videoPath, videoFile);
csvFilePath = fullfile(csvPath, csvFile);

% Чтение видеофайла
video = VideoReader(videoFilePath);
frameRate = video.FrameRate;  % Частота кадров видео (30 фпс)

% Чтение CSV файла с активностью нейронов
data = readtable(csvFilePath);
numNeurons = size(data, 2) - 1;  % Количество нейронов (столбцы, кроме первого)
numFrames = size(data, 1) - 1;   % Количество кадров (строки, кроме первой)

%% Проверка соответствия количества кадров в видео и таблице
if video.NumFrames ~= numFrames
    fprintf('Количество кадров в видео (%d) и в кальции (%d)\n', video.NumFrames, numFrames);
end

%% Для каждого нейрона создаем новое видео
for neuronIdx = 2:numNeurons + 1
    neuronActivity = table2array(data(2:end, neuronIdx));  % Активность нейрона
    
    % Рассчитываем медиану и медианное отклонение активности нейрона
    neuronMedian = median(neuronActivity);
    medAbsDev = mad(neuronActivity, 1);  % Медианное отклонение
    
    % Пороговое значение для активности (медиана + 4*медианное отклонение)
    threshold = neuronMedian + 4 * medAbsDev;
    
    [Indexes, ~, ~,~, TimeLineCalcium, FrameRate] = synchronizer((1:video.NumFrames)', neuronActivity, 'Bonsai', 600);
    length_line = round(FrameRate/2);    
    [selectedFrames, ~, ~,~,~,~] = RefineLine(neuronActivity > threshold, length_line, length_line);
    
%     % debugging plots
%     h = figure; 
%     plot(1:11849, neuronActivity); hold on;
%     plot(1:11849, ones(1,11849)*threshold); hold on;
%     plot(1:11849, neuronActivity./max(neuronActivity)); hold on;
%     plot(1:11849, neuronActivity > threshold); hold on
%     plot(1:11849, selectedFrames*2); hold on

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
    outputVideo.FrameRate = frameRate;
    open(outputVideo);
    fprintf('Plotting video for neuron %d/%d\n', neuronIdx - 1, numNeurons);
    
    % Извлечение и запись выбранных кадров в новое видео
    h = waitbar(1/length(selectedFramesIdx), sprintf('Plotting video, frame %d of %d', 0,  length(selectedFramesIdx)));
    for i = 1:length(selectedFramesIdx)
        if ~mod(i,10)
            h = waitbar(i/length(selectedFramesIdx), h, sprintf('Plotting video, frame %d of %d', i,  length(selectedFramesIdx)));
        end
        
        video.CurrentTime = (selectedFramesIdx(i) - 1) / frameRate;
        frame = readFrame(video);
        neuronActivityNorm = (neuronActivity-min(neuronActivity))./(max(neuronActivity)-min(neuronActivity));
        % Построение графика активности с отметкой на текущем кадре
        fig = figure('visible', 'off');
        plot(TimeLineCalcium,neuronActivityNorm, 'b');
        hold on;
        plot(TimeLineCalcium(selectedFramesIdxNeuro(i)), neuronActivityNorm(selectedFramesIdxNeuro(i)), 'r.', 'MarkerSize', 15, 'LineWidth', 3);  % Жирная точка
        hold off;
        
        % Настройка осей и размеров
        xlim([1 max(TimeLineCalcium)]);
        ylim([0, 1]);
        yticklabels([]);  
        xticklabels([]);       
        
        % Сохранение графика как изображение
        frameGraph = getframe(fig);
        graphImage = frameGraph.cdata;
        close(fig);
        
        % Объединение видео-кадра и графика
        combinedFrame = append_graph_to_frame(frame, graphImage, 0.1);
        
        % Запись объединенного кадра в новое видео
        writeVideo(outputVideo, combinedFrame);        
    
    end
    delete(h);
    close(outputVideo);
    
    fprintf('Видео для нейрона %d сохранено как %s\n', neuronIdx - 1, outputFileName);
end
end

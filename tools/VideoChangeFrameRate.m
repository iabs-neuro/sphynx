function VideoChangeFrameRate(inputVideoPath, newFrameRates)
% vvp 12.01.2024
% Исправляет ошибочную частоту кадров (замедление/ускорение видео).
% Несколько файлов может принять, исправляет в одну частоту кадров
% (поменять значение newFrameRatesв случае запуска скрипта)
if nargin<2
    %%
    [filenames, pathname] = uigetfile({'*.avi;*.mp4', 'Video Files (*.avi, *.mp4)'}, 'Выберите видео файлы', 'MultiSelect', 'on', 'W:\Projects\3DM\Comparision\3DM\2_Combined');
    inputVideoPath = fullfile(pathname,filenames);
    newFrameRates = 55.525;
end

if ~iscell(inputVideoPath)
    inputVideoPath = {inputVideoPath};
end

%% 
for file = 1:length(inputVideoPath)
    % Чтение видео
    videoReader = VideoReader(inputVideoPath{file});
    
    % Получение информации о качестве исходного видео
%     originalQuality = videoReader.Quality; % Для Motion JPEG
%     originalCompression = 'None'; % По умолчанию
%     if contains(videoReader.VideoFormat, 'MJPG')
%         originalCompression = 'Motion JPEG';
%     end
    
    % Создание объекта VideoWriter с максимальным качеством
    [this_path, name, ext] = fileparts(inputVideoPath{file});
    outputVideoPath = fullfile(this_path, [name '_changedFR' ext]);
    
    % Выбор соответствующего профиля в зависимости от формата
    if strcmpi(ext, '.mp4') || strcmpi(ext, '.m4v')
        outputVideoWriter = VideoWriter(outputVideoPath, 'MPEG-4');
%         outputVideoWriter.Quality = 100; % Максимальное качество для MPEG-4
%         outputVideoWriter.VideoBitsPerPixel = videoReader.BitsPerPixel;
    else
        outputVideoWriter = VideoWriter(outputVideoPath, 'Motion JPEG AVI');
        outputVideoWriter.Quality = 100; % Максимальное качество для Motion JPEG
    end
    
    % Сохранение оригинального frame rate
    outputVideoWriter.FrameRate = newFrameRates;
    
    % Открытие объекта для записи
    open(outputVideoWriter);
    
    h = waitbar(1/videoReader.NumFrames, sprintf('Processing video, frame %d of %d', 0, videoReader.NumFrames));
    
    % Процесс обработки кадров
    for k = 1:videoReader.NumFrames
        if ~mod(k, 100)
            h = waitbar(k/videoReader.NumFrames, h, sprintf('Processing video, frame %d of %d', k, videoReader.NumFrames));
        end
        IM = read(videoReader, k);
        writeVideo(outputVideoWriter, IM);
    end
    
    % Закрытие объектов
    delete(h);
    close(outputVideoWriter);
    
    disp(['Видео сохранено с измененным frameRate: ' outputVideoPath]);
end

end

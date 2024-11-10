function VideoChangeFrameRate(inputVideoPath, newFrameRates)
% vvp 12.01.2024
% Исправляет ошибочную частоту кадров (замедление/ускорение видео).
% Несколько файлов может принять, исправляет в одну частоту кадров
% (поменять значение newFrameRatesв случае запуска скрипта)
if nargin<2
    %%
    [filenames, pathname] = uigetfile({'*.avi;*.mp4', 'Video Files (*.avi, *.mp4)'}, 'Выберите видео файлы', 'MultiSelect', 'on', 'd:\Projects\H_mice\RawCombineVideo\');
    inputVideoPath = fullfile(pathname,filenames);
    newFrameRates = 55.5;
end

%% 
for file = 1:length(inputVideoPath)
    
    % Чтение видео
    videoReader = VideoReader(inputVideoPath{file});
    
    % Создайте объект VideoWriter для записи видео с измененным frameRate
    [this_path, name, ext] = fileparts(inputVideoPath{file});
    outputVideoPath = fullfile(this_path, [name '_changedFR' ext]);
    outputVideoWriter = VideoWriter(outputVideoPath, 'MPEG-4');
    outputVideoWriter.FrameRate = newFrameRates;
    
    % Открываем объект для записи и пишем
    open(outputVideoWriter);
    h = waitbar(1/videoReader.NumFrames, sprintf('Processing video, frame %d of %d', 0,  videoReader.NumFrames));
    for k=1:videoReader.NumFrames
%     for k=1:1000
        if ~mod(k,100)
            h = waitbar(k/videoReader.NumFrames, h, sprintf('Processing video, frame %d of %d', k,  videoReader.NumFrames));
        end
        IM = read(videoReader,k);
        writeVideo(outputVideoWriter,IM);
    end
    delete(h);
    
    % Закрываем объект для записи
    close(outputVideoWriter);
    
    disp(['Видео сохранено с измененным frameRate(-ами): ' outputVideoPath]);
end
end

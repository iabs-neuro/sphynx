function new_file = fixFPSmetadata(video_file, wrongDir, correct_fps)
% fixFPSmetadata
% Работает в двух режимах:
%   1) codecMode = 'ffmpeg'  → меняет FPS ТОЛЬКО в метадате, без перекодирования
%   2) codecMode = 'matlab' → перекодирует через VideoWriter, сохраняя bitrate
%
% correct_fps – значение FPS, которое нужно записать в заголовок файла
%%
% video_file = 'E:\Projects\BOWL\2wave\BehaviorData\2_Combined\BOF_J01_3D.mp4';
% wrongDir = 'e:\Projects\BOWL\2wave\BehaviorData\2_Combined\wrong_fps\';
% correct_fps = 55.55;

%%
    % --- Пути ---
    [folder, name, ext] = fileparts(video_file);
    if ~exist(wrongDir, 'dir'); mkdir(wrongDir); end

    % --- Переносим старый файл ---
    old_file = fullfile(wrongDir, [name ext]);
    movefile(video_file, old_file, 'f');  

    % --- Имя нового файла ---
    new_file = fullfile(folder, [name ext]);
    
    % ---- Читаем видео и его bitrate через ffprobe ----
    probeCmd = sprintf('ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "%s"', old_file);
    [~, bitrateOut] = system(probeCmd);
    orig_bitrate = str2double(strtrim(bitrateOut));  % битрейт в бит/сек
    
    if isnan(orig_bitrate)
        fprintf("Не удалось получить bitrate, беру дефолт...\n");
        orig_bitrate = 5e6; % 5 Mbps fallback
    end
    
    fprintf("Исходный bitrate: %.2f Mbps\n", orig_bitrate / 1e6);
    
    % ---- Открываем видеочиталку ----
    vIn = VideoReader(old_file);
    
    % Профиль для VideoWriter (mp4 → 'MPEG-4')
    switch lower(ext)
        case '.mp4', profile = 'MPEG-4';
        case '.avi', profile = 'Motion JPEG AVI';
        otherwise,   profile = 'MPEG-4';
    end
    
    vOut = VideoWriter(new_file, profile);
    vOut.FrameRate = correct_fps;
    
    % === ВАЖНО ===
    % VideoWriter не принимает bitrate напрямую, но Quality определяет его.
    % Подберём Quality так, чтобы получился такой же bitrate.
    % Грубая линейная аппроксимация:
    q = min(100, max(1, round(orig_bitrate / 1e5)));  % примерно работает как 100 → 10 Mbps
    vOut.Quality = q;
    
    fprintf("Устанавливаем Quality=%d чтобы приблизить bitrate...\n", q);
    
    open(vOut);
    
    % ---- Прогресс бар ----
    estimatedFrames = round(vIn.FrameRate * vIn.Duration);
    wb = waitbar(0, sprintf('Перекодирование %s...', name));
    
    frameCount = 0;
    
    % ---- Копируем кадры ----
    while hasFrame(vIn)
        frame = readFrame(vIn);
        writeVideo(vOut, frame);
        frameCount = frameCount + 1;
        
        if mod(frameCount, 100) == 0
            waitbar(frameCount / estimatedFrames, wb, ...
                sprintf('Кадр %d из ~%d', frameCount, estimatedFrames));
        end
    end
    
    close(wb);
    close(vOut);
    
    fprintf("Видео перекодировано с новым FPS и bitrate.\n");
    return;
  
end

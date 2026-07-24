function downloadDemoVideos()

downloadFolder = fullfile(pwd, 'Demo', 'Video');

if ~exist(downloadFolder, 'dir')
    mkdir(downloadFolder);
    fprintf('Создана папка: %s\n', downloadFolder);
end

videoUrls = {
    'https://disk.yandex.ru/i/8ULS0Vg3Q27tPQ', ...
    'https://disk.yandex.ru/i/s45V4KR61tt6HA'
    };

% Имена файлов для сохранения
videoNames = {
    'NOF_H01_1D.mp4', ...
    'NOF_H01_2D.mp4'
    };

fprintf('Начинаем загрузку демо видео...\n');

% Скачиваем каждое видео
for i = 1:length(videoUrls)
    fprintf('Загрузка видео %d из %d...\n', i, length(videoUrls));
    
    outputFile = fullfile(downloadFolder, videoNames{i});
    success = downloadFromYandexDisk(videoUrls{i}, outputFile);
    
    if success
        fprintf('✓ Успешно: %s\n', videoNames{i});
    else
        fprintf('✗ Ошибка: %s\n', videoNames{i});
    end
end

fprintf('Загрузка завершена! Видео находятся в: %s\n', downloadFolder);
end

function success = downloadFromYandexDisk(url, outputFile)
try
    downloadUrl = strrep(url, 'disk.yandex.ru/i/', 'disk.yandex.ru/d/');
    downloadUrl = [downloadUrl, '/?format=pdf&force=true'];
    
    websave(outputFile, downloadUrl);
    
    success = true;
catch ME
    fprintf('Ошибка при загрузке: %s\n', ME.message);
    
    success = alternativeDownload(url, outputFile);
end
end

function success = alternativeDownload(url, outputFile)
try
    if isunix
        [status, ~] = system('which wget');
        if status == 0
            command = sprintf('wget -O "%s" "%s"', outputFile, url);
        else
            command = sprintf('curl -L -o "%s" "%s"', outputFile, url);
        end
    else
        command = sprintf('powershell -Command "Invoke-WebRequest -Uri ''%s'' -OutFile ''%s''"', url, outputFile);
    end
    
    [status, result] = system(command);
    success = (status == 0);
    
    if ~success
        fprintf('Ошибка системной команды: %s\n', result);
    end
    
catch
    success = false;
end
end
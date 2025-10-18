%% download and read video
% Выберите видео файл
[filename, pathname] = uigetfile({'*.avi;*.mp4', 'Video Files (*.avi, *.mp4)'}, 'Выберите видео файл');
if isequal(filename,0) || isequal(pathname,0)
    disp('Отменено.')
    return
end

% Полный путь к видео файлу
videoPath = fullfile(pathname, filename);

video = VideoReader(videoPath);

% Определение середины видео
middleFrameIdx = floor(video.Duration * video.FrameRate / 2);

% Загрузка кадра из середины видео
video.CurrentTime = middleFrameIdx / video.FrameRate;
frame = readFrame(video);

%% main 
% Отображение кадра
imshow(frame);
title('Выберите две точки');

% Выбор двух точек на кадре
[x, y] = ginput(4);

% Вычисление расстояния между точками в пикселях
distancePixels1 = sqrt((x(2) - x(1))^2 + (y(2) - y(1))^2);
distancePixels2 = sqrt((x(4) - x(3))^2 + (y(4) - y(3))^2);

% Ввод пользователя: сколько сантиметров соответствует расстоянию между
% точками
distanceCentimeters1 = input('Сколько сантиметров между 1 и 2 точкой? ');
distanceCentimeters2 = input('Сколько сантиметров между 3 и 4 точкой? ');

% Вычисление разрешения пксл/см
pixelsPerCentimeter1 = distancePixels1 / distanceCentimeters1;
pixelsPerCentimeter2 = distancePixels2 / distanceCentimeters2;

% Вывод результата
fprintf('Количество пикселей на сантиметр между 1-2: %.2f пксл/см\n', pixelsPerCentimeter1);
fprintf('Количество пикселей на сантиметр между 3-4: %.2f пксл/см\n', pixelsPerCentimeter2);
fprintf('Среднее количество пикселей на сантиметр: %.1f пксл/см\n', (pixelsPerCentimeter1+pixelsPerCentimeter2)/2);
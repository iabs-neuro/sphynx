% Запросить путь к основной папке
mainFolderPath = uigetdir('Выберите основную папку');

% Проверка на отмену выбора папки
if mainFolderPath == 0
    disp('Выбор папки отменен');
    return;
end

% Запросить путь к папке для сохранения файлов
saveFolderPath = uigetdir('Выберите папку для сохранения mat-файлов');

% Проверка на отмену выбора папки для сохранения
if saveFolderPath == 0
    disp('Выбор папки для сохранения отменен');
    return;
end

% Получить список всех подпапок
subfolders = dir(mainFolderPath);
subfolders = subfolders([subfolders.isdir]);
subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

%% Перебор всех подпапок
% for folderIdx = 1:length(subfolders)
for folderIdx = 8
    subfolderPath = fullfile(mainFolderPath, subfolders(folderIdx).name);
    
    % Получить список всех файлов TIFF в подпапке
    files = dir(fullfile(subfolderPath, 'filter_*.tif'));
    n_files = length(files);
    if n_files == 0
        disp(['Нет файлов TIFF в папке: ', subfolderPath]);
        continue;
    end
    
    % Инициализация переменной MAT
    MAT = [];
    
    % Инициализация текстового прогресс-бара
    fprintf('Обработка папки %s: [', subfolders(folderIdx).name);
    totalBars = 50;
    progressBars = 0;
    frameCount = 0;
    
    % Чтение и обработка файлов
    for i = 1:n_files
        % Чтение изображения
        IM = double(imread(fullfile(subfolderPath, files(i).name)));
        maxin = max(IM(:));
        IM = IM ./ maxin;
        MAT(i, :, :) = IM;
        
        % Обновление прогресс-бара
        frameCount = frameCount + 1;
        if frameCount / n_files > progressBars / totalBars
            fprintf('=');
            progressBars = progressBars + 1;
        end
    end
    fprintf(']\n');
    
    % Имя mat-файла на основе имени подпапки
    matFileName = fullfile(saveFolderPath, sprintf('%s.mat', subfolders(folderIdx).name));
    
    % Сохранение данных в mat-файл
    save(matFileName, 'MAT');
    disp(['Данные сохранены в ', matFileName]);
end

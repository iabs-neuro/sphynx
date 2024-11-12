%% first rename
% Укажите путь к папке с файлами
folderPath = 'i:\\_STFP\\_VideoData\\2_DLC\\';

% Получаем список всех CSV файлов в папке
files = dir(fullfile(folderPath, '*.csv'));

% Обходим каждый файл и переименовываем его по заданному шаблону
for i = 1:length(files)
    % Исходное имя файла
    oldName = files(i).name;
    
    % Разбиваем имя файла на части по символу '_'
    parts = split(oldName, '_');
    
    % Определяем новый формат имени файла
    % STFP1_D1_DLC_resnet152_MiceUniversal_combined.csv должно стать STFP_A01_D1_T1_track.csv
    % STFP4_D2_T2_DLC_resnet152_MiceUniversal_combined.csv должно стать STFP_A04_D2_T2_track.csv
    
    % Получаем значение после 'STFP' и преобразуем его в нужный формат
    stfpNumber = parts{1}(5:end);  % '1' из 'STFP1'
    newStfpNumber = sprintf('A%02d', str2double(stfpNumber));  % Преобразуем '1' в 'A01'
    
    % Получаем и преобразуем другие части имени файла
    dayPart = parts{2};  % 'D1'
    if length(parts) > 3 && startsWith(parts{3}, 'T')
        timePart = parts{3};  % 'T2'
    else
        timePart = 'T1';  % Если время не указано, добавляем 'T1'
    end
    
    % Определяем суффикс для нового имени файла
    if contains(oldName, 'combined')
        suffix = 'track';
    else
        suffix = 'spikes';
    end
    
    % Формируем новое имя файла
    newName = sprintf('STFP_%s_%s_%s_%s.csv', newStfpNumber, dayPart, timePart, suffix);
    
    % Полный путь к старому и новому файлу
    oldFilePath = fullfile(folderPath, oldName);
    newFilePath = fullfile(folderPath, newName);
    
    % Переименовываем файл
    movefile(oldFilePath, newFilePath);
    
    % Выводим сообщение о переименовании
    disp(['Файл ' oldName ' переименован в ' newName]);
end

%% rename another
% Укажите путь к папке с файлами
folderPath = 'i:\_STFP\_VideoData\3_Presets\';

% Получаем список всех MAT файлов в папке
files = dir(fullfile(folderPath, 'Stfp*.mat'));

% Обходим каждый файл и переименовываем его по заданному шаблону
for i = 1:length(files)
    % Исходное имя файла
    oldName = files(i).name;
    
    % Разбиваем имя файла на части по символу ' ' и '_'
    parts = regexp(oldName, '[ _]', 'split');
    
    % Проверяем, что файл соответствует нужному формату
    if length(parts) >= 5 && startsWith(parts{1}, 'Stfp') && contains(parts{end}, 'Preset.mat')
        % Получаем значение после 'Stfp' и преобразуем его в нужный формат
        stfpNumber = parts{2};  % '1'
        newStfpNumber = sprintf('A%02d', str2double(stfpNumber));  % Преобразуем '1' в 'A01'
        
        % Получаем и преобразуем другие части имени файла
        dayPart = parts{3};  % 'D1'
        timePart = 'T1';  % Используем 'T1'
        suffix = parts{end};  % 'Preset.mat'
        
        % Формируем новое имя файла
        newName = sprintf('STFP_%s_%s_%s_%s', newStfpNumber, dayPart, timePart, suffix);
        
        % Полный путь к старому и новому файлу
        oldFilePath = fullfile(folderPath, oldName);
        newFilePath = fullfile(folderPath, newName);
        
        % Переименовываем файл
        movefile(oldFilePath, newFilePath);
        
        % Выводим сообщение о переименовании
        disp(['Файл ' oldName ' переименован в ' newName]);
    else
        disp(['Файл ' oldName ' не соответствует ожидаемому формату и не был переименован.']);
    end
end

%% rename video
% Укажите путь к папке с файлами
folderPath = 'j:\_Projects\STFP\VT\20fps\STFP_9';

% Получаем список всех m4v видеофайлов в папке
videoFiles = [dir(fullfile(folderPath, '*.m4v')); dir(fullfile(folderPath, '*.mp4'))];

% Обходим каждый файл и переименовываем его по заданному шаблону
for i = 1:length(videoFiles)
    % Исходное имя файла
    oldName = videoFiles(i).name;
    
    % Разбиваем имя файла на части по символу пробела и подчеркивания
    parts = regexp(oldName, '[ _]', 'split');
    
    % Проверяем, что файл соответствует нужному формату
    if length(parts) >= 4
        % Получаем номер мыши и преобразуем его в нужный формат
        stfpNumber = parts{2};  % '1'
        newStfpNumber = sprintf('A%02d', str2double(stfpNumber));  % Преобразуем '1' в 'A01'
        
        % Получаем и преобразуем другие части имени файла
        dayPart = parts{3};  % 'D4'
        if startsWith(parts{4}, 'T')
            timePart = parts{4};  % 'T2'
            numberPart = parts{5};  % '2-9.m4v'
        else
            timePart = 'T1';
            numberPart = parts{4};  % '2-9.m4v'
        end
        
        % Извлекаем первую часть номера и убираем расширение
        numberPart = regexp(numberPart, '^\d+', 'match', 'once');
        
        % Формируем новое имя файла
        newName = sprintf('STFP_%s_%s_%s_%s.m4v', newStfpNumber, dayPart, timePart, numberPart);
        
        % Полный путь к старому и новому файлу
        oldFilePath = fullfile(folderPath, oldName);
        newFilePath = fullfile(folderPath, newName);
        
        % Переименовываем файл
        movefile(oldFilePath, newFilePath);
        
        % Выводим сообщение о переименовании
        disp(['Файл ' oldName ' переименован в ' newName]);
    else
        disp(['Файл ' oldName ' не соответствует ожидаемому формату и не был переименован.']);
    end
end

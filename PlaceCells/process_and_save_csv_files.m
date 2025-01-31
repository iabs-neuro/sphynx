% function process_selected_files(special_list)
    % Выбор папки с файлами
    folderPath = uigetdir('', 'Select Folder with CSV Files');
    if isequal(folderPath, 0)
        disp('No folder selected.');
        return;
    end
    
    special_list = {
    'F01_1D_1T' 'F01_2D_1T' 'F01_3D_1T' 'F01_4D_1T' 'F01_5D_1T'...
    'F04_1D_1T' 'F04_2D_1T' 'F04_3D_1T' 'F04_4D_1T' 'F04_5D_1T'...
    'F09_1D_1T' 'F09_2D_1T' 'F09_3D_1T' 'F09_4D_1T' 'F09_5D_1T'...
    'F12_1D_1T' 'F12_2D_1T' 'F12_3D_1T' 'F12_4D_1T' 'F12_5D_1T'...
    'F29_1D_1T' 'F29_2D_1T' 'F29_3D_1T' 'F29_4D_1T' 'F29_5D_1T'...
    'F38_1D_1T' 'F38_2D_1T' 'F38_3D_1T' 'F38_4D_1T' 'F38_5D_1T'...
    'F40_1D_1T' 'F40_2D_1T' 'F40_3D_1T' 'F40_4D_1T' 'F40_5D_1T'...
    'F48_1D_1T' 'F48_2D_1T' 'F48_3D_1T' 'F48_4D_1T' 'F48_5D_1T'...
    'F52_1D_1T' 'F52_2D_1T' 'F52_3D_1T' 'F52_4D_1T' 'F52_5D_1T'...
    'H27_1D_1T' 'H27_2D_1T' 'H27_3D_1T' 'H27_4D_1T' 'H27_5D_1T'...
    'H32_1D_1T' 'H32_2D_1T' 'H32_3D_1T' 'H32_4D_1T' 'H32_5D_1T' 
};

    % Получение списка всех файлов CSV в папке
    allFiles = dir(fullfile(folderPath, '*.csv'));
    
    % Фильтрация файлов по special_list
    selectedFiles = {};
    for i = 1:length(allFiles)
        for j = 1:length(special_list)
            if contains(allFiles(i).name, special_list{j})
                selectedFiles{end+1} = fullfile(folderPath, allFiles(i).name);
                break; % Если файл подходит, переходим к следующему
            end
        end
    end
    
    % Проверка, нашлись ли подходящие файлы
    if isempty(selectedFiles)
        disp('No matching files found.');
        return;
    end
    
    % Вывод найденных файлов
    disp('Selected files:');
    disp(selectedFiles');
    
    % Указать папку для сохранения обработанных файлов
    savePath = uigetdir('', 'Select Folder to Save Processed Files');
    if isequal(savePath, 0)
        disp('No save folder selected.');
        return;
    end
    
    % Обработка и пересохранение выбранных файлов
    for i = 1:length(selectedFiles)
        % Загружаем CSV как cell array
        data = readcell(selectedFiles{i});
        
        % Удаляем последние 300 строк
        if size(data, 1) > 439
            data = data(1:end-439, :);
        else
            warning('File %s has less than 439 rows, skipping truncation.', selectedFiles{i});
        end
        
        % Сохранение в новую папку
        [~, fileName, fileExt] = fileparts(selectedFiles{i});
        outputFile = fullfile(savePath, [fileName, fileExt]);
        writecell(data, outputFile);
        fprintf('File %s processed and saved to %s\n', fileName, savePath);
    end
% end

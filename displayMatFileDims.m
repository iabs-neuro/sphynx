function dim1 = displayMatFileDims(folderPath)
    % Проверяем, существует ли указанная папка
    if ~isfolder(folderPath)
        error('Указанная папка не существует: %s', folderPath);
    end
    
    % Получаем список всех .mat файлов в папке
    matFiles = dir(fullfile(folderPath, '*.mat'));
    
    % Проверяем, есть ли .mat файлы в папке
    if isempty(matFiles)
        fprintf('В указанной папке нет .mat файлов: %s\n', folderPath);
        return;
    end
    
    fprintf('Найдено %d .mat файлов:\n', length(matFiles));
    fprintf('----------------------------------------\n');
     dim1 = [];
    % Обрабатываем каждый .mat файл
    for i = 1:length(matFiles)
        fileName = matFiles(i).name;
        filePath = fullfile(folderPath, fileName);
        
        try
            % Загружаем данные из .mat файла
            matData = load(filePath);
            
            % Получаем имена переменных в файле
            varNames = fieldnames(matData);
            
            % Проверяем, что в файле ровно одна переменная
            if length(varNames) ~= 1
                fprintf('Файл %s содержит %d переменных (ожидается 1)\n', ...
                        fileName, length(varNames));
                continue;
            end
            
            % Получаем саму матрицу
            matrix = matData.(varNames{1});
            
            % Проверяем, что это действительно матрица
            if ~ismatrix(matrix) && ~isnumeric(matrix)
                fprintf('Файл %s: переменная не является числовой матрицей\n', fileName);
                continue;
            end
            
            % Получаем размерности
            dims = size(matrix);
            dim1 = [dim1 dims(1)];
            % Выводим информацию
            if length(dims) == 2
                fprintf('Файл: %-20s Размер: %dx%d (2D)\n', fileName, dims(1), dims(2));
            elseif length(dims) == 3
                fprintf('Файл: %-20s Размер: %dx%dx%d (3D)\n', fileName, dims(1), dims(2), dims(3));
            else
                fprintf('Файл: %-20s Размер: %s (неподдерживаемая размерность)\n', ...
                        fileName, num2str(dims));
            end
            
        catch ME
            fprintf('Ошибка при обработке файла %s: %s\n', fileName, ME.message);
        end
    end
     dim1
end
function folders = uigetdir2(dialogTitle)
    % Инициализация структуры для хранения путей
    folders = {};
    % Выбор первой папки
    folderName = uigetdir('', dialogTitle);
    while ischar(folderName)
        folders{end+1} = folderName; %#ok<*AGROW>
        % Запрос на выбор следующей папки
        folderName = uigetdir('', sprintf('%s (выбрано %d папок)', dialogTitle, length(folders)));
    end
    % Преобразование в ячейковый массив строк
    if ~isempty(folders)
        folders = folders';
    end
end
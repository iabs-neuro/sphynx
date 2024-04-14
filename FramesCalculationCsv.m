% Запросить путь к папке
folderPath = uigetdir('Выберите папку');

% Проверка на отмену выбора папки
if folderPath == 0
    disp('Выбор папки отменен');
    return;
end

% Получить список всех файлов CSV в папке
csvFiles = dir(fullfile(folderPath, '*.csv'));
 numRows = [];
% Перебор всех файлов
for i = 1:length(csvFiles)
    % Получаем путь к текущему файлу
    filePath = fullfile(folderPath, csvFiles(i).name);
    
    % Считываем файл
    fileData = readtable(filePath);
    
    % Получаем количество строк в файле
%     if mod(i,2) 
        numRows = [ numRows height(fileData)];
%     else
%         numRows = [ numRows; height(fileData)];
%     end
    
    % Выводим информацию о количестве строк
    fprintf('Файл: %s, Количество строк: %d\n', csvFiles(i).name, numRows(i));
end

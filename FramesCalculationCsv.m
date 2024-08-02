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
numCols = [];

% Перебор всех файлов
for i = 1:length(csvFiles)
    % Получаем путь к текущему файлу
    filePath = fullfile(folderPath, csvFiles(i).name);
    
    % Считываем файл
    fileData = readtable(filePath);
    
    % Получаем количество строк и столбцов в файле
    numRows = [numRows; height(fileData)];
    numCols = [numCols; width(fileData)];
    
    % Выводим информацию о количестве строк и столбцов
    fprintf('Файл: %s, Количество строк: %d, Количество столбцов: %d\n', csvFiles(i).name, numRows(i), numCols(i));
end

% Выводим итоговую информацию
fprintf('Обработано файлов: %d\n', length(csvFiles));
fprintf('Суммарное количество строк: %d\n', sum(numRows));
fprintf('Среднее количество строк на файл: %.2f\n', mean(numRows));
fprintf('Среднее количество столбцов на файл: %.2f\n', mean(numCols));

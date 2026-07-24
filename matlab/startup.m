% startup.m - автоматически добавляет все подпапки
function startup
    % Получить путь к папке, где находится этот startup.m
    startupFolder = fileparts(mfilename('fullpath'));
    
    % Добавить ВСЕ подпапки рекурсивно
    addpath(genpath(startupFolder));
    
    % Вывести информацию
    fprintf('Автоматически добавлены все подпапки из: %s\n', startupFolder);
    fprintf('Текущая рабочая директория: %s\n', pwd);
end
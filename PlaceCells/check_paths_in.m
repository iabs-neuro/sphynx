%% Function to check validity of paths and filenames
function isValid = check_paths_in(params_paths)
    % List of required fields and their expected file extensions
    requiredFields = {...
        'filenameWS', '.mat'; ...
        'pathWS', ''; ...
        'filenameNV', '.csv'; ...
        'pathNV', ''; ...
        'filenameTR', '.csv'; ...
        'pathTR', ''; ...
        'filenamePR', '.mat'; ...
        'pathPR', ''; ...
        'pathOut', ''};
    
    isValid = true; % Предполагаем, что все корректно
    
    for i = 1:size(requiredFields, 1)
        field = requiredFields{i, 1};  % Название поля
        ext = requiredFields{i, 2};    % Ожидаемое расширение файла (если применимо)

        % Проверяем, существует ли поле и не является ли оно пустым
        if ~isfield(params_paths, field) || isempty(params_paths.(field))
            disp(['❌ Предупреждение: переменная "' field '" отсутствует или не задана!']);
            isValid = false;
            continue; % Не прерываем проверку, чтобы увидеть все ошибки
        end

        % Если это имя файла, проверяем расширение
        if ~isempty(ext) && ~endsWith(num2str(params_paths.(field)), ext, 'IgnoreCase', true)
            disp(['⚠️ Предупреждение: файл "' params_paths.(field) '" имеет неправильное расширение! Либо файла нет совсем. Ожидалось "' ext '".']);
            isValid = false;
        end
    end
    
    
end


function isValid = check_paths_in_v2(params_paths)
    % Список обязательных полей и их ожидаемые расширения
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
    filePatterns = containers.Map; % Храним шаблоны из имен файлов

    for i = 1:size(requiredFields, 1)
        field = requiredFields{i, 1};
        ext = requiredFields{i, 2};

        % Проверка существования поля и его непустоты
        if ~isfield(params_paths, field) || isempty(params_paths.(field))
            disp(['❌ Предупреждение: переменная "' field '" отсутствует или не задана!']);
            isValid = false;
            continue;
        end

        % Проверка расширения, если это имя файла
        if ~isempty(ext)
            filename = num2str(params_paths.(field));
            if ~endsWith(filename, ext, 'IgnoreCase', true)
                disp(['⚠️ Предупреждение: файл "' filename '" имеет неправильное расширение! Ожидалось "' ext '".']);
                isValid = false;
            end

            % Извлечение шаблона из названия файла
            tokens = regexp(filename, '^([A-Z]+)_([A-Z]\d+)_(\d+)D(\d+)T(\d+)(_.*)?$', 'tokens');
            if isempty(tokens)
                disp(['⚠️ Предупреждение: файл "' filename '" не соответствует ожидаемому шаблону "EXPID_MOUSEID_Dx_Tx"!']);
                isValid = false;
            else
                patternKey = strjoin(tokens{1}, '_'); % Пример: MSS_D01_1D_1T
                filePatterns(field) = patternKey;
            end
        end
    end

    % Проверка согласованности шаблонов у всех файлов
    keysList = filePatterns.keys;
    if ~isempty(keysList)
        referencePattern = filePatterns(keysList{1});
        for k = 2:length(keysList)
            currentPattern = filePatterns(keysList{k});
            if ~strcmp(referencePattern, currentPattern)
                disp(['❌ Ошибка: файл "' keysList{k} '" имеет несовместимое имя (ожидалось "' referencePattern '", получено "' currentPattern '")']);
                isValid = false;
            end
        end
    end
end
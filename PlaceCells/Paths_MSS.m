%% manual defining parameters section
if ~exist('params_paths', 'var') || check_paths_in_v2(params_paths)
    
    % define path for outputs
    params_paths.pathOut = uigetdir('w:\Projects\MSS\ActivityData\PlaceCells\', 'Please specify the path to save the data');
    
    %loading videotracking
    [params_paths.filenameWS, params_paths.pathWS]  = uigetfile('*.mat','Please specify the mat-file from behavior analysis','w:\Projects\MSS\ActivityData\Behav_mat\');
    
    %loading spike file
    [params_paths.filenameNV, params_paths.pathNV]  = uigetfile('*.csv','Please specify the file with spikes','w:\Projects\MSS\ActivityData\Spikes\');
    
    %loading trace file
    [params_paths.filenameTR, params_paths.pathTR]  = uigetfile('*.csv','Please specify the file with traces','w:\Projects\MSS\ActivityData\Traces\');
    
    %loading preset file
    [params_paths.filenamePR, params_paths.pathPR]  = uigetfile('*.mat','Please specify the preset file','w:\Projects\MSS\ActivityData\Presets\');
    
end
function isValid = check_paths_in_v2(params_paths)
    % Список обязательных полей и их ожидаемые расширения
    requiredFields = { ... 
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
    filePatterns = containers.Map; % Храним шаблоны первых частей имен файлов

    firstPart = ''; % Первая часть имени для проверки一致ности всех файлов

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

            % Регулярное выражение для извлечения первой части имени файла
            tokens = regexp(filename, '^([A-Z]+)_([A-Z]+\d+)_(\d+)D_(\d+)T', 'tokens');

            % Проверка на соответствие шаблону
            if isempty(tokens)
                disp(['⚠️ Предупреждение: файл "' filename '" не соответствует ожидаемому шаблону!']);
                isValid = false;
            else
                fileBaseName = strjoin(tokens{1}, '_'); % MSS_D01_1_1

                % Проверяем, совпадает ли первая часть имени со всеми предыдущими
                if isempty(firstPart)
                    firstPart = fileBaseName; % Запоминаем первую часть имени из первого файла
                elseif ~strcmp(firstPart, fileBaseName)
                    disp(['❌ Предупреждение: файл "' filename '" имеет несовместимое имя (ожидалось "' firstPart '", получено "' fileBaseName '")']);
                    isValid = false;
                end

                filePatterns(field) = fileBaseName; % Добавляем имя файла в словарь
            end
        end
    end
end
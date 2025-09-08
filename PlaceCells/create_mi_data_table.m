% function create_mi_data_table()
    % 1. Загрузка выбранных mat-файлов из папки
    [filenames, pathname] = uigetfile('*.mat', 'Select MAT files', 'MultiSelect', 'on');
    
    % Проверка, что файлы были выбраны
    if isequal(filenames, 0)
        disp('No files selected. Exiting function.');
        return;
    end
    
    % Если выбран только один файл, преобразуем в cell array
    if ischar(filenames)
        filenames = {filenames};
    end
    
    % 2. Сначала проверим размерность cells_MI чтобы определить количество столбцов
    % Загружаем первый файл для проверки
    first_file = load(fullfile(pathname, filenames{1}));
    num_mi_columns = size(first_file.cells_MI, 2);
    
    % Создаем имена столбцов
    var_names = {'small_size', 'small_sigma', 'big_size', 'big_sigma'};
    mi_columns_names = arrayfun(@(x) sprintf('MI_%d', x), 1:num_mi_columns, 'UniformOutput', false);
    all_var_names = [var_names, mi_columns_names];
    
    % Создаем матрицу для данных
    num_files = numel(filenames);
    data = zeros(num_files, 4 + num_mi_columns);
    
    % 3. Обработка каждого файла
    for i = 1:num_files
        i
        fullpath = fullfile(pathname, filenames{i});
        mat_data = load(fullpath);
        
        try
            % Извлекаем основные параметры
            data(i, 1) = mat_data.mouse.params_main.kernel_opt.small.size;
            data(i, 2) = mat_data.mouse.params_main.kernel_opt.small.sigma;
            data(i, 3) = mat_data.mouse.params_main.kernel_opt.big.size;
            data(i, 4) = mat_data.mouse.params_main.kernel_opt.big.sigma;
            
            % Извлекаем значения cells_MI(4,:)
            data(i, 5:end) = mat_data.cells_MI(4, :);
            
        catch ME
            warning('Error processing file %s: %s', filenames{i}, ME.message);
            data(i, :) = NaN;
        end
    end
    
    % 4. Создаем таблицу
    T = array2table(data, 'VariableNames', all_var_names);
    
    % Добавляем имена файлов как первый столбец
    T = addvars(T, filenames', 'Before', 1, 'NewVariableNames', 'filename');
    
    % Отображаем таблицу
    disp(T);
    
    % Сохраняем таблицу
    writetable(T, 'w:\\Projects\\NOF\\ActivityData\\PlaceCells\\mi_data_kernel_opt_results.csv');
    save('w:\\Projects\\NOF\\ActivityData\\PlaceCells\\mi_data_kernel_opt_table.mat', 'T');
    
    disp('Results saved to mi_data_kernel_opt_results.csv and mi_data_kernel_opt_table.mat');
% end

folder_path = 'd:\Projects\H_mice\NOF\dfsg\\';
out_path = 'd:\Projects\H_mice\NOF\Filters_mat_doubled\';
mat_files = dir(fullfile(folder_path, '*.mat'));

%%
% Перебрать каждый файл .mat
for i = 1:length(mat_files)
    % Загрузить данные из файла .mat
    data = load(fullfile(folder_path, mat_files(i).name));
    
    % Получить переменную из файла (предположим, что переменная называется 'matrix_data')
    if isfield(data, 'A')
        % Проверка на существование переменной 'matrix_data' в файле .mat
        matrix_data = data.A;
        
        % Переконвертировать переменную в тип double (если она уже не double)
        if ~isa(matrix_data, 'double')
            matrix_data = double(matrix_data);
            
            % Сохранить переменную обратно в файл .mat, без перезаписи
            [~, name, ext] = fileparts(mat_files(i).name);
            save(fullfile(out_path, [name(1:10) '_converted' ext]), 'matrix_data', '-v7.3');
        else
            disp(['Переменная в файле ' mat_files(i).name ' уже является типом double.']);
        end
    else
        disp(['В файле ' mat_files(i).name ' нет переменной A.']);
    end
end

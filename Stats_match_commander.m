
% FileNames = {
%     'NOF_H01';'NOF_H02';'NOF_H03';'NOF_H06';
%     'NOF_H07';'NOF_H08';'NOF_H09';'NOF_H14';
%     'NOF_H19';'NOF_H23';'NOF_H26';'NOF_H27';
%     'NOF_H31';'NOF_H32';'NOF_H33';'NOF_H36';'NOF_H39'
%     };

% FileNames = {
%     'RFC_F01';'RFC_F04';'RFC_F05';'RFC_F06';'RFC_F07';'RFC_F08';'RFC_F09';'RFC_F11';'RFC_F12'
%     'RFC_F14';'RFC_F15';'RFC_F19';'RFC_F20';'RFC_F26';'RFC_F28';'RFC_F29';'RFC_F30';
%     'RFC_F31';'RFC_F32';'RFC_F34';'RFC_F35';'RFC_F36';'RFC_F37';'RFC_F38';'RFC_F40';
%     'RFC_F41';'RFC_F48';'RFC_F52';'RFC_F53';'RFC_F54'
%     };

FileNames = {
    '3DM_D14' '3DM_D17' '3DM_F31' '3DM_F35' '3DM_F37' '3DM_F43' '3DM_F48' '3DM_F52' '3DM_F54' ...
    '3DM_F28' '3DM_F29' '3DM_F30' '3DM_F36' '3DM_F40' '3DM_F26' '3DM_F36'
    };

folder_path_main = 'D:\_Projects\3DM\CalciumData\8_Cellreg\';
OutPath = 'D:\_Projects\3DM\CalciumData\8_Cellreg\Statsmatch\';

%% loading mat-file
All_match = zeros(length(FileNames),8);
match_15 = zeros(length(FileNames),6);

for file = 1:length(FileNames)

    % Укажите путь к папке
    folder_path = sprintf('%s\\%s\\',folder_path_main,FileNames{file});
    
    % Получение списка всех файлов в папке
    file_list = dir(folder_path);
    
    % Фильтруем файлы, имя которых начинается с "cellRegistered_"
    matching_files = {};
    for k = 1:length(file_list)
        if startsWith(file_list(k).name, 'cellRegistered_')
            matching_files{end+1} = file_list(k).name;
        end
    end
    
    % Проверяем, найден ли файл
    if isempty(matching_files)
        error('Не найдено ни одного файла, начинающегося на "cellRegistered_"');
    elseif length(matching_files) > 1
        error('Найдено несколько файлов, начинающихся на "cellRegistered_". Проверьте папку.');
    else
        % Если файл найден, формируем полный путь и загружаем
        file_name = matching_files{1};
        full_file_path = sprintf('%s%s', folder_path, file_name);
        disp(['Загружается файл: ', full_file_path]);
        
        % Загрузка файла
        load(full_file_path);
    end
    
    Cell_table = cell_registered_struct.cell_to_index_map./cell_registered_struct.cell_to_index_map;
    Cell_table(isnan(Cell_table)) = 0;
    Cell_info = sum(Cell_table,2);
    
    All_match(file,1) = length(Cell_info);
    All_match(file,2) = length(find(Cell_info==7));
    All_match(file,3) = length(find(Cell_info==6));
    All_match(file,4) = length(find(Cell_info==5));
    All_match(file,5) = length(find(Cell_info==4));
    All_match(file,6) = length(find(Cell_info==3));
    All_match(file,7) = length(find(Cell_info==2));
    All_match(file,8) = length(find(Cell_info==1));
    %     disp(All_match);
    
    Cell_info = sum(Cell_table(:,1:5),2);
    match_15(file,1) = length(Cell_info);
    match_15(file,2) = length(find(Cell_info==5));
    match_15(file,3) = length(find(Cell_info==4));
    match_15(file,4) = length(find(Cell_info==3));
    match_15(file,5) = length(find(Cell_info==2));
    match_15(file,6) = length(find(Cell_info==1));
    %     disp(match_15);
    
    csvwrite(sprintf('%s%s.csv', folder_path, FileNames{file}), cell_registered_struct.cell_to_index_map);
end


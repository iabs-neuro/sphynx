function mouse = createOutputDirectories(mouse)
    % CreateOutputDirectories - Создает уникальную папку для выходных данных
    % и дополнительные подкаталоги в зависимости от настроек.
    %
    % Вход:
    %   mouse - структура с настройками путей и опциями графиков.
    %
    % Выход:
    %   mouse - обновленная структура с обновленным путём для выходных данных.
    
    % Формирование уникального имени папки
    path_folder = sprintf('%s_%s', mouse.params_paths.filenameOut, date);
    num_dir = 1;
    while isfolder(sprintf('%s\\%s_%d', mouse.params_paths.pathOut, path_folder, num_dir))
        num_dir = num_dir + 1;
    end
    
    % Создание папки
    [success, ~, ~] = mkdir(mouse.params_paths.pathOut, sprintf('%s_%d', path_folder, num_dir));
    while ~success
        [success, ~, ~] = mkdir(mouse.params_paths.pathOut, sprintf('%s_%d', path_folder, num_dir));
    end
    
    % Обновление пути
    mouse.params_paths.pathOut = sprintf('%s\\%s_%d', mouse.params_paths.pathOut, path_folder, num_dir);
    
    % Создание дополнительных папок в зависимости от опций
    if mouse.plot_opt.Plot_Single_Spike
        mkdir(mouse.params_paths.pathOut, 'Spikes');
    end
    if mouse.plot_opt.Plot_Spike
        mkdir(mouse.params_paths.pathOut, 'Heatmap_Spike');
    end
    if mouse.plot_opt.Plot_Spike_Smooth
        mkdir(mouse.params_paths.pathOut, 'Heatmap_Spike_Smooth');
    end
    if mouse.plot_opt.Plot_FiringRate
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Informative');
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_NOT_Informative');
    end
    if mouse.plot_opt.Plot_FiringRate_Smooth
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Smooth');
    end
    if mouse.plot_opt.Plot_FiringRate_Smooth_Thres
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Smooth_Thres_NOT_Informative');
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Smooth_Thres_Informative');
    end
    if mouse.plot_opt.Plot_FiringRate_Fields
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Fields');
    end
    if mouse.plot_opt.Plot_FiringRate_Fields_Corrected
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Fields_Corrected_NOT_Inform');
        mkdir(mouse.params_paths.pathOut, 'Heatmap_FiringRate_Fields_Corrected_Inform');
    end
    if mouse.plot_opt.Plot_WaterShed
        mkdir(mouse.params_paths.pathOut, 'WaterShed');
    end
    if mouse.plot_opt.Plot_WaterShedField
        mkdir(mouse.params_paths.pathOut, 'WaterShedFields');
    end
    if mouse.plot_opt.Plot_Field
        mkdir(mouse.params_paths.pathOut, 'Heatmap_Fields_Real');
        mkdir(mouse.params_paths.pathOut, 'Heatmap_Fields_NOT_Real');
    end
    
    disp('Созданы директории для выходных данных');
end

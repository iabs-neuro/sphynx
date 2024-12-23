function PlotPC(mouse, mode)
    % PlotPC - Функция для построения графиков в зависимости от режима
    % Входные параметры:
    %   mouse - структура с данными
    %   mode - режим построения графиков ('coordinate')

    % Проверка входного параметра mode
    if nargin < 2
        error('Необходимо указать режим построения графика');
    end

    % Построение графиков в зависимости от режима
    switch mode
        case 'coordinate'
            % X координата
            h = figure('Position', mouse.params_main.Screensize);
            plot(mouse.time, mouse.x_bad, 'b');hold on; % Оригинальные данные            
            plot(mouse.time, mouse.x, 'r'); % Интерполированные и сглаженные данные
            
            title('X vs x smooth', 'FontSize', mouse.params_main.FontSizeLabel);
            xlabel(sprintf('Time, %s', mouse.params_main.TimeMode), 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('X coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);
            legend({'Original', 'Interpolated and Smoothed'});
            
            saveas(h, sprintf('%s\\%s_x_coordinate.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            saveas(h, sprintf('%s\\%s_x_coordinate.fig', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            delete(h);

            % Y координата
            h = figure('Position', mouse.params_main.Screensize);
            plot(mouse.time, mouse.y_bad, 'b');hold on; % Оригинальные данные            
            plot(mouse.time, mouse.y, 'r'); % Интерполированные и сглаженные данные
            
            title('Y vs y smooth', 'FontSize', mouse.params_main.FontSizeLabel);
            xlabel(sprintf('Time, %s', mouse.params_main.TimeMode), 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Y coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);            
            legend({'Original', 'Interpolated and Smoothed'});
            
            saveas(h, sprintf('%s\\%s_y_coordinate.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            saveas(h, sprintf('%s\\%s_y_coordinate.fig', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            delete(h);
            
        case 'velocity'
            
            % скорость
            h = figure('Position', mouse.params_main.Screensize);
            plot(mouse.time,mouse.velocity,'r');hold on; % скорость
            plot(mouse.time,mouse.velocity_binary*mouse.params_main.vel_border,'g'); % скорость с порогом быстрой побежки
            
            title('V vs v smooth','FontSize', mouse.params_main.FontSizeLabel);
            xlabel(sprintf('Time, %s', mouse.params_main.TimeMode),'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Velocity, cm/s','FontSize', mouse.params_main.FontSizeLabel);
            legend({'Velocity', 'Locomotions'});
            
            saveas(h, sprintf('%s\\%s_velocity.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            saveas(h, sprintf('%s\\%s_velocity.fig',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);
        case 'spike'
            
            if mouse.plot_opts.Plot_Single_Spike
                h = figure('Position', mouse.params_main.Screensize);
                axis(axes);
                title(sprintf('Trajectory of mouse with n = %d (%d) Ca2+ events (in mov, red) of cell #%d', CellInfo(cell).spikes_all_count,CellInfo(cell).spikes_in_mov_count, cell), 'FontSize', params_main.FontSizeTitle);
                xlabel('X coordinate, cm','FontSize', params_main.FontSizeLabel);ylabel('Y coordinate, cm','FontSize', params_main.FontSizeLabel);
                hold on;plot(mouse.x,mouse.y, 'b');
                hold on;DrawLine(mouse.x, mouse.y, mouse.velcam, 1, 'g', 0, 1);
                hold on;plot(mouse.x(CellInfo(cell).spikes_all_frames),mouse.y(CellInfo(cell).spikes_all_frames),'k*', 'MarkerSize',round(params_main.MarksizeSpikes/2), 'LineWidth',round(params_main.LineWidthSpikes/2));
                hold on;plot(mouse.x(CellInfo(cell).spikes_in_mov_frames),mouse.y(CellInfo(cell).spikes_in_mov_frames),'r*', 'MarkerSize',params_main.MarksizeSpikes, 'LineWidth',params_main.LineWidthSpikes);
                set(gca, 'FontSize', params_main.FontSizeLabel);
                saveas(h, sprintf('%s\\Spikes\\%s_Spikes_Cell_%d.png',mouse.params_paths.pathOut,mouse.filenameOut,cell));
                delete(h);
            end

        otherwise
            error('Неизвестный режим: %s', mode);
    end
end

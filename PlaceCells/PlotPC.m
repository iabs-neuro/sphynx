function PlotPC(mouse, mode, cell)
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
            plot(mouse.time, mouse.x_bad, 'b');hold on;                     % Оригинальные данные            
            plot(mouse.time, mouse.x, 'r');                                 % Интерполированные и сглаженные данные
            
            title('X vs x smooth', 'FontSize', mouse.params_main.FontSizeLabel);
            xlabel(sprintf('Time, %s', mouse.params_main.TimeMode), 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('X coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);
            legend({'Original', 'Interpolated and Smoothed'});
            
            saveas(h, sprintf('%s\\%s_x_coordinate.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            saveas(h, sprintf('%s\\%s_x_coordinate.fig', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            delete(h);

            % Y координата
            h = figure('Position', mouse.params_main.Screensize);
            plot(mouse.time, mouse.y_bad, 'b');hold on;                     % Оригинальные данные            
            plot(mouse.time, mouse.y, 'r');                                 % Интерполированные и сглаженные данные
            
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
            plot(mouse.time,mouse.velocity_binary*mouse.params_main.vel_border,'g');
            
            title('V vs v smooth','FontSize', mouse.params_main.FontSizeLabel);
            xlabel(sprintf('Time, %s', mouse.params_main.TimeMode),'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Velocity, cm/s','FontSize', mouse.params_main.FontSizeLabel);
            legend({'Velocity', 'Locomotions'});
            
            saveas(h, sprintf('%s\\%s_velocity.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            saveas(h, sprintf('%s\\%s_velocity.fig',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);
            
        case 'single_spike'
            
            % активность нейронов
            for ncell = 1:mouse.cells_count_for_analysis
                
                h = figure('Position', mouse.params_main.Screensize);
                plot(mouse.x,mouse.y, 'b');hold on;                                         % траектория животного
                DrawLine(mouse.x, mouse.y, mouse.velocity_binary, 1, 'g', 0, 1);hold on;    % траектория во время побежек
                plot(mouse.x(cell(ncell).spikes_in_rest_frames),mouse.y(cell(ncell).spikes_in_rest_frames),'k*', 'MarkerSize',round(mouse.params_main.MarksizeSpikes/2), 'LineWidth',round(mouse.params_main.LineWidthSpikes/2));hold on;
                plot(mouse.x(cell(ncell).spikes_in_mov_frames),mouse.y(cell(ncell).spikes_in_mov_frames),'r*', 'MarkerSize',mouse.params_main.MarksizeSpikes, 'LineWidth',mouse.params_main.LineWidthSpikes);
                
                axis(mouse.axes);
                title(sprintf('Trajectory of mouse with n = %d (%d) Ca2+ events (in mov, red) of cell #%d', cell(ncell).spikes_all_count,cell(ncell).spikes_in_mov_count, ncell), 'FontSize', mouse.params_main.FontSizeTitle);
                xlabel('X coordinate, cm','FontSize', mouse.params_main.FontSizeLabel);
                ylabel('Y coordinate, cm','FontSize', mouse.params_main.FontSizeLabel);
                set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
                legend({'Rest', 'Locomotion'});
                
                saveas(h, sprintf('%s\\Spikes\\%s_Spikes_Cell_%d.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
                delete(h);
                
            end
            
        case 'all_spikes'
            
            % all spikes from all cells
            h = figure('Position', mouse.params_main.Screensize);
            plot(mouse.x,mouse.y, 'b');hold on;
            DrawLine(mouse.x, mouse.y, mouse.velocity_binary, 1, 'g', 0, 1);hold on;
            for ncell=1:mouse.cells_count_for_analysis
                plot(mouse.x(cell(ncell).spikes_in_mov_frames),mouse.y(cell(ncell).spikes_in_mov_frames),'r*', 'MarkerSize',mouse.params_main.MarksizeSpikesAll, 'LineWidth',mouse.params_main.LineWidthSpikes);
                hold on;
                plot(mouse.x(cell(ncell).spikes_in_rest_frames),mouse.y(cell(ncell).spikes_in_rest_frames),'k*', 'MarkerSize',round(mouse.params_main.MarksizeSpikesAll/2), 'LineWidth',round(mouse.params_main.LineWidthSpikes/2));
                hold on;
            end
            
            axis(mouse.axes);
            title('Trajectory of mouse with all Ca2+ events', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('X coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Y coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
            legend({'Rest', 'Locomotion'});
            
            saveas(h, sprintf('%s\\%s_spike_all_plot.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            saveas(h, sprintf('%s\\%s_spike_all_plot.fig',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);
            
            % histogram of ratio 'spikes_in_mov_frequency'/'spikes_in_rest_frequency'
            h = figure('Position', mouse.params_main.Screensize);
            histogram([cell.frequency_ratio_mov_rest], 'BinMethod','fd');
            title('Histogram of Ca2+ events frequency ratio in locomotions to rests', 'FontSize', mouse.params_main.FontSizeTitle);
            saveas(h, sprintf('%s\\%s_frequency_ratio_in_locomotions.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);
            
        otherwise
            error('Неизвестный режим: %s', mode);
    end
end

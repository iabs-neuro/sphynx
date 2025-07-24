function PlotPC(mouse, mode, cells, cellmaps)
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
    case 'allmap'

        %% Сводная картинка с использованием draw_heatmap
        for ncell = 1:mouse.cells_count_for_analysis
            h = figure('Position', [100 100 1200 900], 'Color', 'w');


            % ===== Верхний ряд: карты спайков =====
            % 1. Карта спайков (raw)
            subplot('Position', [0.05 0.7 0.25 0.25]);
            draw_heatmap(cellmaps(ncell).spike, [], [], [], bin_size, x_kcorr, shift, mouse.params_main.heatmap_opt.spike);
            axis image off;
            title('Spike Map (raw)', 'FontSize', 10);

            % 2. Сглаженная карта спайков
            subplot('Position', [0.35 0.7 0.25 0.25]);
            draw_heatmap(cellmaps(ncell).spike_smoothed, [], [], [], bin_size, x_kcorr, shift, mouse.params_main.heatmap_opt.spike);
            axis image off;
            title('Spike Map (smoothed)', 'FontSize', 10);

            % 3. Обрезанная карта спайков
            subplot('Position', [0.65 0.7 0.25 0.25]);
            draw_heatmap(cellmaps(ncell).spike_refined, [], [], [], bin_size, x_kcorr, shift, opt);
            axis image off;
            title('Spike Map (refined)', 'FontSize', 10);

            % ===== Средний ряд: карты firing rate =====
            % 1. Карта firing rate (raw)
            subplot('Position', [0.05 0.4 0.25 0.25]);
            draw_heatmap(cellmaps(ncell).firingrate, [], [], [], bin_size, x_kcorr, shift, opt);
            axis image off;
            title('Firing Rate (raw)', 'FontSize', 10);

            % 2. Сглаженная карта firing rate
            subplot('Position', [0.35 0.4 0.25 0.25]);
            draw_heatmap(cellmaps(ncell).firingrate_smoothed, [], [], [], bin_size, x_kcorr, shift, opt);
            axis image off;
            title('Firing Rate (smoothed)', 'FontSize', 10);

            % 3. Обрезанная карта firing rate
            subplot('Position', [0.65 0.4 0.25 0.25]);
            draw_heatmap(cellmaps(ncell).firingrate_refined, [], [], [], bin_size, x_kcorr, shift, opt);
            axis image off;
            title('Firing Rate (refined)', 'FontSize', 10);

            % ===== Нижний ряд: карта времени и график активности =====
            % 1. Карта времени нахождения (оставляем imagesc)
            subplot('Position', [0.05 0.05 0.25 0.25]);
            imagesc(mouse.ocuppancy_map.time_smoothed);
            axis image off;
            title('Occupancy Time Map', 'FontSize', 10);
            colorbar;

            % 2. График активности нейрона (без изменений)
            subplot('Position', [0.35 0.05 0.55 0.25]);
            plot(mouse.time, cells(ncell).trace, 'b', 'LineWidth', 1);
            xlabel('Time (s)', 'FontSize', 10);
            ylabel('Activity (a.u.)', 'FontSize', 10);
            xlim([min(mouse.time) max(mouse.time)]);
            box off;
            grid on;
            title('Neuronal Activity Trace', 'FontSize', 10);

            % Добавляем SNR в правый нижний угол
            annotation('textbox', [0.78 0.33 0.1 0.05], ...
                'String', sprintf('SNR: %.2f', cells(ncell).SNR), ...
                'FontSize', 10, ...
                'FontWeight', 'bold', ...
                'EdgeColor', [0.3 0.3 0.3], ...
                'BackgroundColor', [1 1 1], ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'Margin', 2, ...
                'LineWidth', 0.8);

            % Сохранение
            saveas(h, sprintf('%s\\CompositeMaps\\%s_Cell_%d.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut, ncell));
            if ~mouse.params_main.ShowFigures
                close(h);
            end
        end

    case 'trace map'

        for ncell = mouse.cells_active
            draw_heatmap( ...
                mouse.behav_opt.rgb_image, ...
                mouse.params_main.heatmap_opt.trace, ...
                cellmaps(ncell).trace_refined, ...
                0, ...
                mouse.x_track, ...
                mouse.y_track, ...
                mouse.shift, ...
                mouse.behav_opt.x_kcorr, ...
                mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
                cellmaps(ncell).spikes   ...
                );
            
            title(sprintf('Trace activity (trace map), refined, of cell %d', ncell), ...
                'FontSize', mouse.params_main.FontSizeTitle);
            saveas(gcf, sprintf('%s\\Heatmap_Trace\\%s_Heatmap_Trace_Cell_%d.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut, ncell));
            clf; close;
        end

    case 'firing rate summary'

        % activity_map_summary, firingrate
        draw_heatmap( ...
            mouse.behav_opt.rgb_image, ...
            mouse.params_main.heatmap_opt.spike, ...
            mouse.activity_map_summary.firingrate, ...
            0, ...
            mouse.x_track, ...
            mouse.y_track, ...
            mouse.shift, ...
            mouse.behav_opt.x_kcorr, ...
            mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
            [] ...
            );

        title('Firing rate for all cells(#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
        saveas(gcf, sprintf('%s\\%s_Heatmap_AllCells_FiringRate.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
        clf; close;

        % activity_map_summary, firingrate normalized
        draw_heatmap( ...
            mouse.behav_opt.rgb_image, ...
            mouse.params_main.heatmap_opt.spike, ...
            mouse.activity_map_summary.firingrate_normalized, ...
            0, ...
            mouse.x_track, ...
            mouse.y_track, ...
            mouse.shift, ...
            mouse.behav_opt.x_kcorr, ...
            mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
            [] ...
            );

        title('Firing rate for all cells normalized (#/min)', 'FontSize', mouse.params_main.FontSizeTitle);
        saveas(gcf, sprintf('%s\\%s_Heatmap_AllCells_FiringRate_Normalized.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
        clf; close;


        if mouse.cells_active_count

            % histogram, MI (bit/Ca2+)
            h = figure('Position', mouse.params_main.Screensize);
            histogram(mouse.cells_active_MI_bit_event, 'BinMethod','fd');
            title('Histogram of cell''s MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
            saveas(h, sprintf('%s\\%s_Histogram_MI_bit_event.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            delete(h);

            % histogram, MI (bit/min)
            h = figure('Position', mouse.params_main.Screensize);
            histogram(mouse.cells_active_MI_bit_time, 'BinMethod','fd');
            title('Histogram of cell''s MI, bit/min', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
            saveas(h, sprintf('%s\\%s_Histogram_MI_bit_time.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            delete(h);

            % histogram, MI (z-scored)
            h = figure('Position', mouse.params_main.Screensize);
            histogram(mouse.cells_active_MI_zscored, 'BinMethod','fd');
            title('Histogram of cell''s MI, z-scored', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('MI, z-scored', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
            saveas(h, sprintf('%s\\%s_Histogram_MI_zscored.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
            delete(h);

            % MI, bit/Ca2+ and MI, z-scored
            h = figure('Position', mouse.params_main.Screensize);
            scatter(mouse.cells_active_MI_bit_event, mouse.cells_active_MI_zscored, mouse.params_main.MarksizeSpikes, 'k', 'filled');
            yline(mouse.params_main.S_sigma, 'r--', 'LineWidth', 2);
            title('MI (bit/Ca^{2+}) and MI (z-scored)', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('MI, z-scored', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);

            saveas(h, sprintf('%s\\%s_MI_event_zscored.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);

            % MI, bit/min and MI, z-scored
            h = figure('Position', mouse.params_main.Screensize);
            scatter(mouse.cells_active_MI_bit_time, mouse.cells_active_MI_zscored, mouse.params_main.MarksizeSpikes, 'k', 'filled');
            yline(mouse.params_main.S_sigma, 'r--', 'LineWidth', 2);
            title('MI (bit/min) and MI (z-scored)', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('MI, z-scored', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);

            saveas(h, sprintf('%s\\%s_MI_time_zscored.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);

            % MI, bit/min and MI, bit/event
            h = figure('Position', mouse.params_main.Screensize, 'Color', 'w');
            main_ax = axes('Position', [0.15 0.15 0.8 0.8]);
            scatter(mouse.cells_active_MI_bit_time, mouse.cells_active_MI_bit_event, mouse.params_main.MarksizeSpikes, 'k', 'filled'); hold on;
            [~,~,active_indx] = intersect(mouse.cells_informative,mouse.cells_active);
            scatter(mouse.cells_active_MI_bit_time(active_indx), mouse.cells_active_MI_bit_event(active_indx), mouse.params_main.MarksizeSpikes, 'r', 'filled'); hold on;
            title('MI (bit/min) and MI (z-scored)', 'FontSize', mouse.params_main.FontSizeTitle);
            xlabel('MI, bit/min', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('MI, bit/Ca^{2+}', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel, 'TickDir', 'in', 'Box', 'on');

            ax_xdist = axes('Position', [0.15 0.15 0.8 0.1]);
            histogram(mouse.cells_active_MI_bit_time, 'BinMethod', 'fd', 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            ax_xdist.XAxis.Visible = 'off'; ax_xdist.YAxis.Visible = 'off'; ax_xdist.Color = 'none'; ax_xdist.YAxisLocation = 'right';

            ax_ydist = axes('Position', [0.15 0.15 0.1 0.8]);
            histogram(mouse.cells_active_MI_bit_event, 'BinMethod', 'fd', 'Orientation', 'horizontal', 'FaceColor', [0.9 0.4 0.3], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            ax_ydist.XAxis.Visible = 'off'; ax_ydist.YAxis.Visible = 'off'; ax_ydist.Color = 'none';

            linkaxes([main_ax, ax_xdist], 'x');
            linkaxes([main_ax, ax_ydist], 'y');

            saveas(h, sprintf('%s\\%s_MI_time_event.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
            delete(h);
        end

    case 'firing rate'

        for ncell = mouse.cells_active

            draw_heatmap( ...
                mouse.behav_opt.rgb_image, ...
                mouse.params_main.heatmap_opt.spike, ...
                cellmaps(ncell).firingrate_refined, ...
                mouse.max_bin.firingrate_refined, ...
                mouse.x_track, ...
                mouse.y_track, ...
                mouse.shift, ...
                mouse.behav_opt.x_kcorr, ...
                mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
                cellmaps(ncell).spikes ... % !!! check for vel_opt
                );

            title(sprintf('Cell %d. Ca2+ events: %d, MI = %.2f, MI\\_shuffle = %.3f, SIGMA\\_shuffle = %.3f, MI\\_Zscore = %.1f', ...
                ncell, ...
                cells(ncell).spikes_all_count, ...
                cells(ncell).MI_bit_event, ...
                cells(ncell).MI_mean_shuffles, ...
                cells(ncell).MI_std_shuffles, ...
                cells(ncell).MI_zscore), ...
                'FontSize', mouse.params_main.FontSizeTitle);
            saveas(gcf, sprintf('%s\\Heatmap_FiringRate_Smooth\\%s_Heatmap_FiringRate_Smoothed_Cell_%d.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut, ncell));
            clf; close;
        end
        
    case 'occupancy'
        draw_heatmap( ...
            mouse.behav_opt.rgb_image, ...
            mouse.params_main.heatmap_opt.track, ...
            mouse.occupancy_map.time_smoothed, ...
            0, ...
            mouse.x_track, ...
            mouse.y_track, ...
            mouse.shift, ...
            mouse.behav_opt.x_kcorr, ...
            mouse.params_main.bin_size_cm*mouse.behav_opt.pxl2sm, ...
            [] ...
            );
        title(sprintf('Occupancy map smoothed (%s)',mouse.params_main.TimeMode), 'FontSize', mouse.params_main.FontSizeTitle);
        saveas(gcf,sprintf('%s\\%s_Heatmap_occupancy.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
        clf; close;
        
    case 'arena_and_track'
        
        figure;
        imshow(mouse.behav_opt.GoodVideoFrameGray); hold on;
        plot(mouse.x_track, mouse.y_track); hold on;
        plot(mouse.arena_opt(1).border_x, mouse.arena_opt(1).border_y);
        
        title('Arena with trajectory', 'FontSize', mouse.params_main.FontSizeLabel);
        legend({'Trajectory', 'Arena border'});
        
        saveas(gcf, sprintf('%s\\%s_x_arena_with_track.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
        saveas(gcf, sprintf('%s\\%s_x_arena_with_track.fig', mouse.params_paths.pathOut, mouse.params_paths.filenameOut));
        clf; close;
    
    case 'coordinate'
        
        % X координата
        h = figure('Position', mouse.params_main.Screensize);        
        set(gcf, 'DefaultAxesFontSize', mouse.params_main.FontSizeLabel);
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

        graf_trace_ratio = 0.8;
        for ncell = 1:mouse.cells_for_analysis_count

            h_combined = figure('Position', [1 1 mouse.params_main.Screensize(4)/(1+(1-graf_trace_ratio)/graf_trace_ratio) mouse.params_main.Screensize(4)]);
            subplot('Position', [0.2 1-graf_trace_ratio+0.2 0.6 graf_trace_ratio-0.3]); % [left bottom width height]
            
            % график траектории с кальциевыми событиями
            h1 = plot(mouse.x,mouse.y, 'b');hold on;
            h2 = DrawLine(mouse.x, mouse.y, mouse.velocity_binary, 1, 'g', 0, 1); hold on;
            h3 = plot(mouse.x(cells(ncell).spikes_in_rest_frames),mouse.y(cells(ncell).spikes_in_rest_frames),'k*', 'MarkerSize',mouse.params_main.MarksizeSpikes, 'LineWidth',mouse.params_main.LineWidthSpikes); hold on;
            h4 = plot(mouse.x(cells(ncell).spikes_in_mov_frames),mouse.y(cells(ncell).spikes_in_mov_frames),'r*', 'MarkerSize',mouse.params_main.MarksizeSpikes, 'LineWidth',mouse.params_main.LineWidthSpikes);
            
            axis(mouse.axes);
            xlabel('X, cm','FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Y, cm','FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
            title(sprintf('%s. Cell #%d', strrep(mouse.params_paths.filenameOut, '_', '\_'), ncell), 'FontSize', mouse.params_main.FontSizeTitle);
            
            legend([h1, h2, h3, h4], {'Rest','Locomotion','Ca^{2+}, all events', 'Ca^{2+}, in locomotion'},'FontSize', round(mouse.params_main.FontSizeTitle*2/3), 'Position', [0.85 0.8 0.1 0.05]);
            
            % активность нейрона
            subplot('Position', [0.2 0.1 0.6 1-graf_trace_ratio]);
            plot(mouse.time, cells(ncell).trace, 'b', 'LineWidth', 1.5); hold on;
            DrawLine(mouse.time, cells(ncell).trace, mouse.velocity_binary, 1, 'g', 0, 1); hold on;

            spike_level = 0.9 * max(cells(ncell).trace);
            
            % Отмечаем спайки покоя (чёрные звёздочки на фиксированной высоте)
            time_rest = mouse.time(cells(ncell).spikes_in_rest_frames);
            if ~isempty(time_rest)
                plot(time_rest, repmat(spike_level, size(time_rest)), 'k*', 'MarkerSize', 6, 'LineWidth', 1.5);
            end

            % Отмечаем спайки движения (красные звёздочки на той же высоте)
            time_mov = mouse.time(cells(ncell).spikes_in_mov_frames);
            if ~isempty(time_mov)
                plot(time_mov, repmat(spike_level, size(time_mov)), 'r*', 'MarkerSize', 8, 'LineWidth', 1.5);
            end

            xlabel('Time, s', 'FontSize', mouse.params_main.FontSizeLabel);
            ylabel('Activity, a.u.', 'FontSize', mouse.params_main.FontSizeLabel);
            set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
            xlim([min(mouse.time) max(mouse.time)]);
            box off;

            % инфо активности нейрона
            % Создаем axes для текста в правом нижнем углу
            axes('Position', [0.61 0.1 0.4 1-graf_trace_ratio], 'Visible', 'off');

            cell_info = sprintf('SNR = %.1f\nN_{all} = %d Ca^{2+}\nN_{rest} = %d Ca^{2+}\nN_{loc} = %d Ca^{2+}\nFR_{all} = %.2f Ca^{2+}/min\nFR_{rest} = %.2f Ca^{2+}/min\nFR_{loc} = %.2f Ca^{2+}/min\nFR_{loc}/FR_{rest} = %.2f', ...
                cells(ncell).SNR_peak, ...
                cells(ncell).spikes_all_count, ...
                cells(ncell).spikes_in_rest_count, ...
                cells(ncell).spikes_in_mov_count, ...
                cells(ncell).spikes_all_frequency, ...
                cells(ncell).spikes_in_rest_frequency, ...
                cells(ncell).spikes_in_mov_frequency, ...
                cells(ncell).frequency_ratio_mov_rest);

            text(0.5, 0.5, cell_info, ...
                'FontSize', mouse.params_main.FontSizeLabel *0.7, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'middle', ...
                'BackgroundColor', [1 1 1], ...
                'EdgeColor', 'k', ...
                'LineWidth', 1, ...
                'Margin', 5);

            saveas(h_combined, sprintf('%s\\Spikes\\%s_Spikes_Cell_%d.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
            delete(h_combined);
        end

    case 'all_spikes'
        
        % all spikes from all cells
        h = figure('Position', mouse.params_main.Screensize);
        plot(mouse.x,mouse.y, 'b');hold on;
        DrawLine(mouse.x, mouse.y, mouse.velocity_binary, 1, 'g', 0, 1);hold on;
        for ncell=1:mouse.cells_for_analysis_count
            plot(mouse.x(cells(ncell).spikes_in_mov_frames),mouse.y(cells(ncell).spikes_in_mov_frames),'r*', 'MarkerSize',mouse.params_main.MarksizeSpikesAll, 'LineWidth',mouse.params_main.LineWidthSpikes);
            hold on;
            plot(mouse.x(cells(ncell).spikes_in_rest_frames),mouse.y(cells(ncell).spikes_in_rest_frames),'k*', 'MarkerSize',round(mouse.params_main.MarksizeSpikesAll/2), 'LineWidth',round(mouse.params_main.LineWidthSpikes/2));
            hold on;
        end
        
        axis(mouse.axes);
        title('Trajectory of mouse with all Ca2+ events', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('X coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Y coordinate, cm', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        legend({'Rest', 'Locomotion'});
        
        saveas(h, sprintf('%s\\%s_spikes_all.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        saveas(h, sprintf('%s\\%s_spikes_all.fig',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % spikes_all_frequency hist
        h = figure('Position', mouse.params_main.Screensize);
        histogram([cells.spikes_all_frequency], 'BinMethod','fd');
        
        title('Histogram of cells FiringRate', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('FiringRate, Ca2+/min', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_FiringRate.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % spikes_in_mov_frequency hist
        h = figure('Position', mouse.params_main.Screensize);
        histogram([cells.spikes_in_mov_frequency], 'BinMethod','fd');
        
        title('Histogram of cells FiringRate in locomotions', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('FiringRate, Ca2+/min', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_FiringRate_in_locomotions.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % spikes_in_rest_frequency hist
        h = figure('Position', mouse.params_main.Screensize);
        histogram([cells.spikes_in_rest_frequency], 'BinMethod','fd');
        
        title('Histogram of cells FiringRate in rests', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('FiringRate, Ca2+/min', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_SNR_peak.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % ratio 'spikes_in_mov_frequency'/'spikes_in_rest_frequency' hist
        h = figure('Position', mouse.params_main.Screensize);
        histogram([cells.frequency_ratio_mov_rest], 'BinMethod','fd');
        
        title('Histogram of cells FiringRate Ratio in locomotions to rests', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('FiringRate Ratio', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_FiringRate_Ratio_in_locomotions.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % SNR_baseline hist
        h = figure('Position', mouse.params_main.Screensize);
        histogram([cells.SNR_baseline], 'BinMethod','fd');
        
        title('Histogram of cells SNR, method: baseline', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('SNR, dB', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_SNR_baseline.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % SNR_peak hist
        h = figure('Position', mouse.params_main.Screensize);
        histogram([cells.SNR_peak], 'BinMethod','fd');
        
        title('Histogram of cells SNR, method: peak', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('SNR, dB', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('Count', 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_SNR_peak.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % SNR_baseline and SNR_peak correlation
        h = figure('Position', mouse.params_main.Screensize);
        [statsText] = plotCorrelationWithStats([cells.SNR_baseline], [cells.SNR_peak], 'k', mouse.params_main.MarksizeSpikes, 'equal');
        coord_text = positionText(gca, 0.01, 0.8);
        text(coord_text(1), coord_text(2), statsText, 'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 5, 'FontSize', mouse.params_main.FontSizeLabel);
        
        title('SNR baseline / SNR peak correlation', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('SNR baseline, dB', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('SNR peak, dB', 'FontSize', mouse.params_main.FontSizeLabel);
        legend({'Data Points', 'Linear Fit'}, 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_corr_SNR_baseline_SNR_peak.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % SNR and FiringRate correlation
        h = figure('Position', mouse.params_main.Screensize);
        [statsText] = plotCorrelationWithStats([cells.SNR], [cells.spikes_all_frequency], 'k', mouse.params_main.MarksizeSpikes);
        coord_text = positionText(gca, 0.01, 0.8);
        text(coord_text(1), coord_text(2), statsText, 'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 5, 'FontSize', mouse.params_main.FontSizeLabel);
        
        title('SNR / FiringRate correlation', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('SNR, dB', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('FiringRate, Ca2+/min', 'FontSize', mouse.params_main.FontSizeLabel);
        legend({'Data Points', 'Linear Fit'}, 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_corr_SNR_FiringRate.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);
        
        % SNR and FiringRate Ratio correlation
        h = figure('Position', mouse.params_main.Screensize);
        [statsText] = plotCorrelationWithStats([cells.SNR], [cells.frequency_ratio_mov_rest], 'k', mouse.params_main.MarksizeSpikes);
        coord_text = positionText(gca, 0.01, 0.8);
        text(coord_text(1), coord_text(2), statsText, 'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 5, 'FontSize', mouse.params_main.FontSizeLabel);
        
        title('SNR / FiringRate Ratio correlation', 'FontSize', mouse.params_main.FontSizeTitle);
        xlabel('SNR, dB', 'FontSize', mouse.params_main.FontSizeLabel);
        ylabel('FiringRate Ratio', 'FontSize', mouse.params_main.FontSizeLabel);
        legend({'Data Points', 'Linear Fit'}, 'FontSize', mouse.params_main.FontSizeLabel);
        set(gca, 'FontSize', mouse.params_main.FontSizeLabel);
        
        saveas(h, sprintf('%s\\%s_corr_SNR_FiringRateRatio.png',mouse.params_paths.pathOut,mouse.params_paths.filenameOut));
        delete(h);

    otherwise
        error('Неизвестный режим: %s', mode);
end
end

% for ncell = mouse.cells_active
% 
%     MapCells(:,:,ncell) = cellmaps(ncell).firingrate_refined_normalized; 
    
%     if mouse.plot_opt.Plot_Spike
%         h = figure('Position', mouse.params_main.Screensize);
%         DrawHeatMapModSphynx (Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).spike,mouse.max_bin.spike,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%         title(sprintf('Spike''s map of cell #%d. Spikes: %d',ncell, length(spike_t_good)), 'FontSize', mouse.params_main.FontSizeTitle);
%         saveas(h, sprintf('%s\\Heatmap_Spike\\%s_Heatmap_Spike_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
%         delete(h);
%     end
    
%     if mouse.plot_opt.Plot_Spike_Smooth
%         h = figure('Position', mouse.params_main.Screensize);
%         DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).spike_refined,mouse.max_bin.spike_sm_sm,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%         title(sprintf('Spikes number of cell %d (smoothed). Spikes: %d',ncell, length(spike_t_good)), 'FontSize', mouse.params_main.FontSizeTitle);
%         saveas(h, sprintf('%s\\Heatmap_Spike_Smooth\\%s_Heatmap_Spike_sm_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
%         delete(h);
%     end
    
%     if mouse.plot_opt.Plot_FiringRate
%         if Cell_IC(2,ncell)
%             h = figure('Position', mouse.params_main.Screensize);
%             DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).firingrate,0,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%             title(sprintf('Firing rate of informative cell %d (#/min)', ncell), 'FontSize', mouse.params_main.FontSizeTitle);
%             saveas(h, sprintf('%s\\Heatmap_FiringRate_Informative\\%s_Heatmap_FiringRate_Informative_%d.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut,ncell));
%             delete(h);
%         else
%             h = figure('Position', mouse.params_main.Screensize);
%             DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).firingrate,0,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%             title(sprintf('Firing rate of NOT informative cell %d (#/min)', ncell), 'FontSize', mouse.params_main.FontSizeTitle);
%             saveas(h, sprintf('%s\\Heatmap_FiringRate_NOT_Informative\\%s_Heatmap_FiringRate_NOT_Informative_%d.png', mouse.params_paths.pathOut, mouse.params_paths.filenameOut,ncell));
%             delete(h);
%         end
%     end
    
%     if mouse.plot_opt.Plot_FiringRate_Smooth
%         h = figure('Position', mouse.params_main.Screensize);
%         DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).firingrate_refined,mouse.max_bin.firingrate_refimed,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%         title(sprintf('Firing rate, smoothed, of cell %d (#/min). Ca2+ events: %d\n MI = %.2f, MU\\_shuffle = %.3f, SIGMA\\_shuffle = %.3f, MI\\_Zscore = %.1f', ncell, length(spike_t_good), Cell_IC(3:6,ncell)), 'FontSize', 10);
%         saveas(h, sprintf('%s\\Heatmap_FiringRate_Smooth\\%s_Heatmap_FiringRate_Smoothed_Cell_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
%         delete(h);
%     end
    
%     if mouse.plot_opt.Plot_FiringRate_Smooth_Thres
%         if Cell_IC(2,ncell)
%             h = figure('Position', mouse.params_main.Screensize);
%             DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).firingrate_refined_normalized,0,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%             title(sprintf('Firing rate of informative cell %d (smoothed and thresholded)(#/min)',ncell), 'FontSize', mouse.params_main.FontSizeTitle);
%             saveas(h, sprintf('%s\\Heatmap_FiringRate_Smooth_Thres_Informative\\%s_Heatmap_FiringRate_sm_thres_Informative_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
%             delete(h);
%         else
%             h = figure('Position', mouse.params_main.Screensize);
%             DrawHeatMapModSphynx(Options,ArenaAndObjects,params_main.opt.spike,cellmaps(ncell).firingrate_refined_normalized,0,mouse.x,mouse.y,mouse.bin_size,Options.x_kcorr,spike_t_good);
%             title(sprintf('Firing rate of NOT informative cell %d (smoothed and thresholded)(#/min)',ncell), 'FontSize', mouse.params_main.FontSizeTitle);
%             saveas(h, sprintf('%s\\Heatmap_FiringRate_Smooth_Thres_NOT_Informative\\%s_Heatmap_FiringRate_sm_thres_NOT_Informative_%d.png', mouse.params_paths.pathOut,mouse.params_paths.filenameOut,ncell));
%             delete(h);
%         end
%     end
% end
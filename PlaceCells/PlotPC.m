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
    
    case 'firing rate summary'
        
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
                cells(ncell).spikes_all_frames ...
                );
            
            title(sprintf('Firing rate, smoothed, of cell %d (#/min). Ca2+ events: %d\n MI = %.2f, MI\\_shuffle = %.3f, SIGMA\\_shuffle = %.3f, MI\\_Zscore = %.1f', ...
                ncell, ...
                cells(ncell).spikes_all_count, ...
                cells(ncell).MI_bit, ...
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
            mouse.ocuppancy_map.time_smoothed, ...
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
        plot(mouse.arena_opt.border_x, mouse.arena_opt.border_y);
        
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
        
        % активность нейронов
        for ncell = 1:mouse.cells_count_for_analysis
            
            h = figure('Position', mouse.params_main.Screensize);
            plot(mouse.x,mouse.y, 'b');hold on;                                         % траектория животного
            DrawLine(mouse.x, mouse.y, mouse.velocity_binary, 1, 'g', 0, 1);hold on;    % траектория во время побежек
            plot(mouse.x(cells(ncell).spikes_in_rest_frames),mouse.y(cells(ncell).spikes_in_rest_frames),'k*', 'MarkerSize',round(mouse.params_main.MarksizeSpikes/2), 'LineWidth',round(mouse.params_main.LineWidthSpikes/2));hold on;
            plot(mouse.x(cells(ncell).spikes_in_mov_frames),mouse.y(cells(ncell).spikes_in_mov_frames),'r*', 'MarkerSize',mouse.params_main.MarksizeSpikes, 'LineWidth',mouse.params_main.LineWidthSpikes);
            
            axis(mouse.axes);
            title(sprintf('Trajectory of mouse with n = %d (%d) Ca2+ events (in mov, red) of cell #%d', cells(ncell).spikes_all_count,cells(ncell).spikes_in_mov_count, ncell), 'FontSize', mouse.params_main.FontSizeTitle);
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
function generatePlots(s, V, T, A, plotDir)

figure;
plot(T.dt);
hold on;
yline(T.mean_dt, 'r');
yline(T.threshold, 'g');
title([strrep(s.name, "_", "\_") ' dt']);
saveas(gcf, fullfile(plotDir, sprintf('%s_dt.png', s.name)));
close;

figure;
histogram(T.dt, 50);
title([strrep(s.name, "_", "\_") ' dt histogram']);
saveas(gcf, fullfile(plotDir, sprintf('%s_dt_hist.png', s.name)));
close;

end

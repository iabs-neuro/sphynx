%predexp
time_pred = [20,30,85,75,90,80,75,80,70,70];
time_test = [15,15,90,65,70,95,105,90,80,85];
mouse = [11,14,18,21,22,23,25,26,28,30];

path_f_pred = 'F:\SCRIPTS_for_VT_NV_disk\CG-FR_data\behav\Predexp\';
path_n_pred = 'F:\SCRIPTS_for_VT_NV_disk\CG-FR_data\Ca_data\Predexp\';
path_f_test = 'F:\SCRIPTS_for_VT_NV_disk\CG-FR_data\behav\Test\';
path_n_test = 'F:\SCRIPTS_for_VT_NV_disk\CG-FR_data\Ca_data\Test\';

freez_act_sum = [];
freez_gap_sum = [];
k=1;
for i = mouse
name_f = sprintf('%d.wmv_MotInd_14.csv', i);
name_n = sprintf('%d.csv', i);
[freez_act, freez_gap] = FreezKiller(path_f_pred,name_f,path_n_pred,name_n,time_pred(k));
freez_act_sum = [freez_act_sum freez_act];
freez_gap_sum = [freez_gap_sum freez_gap(2:length(freez_gap)-1)];
k=k+1;
end

h = figure('Position', get(0, 'Screensize')); 
hist(freez_act_sum,max(freez_act_sum));
title('Distribution of freezing time, predexp', 'FontSize', 18);
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\FreezTimePredexp.png', path_f_pred));         
delete(h); 

h = figure('Position', get(0, 'Screensize')); 
hist(freez_gap_sum,max(freez_gap_sum));
title('Distribution of gap between freezing, predexp', 'FontSize', 18);
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\GapTimePredexp.png', path_f_pred));         
delete(h); 

[counts1, binCenters1] = hist(freez_gap_sum ,max(freez_gap_sum));
[counts2, binCenters2] = hist(freez_act_sum,max(freez_act_sum));
plot(binCenters1, counts1, 'r-');hold on;
plot(binCenters2, counts2, 'g-');
grid on;
% Put up legend
title('Predexp', 'FontSize', 18);
legend1 = 'Freez gap ';
legend2 = 'Freez act';
legend({legend1, legend2}, 'FontSize', 18);

%test
freez_act_sum = [];
freez_gap_sum = [];
k=1;
for i = mouse
name_f = sprintf('%d.wmv_MotInd_14.csv', i);
name_n = sprintf('%d.csv', i);
[freez_act, freez_gap] = FreezKiller(path_f_test,name_f,path_n_test,name_n,time_test(k));
freez_act_sum = [freez_act_sum freez_act];
freez_gap_sum = [freez_gap_sum freez_gap(2:length(freez_gap)-1)];
k=k+1;
end

% h = figure('Position', get(0, 'Screensize'));
% hist(freez_act_sum,max(freez_act_sum));
% title('Distribution of freezing time, test', 'FontSize', 18);
% F = getframe(h);
% imwrite(F.cdata, sprintf('%s\\FreezTimeTest.png', path_f_test));         
% delete(h); 
% 
% h = figure('Position', get(0, 'Screensize')); 
% hist(freez_gap_sum,max(freez_gap_sum));
% title('Distribution of gap between freezing, test', 'FontSize', 18);
% F = getframe(h);
% imwrite(F.cdata, sprintf('%s\\GapTimeTest.png', path_f_test));         
% delete(h); 
% 
% [counts1, binCenters1] = hist(freez_gap_sum ,max(freez_gap_sum));
% [counts2, binCenters2] = hist(freez_act_sum,max(freez_act_sum));
% plot(binCenters1, counts1, 'r-');hold on;
% plot(binCenters2, counts2, 'g-');
% grid on;
% % Put up legend
% title('Test', 'FontSize', 18);
% legend1 = 'Freez gap ';
% legend2 = 'Freez act';
% legend({legend1, legend2}, 'FontSize', 18);


% h = histogram(freez_act_sum,max(freez_act_sum)-1,'facealpha',.5, 'EdgeAlpha', 0.5);
% hold on;
% h.FaceColor = 'r';
% h.EdgeColor = 'w';
% grid on;
% hold on;
% histogram(freez_gap_sum,max(freez_gap_sum)-1,'FaceColor','b','EdgeColor','w','facealpha',0.5, 'EdgeAlpha', 0.5);
% hold on;
% title('Distribution of freezing time, test', 'FontSize', 18);
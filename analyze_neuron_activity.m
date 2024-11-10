%% Paths and names

% filenames = {
%     'H01_1D','H02_1D','H03_1D','H06_1D','H07_1D','H08_1D','H09_1D','H14_1D','H23_1D',...
%     'H26_1D','H27_1D','H31_1D','H32_1D','H33_1D','H36_1D','H39_1D',...
%     'H01_2D','H02_2D','H03_2D','H06_2D','H07_2D','H08_2D','H09_2D','H14_2D','H23_2D'...
%     'H26_2D','H27_2D','H31_2D','H32_2D','H33_2D','H36_2D','H39_2D',...
%     'H01_3D','H02_3D','H03_3D','H06_3D','H07_3D','H08_3D','H09_3D','H14_3D','H23_3D',...
%     'H26_3D','H27_3D','H31_3D','H32_3D','H33_3D','H36_3D','H39_3D',...
%     'H01_4D','H02_4D','H03_4D','H06_4D','H07_4D','H08_4D','H09_4D','H14_4D','H23_4D',...
%     'H26_4D','H27_4D','H31_4D','H32_4D','H33_4D','H36_4D','H39_4D',...
%     };

path = 'c:\Users\Plusnin\Projects\NOF\';
data_files = dir('c:\Users\Plusnin\Projects\NOF\*.csv');

%% opts
non_negativ = 1;
non_zero = 0;
fake_timeline = 1;
session_times = 10; % in minutes 
num_bins = 100;
z_thresh = 2; % Порог по z-отклонению
mad_thresh = 4; % Порог по медианному отклонению

%% main part
for file = 1:length(FileNames)
    data_file = data_files(file).name;
    analyze_neuron_activity(data_file);
end

%% function

% test filename
data_file = 'NOF_H02_1D_gsig4_mincorr0.95_minpnr10_traces.csv';

% function analyze_neuron_activity(data_file)

% Чтение таблицы
data = readtable(sprintf('%s%s',path,data_file));

neuron_data = data{2:end, 4:end};  % Активность нейронов
num_neurons = size(neuron_data, 2); % Количество нейронов
time_series = data{2:end, 3};  % Временной ряд
if fake_timeline
    time_series = linspace(0, session_times*60, size(neuron_data,1));
end

% Создаем папку для сохранения гистограмм, если она еще не существует
output_folder = sprintf('%s%s',path, data_file(1:10));
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% Инициализируем таблицу для хранения результатов аппроксимации
results = cell(num_neurons, 2);

for i = 1:num_neurons
    
    % Данные активности текущего нейрона
    activity = neuron_data(:, i);
    if non_negativ
        activity = activity-min(activity);
    end
    if non_zero
        activity(activity <= 0) = [];
    end
        
    % Проверка на пустой массив после удаления нулей
    if isempty(activity)
        warning(['Neuron ' data{1, i+3} ' has only zero values, skipping.']);
        continue;
    end    
    
    % Построение гистограммы 
    
    % Вычисление медианы и медианного отклонения
    med_activity = median(activity);
    mad_activity = median(abs(activity - med_activity));
    mean_activity = mean(activity);
    dev_activity = std(activity);
    
    % Аппроксимация распределениями
    pd_normal = fitdist(activity, 'Normal');
    pd_gamma = fitdist(activity(activity > 0), 'Gamma');
    pd_lognormal = fitdist(activity(activity > 0), 'Lognormal');
    
    % Создание графиков
    figure;
    set(gcf, 'Position', get(0, 'Screensize'));
    
    % 1. Гистограмма и аппроксимирующие распределения
    subplot(3, 2, [1 3 5]);
    histogram(activity, num_bins, 'Normalization', 'pdf', 'DisplayName', 'Ca^{2+} Activity');
    hold on;
    x_values = linspace(min(activity), max(activity), 100);
    plot(x_values, pdf(pd_normal, x_values), 'r-', 'LineWidth', 1, 'DisplayName', 'Normal');
    plot(x_values, pdf(pd_gamma, x_values), 'g-', 'LineWidth', 1, 'DisplayName', 'Gamma');
    plot(x_values, pdf(pd_lognormal, x_values), 'b-', 'LineWidth', 1, 'DisplayName', 'Lognormal');
    
    % Добавление линий медианы и медианного отклонения
    line([med_activity, med_activity], ylim, 'Color', 'm', 'LineWidth', 1.5, 'LineStyle', '-', 'DisplayName', 'Median');
%     line([med_activity + mad_activity, med_activity + mad_activity], ylim, 'Color', 'm', 'LineWidth', 1.5, 'LineStyle', '-.', 'DisplayName', 'Median + MAD');
    line([med_activity + mad_thresh*mad_activity, med_activity + mad_thresh*mad_activity], ylim, 'Color', 'm', 'LineWidth', 1.5, 'LineStyle', '-.', 'DisplayName', sprintf('Median + %d MAD',mad_thresh));
    line([mean_activity, mean_activity], ylim, 'Color', 'r', 'LineWidth', 1.5, 'LineStyle', '-', 'DisplayName', 'Mean');
    line([mean_activity + z_thresh*dev_activity, mean_activity + z_thresh*dev_activity], ylim, 'Color', 'r', 'LineWidth', 1.5, 'LineStyle', '-.', 'DisplayName', sprintf('Mean + %d SD',z_thresh));
        
    legend;
    title(sprintf('Ca^{2+} Activity Histogram with Fits of neuron #%d', data{1, i+3}));
    hold off;
    
    % 2. График активности (весь временной ряд)
    subplot(3, 2, 2);
    plot(time_series, activity, 'k', 'DisplayName', 'Ca^{2+} Activity');
    title('Ca^{2+} Activity');
    xlabel('Time, s');
    ylabel('Ca^{2+} Activity Level');
    legend;
    
    % 3. График активности с выделением по z-отклонению
    subplot(3, 2, 4);
    z_activity = (activity - mean(activity)) / std(activity);  % Z-оценка
    plot(time_series, activity, 'k', 'DisplayName', 'Ca^{2+} Activity');  % Основной график
    hold on;
    outliers_z = abs(z_activity) > z_thresh;
    plot(time_series(outliers_z), activity(outliers_z), 'r.', 'DisplayName', sprintf('> %d SD', z_thresh)); % Выделение точек
    title('Ca^{2+} Activity with Z-score Outliers');
    xlabel('Time, s');
    ylabel('Ca^{2+} Activity Level');
    legend;
    hold off;
    
    % 4. График активности с выделением по медианному отклонению
    subplot(3, 2, 6);
    plot(time_series, activity, 'k', 'DisplayName', 'Ca^{2+} Activity');  % Основной график
    hold on;
    outliers_mad = abs(activity - med_activity) > mad_thresh * mad_activity;
    plot(time_series(outliers_mad), activity(outliers_mad), 'm.', 'DisplayName', sprintf('> %d MAD', mad_thresh)); % Выделение точек
    title('Ca^{2+} Activity with MAD Outliers');
    xlabel('Time, s');
    ylabel('Ca^{2+} Activity Level');
    legend;
    hold off;
    
    % Сохранение гистограммы с аппроксимациями
    saveas(gcf, fullfile(output_folder, ['hist_' num2str(data{1, i+3}) '.png']));
    close;
    
    % Оценка аппроксимаций с помощью критерия Колмогорова-Смирнова
    [ks_normal, p_normal] = kstest(activity, 'CDF', pd_normal);
    [ks_gamma, p_gamma] = kstest(activity, 'CDF', pd_gamma);
    [ks_lognormal, p_lognormal] = kstest(activity, 'CDF', pd_lognormal);
    
    % Определение лучшего распределения на основе наименьшего значения статистики Колмогорова-Смирнова
    [~, best_fit_idx] = min([ks_normal, ks_gamma, ks_lognormal]);
    best_fit = {'Normal', 'Gamma', 'Lognormal'};
    
    % Сохранение результата
    results{i, 1} = data{1, i+3};
    results{i, 2} = best_fit{best_fit_idx};
end

% Сохранение результатов в таблицу
results_table = cell2table(results, 'VariableNames', {'Neuron', 'BestFitDistribution'});
writetable(results_table, fullfile(output_folder, sprintf('%s_fit_results.csv', data_file(1:10))));

disp('Анализ завершен. Результаты сохранены в папке NeuronHistograms.');
% end
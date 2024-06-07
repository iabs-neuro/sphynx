%% Запросить у пользователя путь к папке с CSV файлами
folder_path = uigetdir('', 'Выберите папку с CSV файлами');

% Получить список CSV файлов в указанной папке
csv_files = dir(fullfile(folder_path, '*4D*.csv'));

thr = 1.5;

%% Перебрать каждый CSV файл
LengthData =[];
Counts_outliers = [];
for file = 1:length(csv_files)
% for file = 1:10
    % Загрузить данные из CSV файла
    data = csvread(fullfile(folder_path, csv_files(file).name));
    
    % Посчитать разницу между временными точками
    diff_data = diff(data)./10000;
    mean_diff = mean(diff_data);
    std_diff = std(diff_data);
    
    % Посчитать количество точек, выходящих за 2 стандартных отклонения
    count_outliers = sum(diff_data >  thr*mean_diff);
    
    % Вывести результаты
    fprintf('%s. Количество кадров: %d. Количество дропов: %d\n', csv_files(file).name, length(data), count_outliers);
    
    LengthData = [LengthData length(data)];
    Counts_outliers = [Counts_outliers count_outliers];
    % Построить график разницы между временными точками
    h = figure;
    plot(diff_data);hold on;
    yline(mean_diff, 'r');
    yline(mean_diff+std_diff*2, 'r');
    yline(mean_diff+std_diff*3, 'r');
    xlabel('Frames, ms');
    ylabel('Frames diff');
    title(sprintf('%sDroppedFrames: %d',csv_files(file).name(1:end-4), count_outliers ));
    saveas(h,sprintf('%s\\%s_DroppedFrames_%d.png',folder_path, csv_files(file).name(1:end-4), count_outliers ));
    delete(h);
end







%% parameters

% Задайте количество частей
numParts = 5;
Screensize = get(0,'ScreenSize');

% Запросить список файлов workspace.mat
[fileNames, filePath] = uigetfile('*.mat', 'Выберите файлы workspace.mat', 'MultiSelect', 'on','d:\Projects\H_mice\8_matfiles\');

PathOut = 'd:\Projects\H_mice\test_trajectory\';

%% main
for block = 1:21
    h = figure('Position', Screensize);
    pp = 1;
    for file = (block-1)*4+1:(block-1)*4+4
    %     for file = 1:length(fileNames)
        % Загрузка данных из файла workspace.mat
        load(fullfile(filePath, fileNames{file}), 'BodyPartsTracesMainX','BodyPartsTracesMainY','Acts', 'Options','Point');

        % Задайте количество данных в каждой части
        numPoints = floor(length(Acts(3).ActArrayRefine) / numParts);

    %     if mod(file,4) == 1
    %         h = figure('Position', Screensize);
    %     end
        
        for i = 1:numParts
            % Индексы для текущей части
            startIndex = (i - 1) * numPoints + 1;
            if i == numParts
                endIndex = length(Acts(3).ActArrayRefine);
            else
                endIndex = i * numPoints;
            end

            % Создайте подграфик
            subplot(4, numParts, pp);
            pp = pp + 1;
            imshow(Options.GoodVideoFrame, 'InitialMag', 'fit'); hold on;
    %         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(3).ActArrayRefine(startIndex:endIndex))) / Options.x_kcorr, BodyPartsTracesMainY(Point.Center,logical(Acts(3).ActArrayRefine(startIndex:endIndex))), 'b.');hold on;
    %         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(2).ActArrayRefine(startIndex:endIndex))) / Options.x_kcorr, BodyPartsTracesMainY(Point.Center,logical(Acts(2).ActArrayRefine(startIndex:endIndex))), 'g.');hold on;
    %         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(1).ActArrayRefine(startIndex:endIndex))) / Options.x_kcorr, BodyPartsTracesMainY(Point.Center,logical(Acts(1).ActArrayRefine(startIndex:endIndex))), 'r.');hold on;
            plot(BodyPartsTracesMainX(Point.Center,startIndex:endIndex) / Options.x_kcorr, BodyPartsTracesMainY(Point.Center,startIndex:endIndex), 'b.');hold on;
    %         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(2).ActArrayRefine))(startIndex:endIndex) / Options.x_kcorr, BodyPartsTracesMainY(Point.Center,logical(Acts(2).ActArrayRefine(startIndex:endIndex))), 'g.');hold on;
    %         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(1).ActArrayRefine))(startIndex:endIndex) / Options.x_kcorr, BodyPartsTracesMainY(Point.Center,logical(Acts(1).ActArrayRefine(startIndex:endIndex))), 'r.');hold on;

    %         legend('Locomotion', 'Other', 'Rest');
    %         title(sprintf('%s_part%d', fileNames{1, file}(1:10), i));
            title(sprintf('%s %d', strrep(fileNames{1, file}(1:10), '_', '\_'), i));
        end
    end

    saveas(h, sprintf('%s\\Trajectory_%d.png', PathOut, block));
    delete(h);
end
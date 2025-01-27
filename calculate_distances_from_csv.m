function distances = calculate_distances_from_csv()

%% parameters

% 1D
% x_kcorr = [1,1.22000000000000,1,1,1,1,1,1.22000000000000,1,1,1,1,1,1.22000000000000,1.22000000000000,1.22000000000000,1,1];
% pxl2sm = [7,11.5400000000000,7,7,7,7,7,11.5400000000000,7,7,7,7,7,11.5400000000000,11.5400000000000,11.5400000000000,7,7];
% label = [2,5,2,2,2,2,2,5,2,2,2,2,2,5,5,5,2,2];

% % 2D
x_kcorr = [1,1.22000000000000,1,1.22000000000000,1,1,1,1.22000000000000,1.22000000000000,1.22000000000000,1.22000000000000,1.22000000000000,1,1,1,1,1.22000000000000,1.22000000000000];
pxl2sm = [7,11.5400000000000,7,11.5400000000000,7,7,7,11.5400000000000,11.5400000000000,11.5400000000000,11.5400000000000,11.5400000000000,7,7,7,7,11.5400000000000,11.5400000000000];

% mode = "DLC"; % or "Bonsai"
mode = "Bonsai"; % or "Bonsai"
part = 13; % center bodypart for DLC mode
FrameRate = 50;
Velocity_threshold = 25;

%% main part

% Выбрать CSV-файлы из папки
[files, path] = uigetfile('*.csv', 'Выберите CSV-файлы', 'c:\Users\1\YandexDisk\_Projects\3DM\2DM\2DM_2D\', 'MultiSelect', 'on');

if isnumeric(files)
    disp('Файлы не выбраны.');
    return;
end

% Если выбран один файл, преобразовать в ячейку для единообразия
if ischar(files)
    files = {files};
end


%% Обработка каждого файла

% Инициализация массива для хранения дистанций
distances = zeros(1, numel(files));
for name = 1:numel(files)
    filename = fullfile(path, files{name});
    
    file = readtable(filename); % Загрузка CSV как таблицы
    EndTime = size(file,1);
    StartTime = 1;
    n_frames = EndTime-StartTime+1;
    frames = linspace(1, n_frames, n_frames);
    time = (1:n_frames)/FrameRate;
    
    switch mode
        case "DLC"
            try
                [~,fileDLC,~] = xlsread(filename);
            catch
                fileID = fopen(filename, 'r');
                numLines = 3;
                fileDLC = cell(3, 1);
                for i = 1:numLines
                    fileDLC{i} = fgetl(fileID);
                end
                fclose(fileID);
            end
            
            NamesDLC = strsplit(fileDLC{2},',');
            BodyPartsNumber = (length(NamesDLC)-1)/3;
            BodyPartsNames = cell(1, BodyPartsNumber);
            BodyPartsOptions = zeros(1, BodyPartsNumber);
            for PartName = 1:BodyPartsNumber
                BodyPartsNames{PartName} = NamesDLC{(PartName-1)*3+2};
                BodyPartsOptions(PartName) = (PartName-1)*3+2;
            end
            clear fileDLC;
            
            BodyPartsTraces = struct('BodyPartName', [], 'TraceOriginal', [],'TraceLikelihood', [], 'PercentNaN', [],'PercentLikeliHoodSubThreshold', [], 'Status', [], 'TraceInterpolated', [], 'TraceSmoothed', [], 'AverageDistance', [],'AverageSpeed', []);
            BodyPartsTracesMainX = zeros(BodyPartsNumber,n_frames);
            BodyPartsTracesMainY = zeros(BodyPartsNumber,n_frames);
            
            x = table2array(file(StartTime:EndTime,BodyPartsOptions(part)))*x_kcorr;
            y = table2array(file(StartTime:EndTime,BodyPartsOptions(part)+1));
            TraceLikelihood = table2array(file(StartTime:EndTime,BodyPartsOptions(part)+2));
            
        case "Bonsai"
            
            x = table2array(file(StartTime:EndTime,1))'*x_kcorr(name);
            y = table2array(file(StartTime:EndTime,2))';
            
            
    end
    
    h = figure;
    plot(x,y);
    saveas(h, sprintf('%s\\%s_track_original.png', path, files{name}(1:end-4)));
    delete(h);
    
    % velocity calculation
    
    TempArrayX = [0 diff(x)];
    TempArrayY = [0 diff(y)];
    SmoothWindow = 50;
    
    Velocity = sqrt((TempArrayX).^2+(TempArrayY).^2)*FrameRate./pxl2sm(name);
    Velocity = [interp1(2:n_frames, Velocity(2:end), 1, 'linear', 'extrap') Velocity(2:end)];
    plot(Velocity);
    
    TempArray = Velocity;
    TempArray(isnan(TempArray)) = 0;
    TempArray(TempArray>Velocity_threshold) = 0;
    TempArray(TempArray<0) = 0;
    plot(TempArray);
    TempArrayX = TempArray;
    
    VelocityInt = interp1(frames(TempArray ~=0), TempArray(TempArray ~=0), find(TempArray == 0), 'PCHIP');
    VelocityInt(VelocityInt<0) = 0;
    VelocityInt(VelocityInt>Velocity_threshold) = Velocity_threshold;
    TempArray(TempArray == 0) = VelocityInt;
    VelocityInt = TempArray;
    plot(VelocityInt);
    
    VelocitySmoothed = smooth(VelocityInt,SmoothWindow,'moving');
    plot(VelocitySmoothed);
    
    AverageSpeed = round(mean(VelocitySmoothed),2);
    Distance = round(AverageSpeed*time(end)/100,2);
    
    x_int_add = interp1(frames(TempArrayX ~=0), x(TempArrayX ~=0), find(TempArrayX == 0), 'pchip');
    y_int_add = interp1(frames(TempArrayX ~=0), y(TempArrayX ~=0), find(TempArrayX == 0), 'pchip');
    
    x_int = x;
    y_int = y;
    x_int(TempArrayX == 0) = x_int_add;
    y_int(TempArrayX == 0) = y_int_add;
    
    h = figure;
    plot(x_int,y_int);
    saveas(h, sprintf('%s\\%s_track_int_smooth.png', path, files{name}(1:end-4)));
    delete(h);
    
    
    % Сохранение результата
    distances(name) = Distance;
    
    fprintf('Файл: %s, Пройденная дистанция: %.2f метров\n', files{name}, Distance);
    
end

end

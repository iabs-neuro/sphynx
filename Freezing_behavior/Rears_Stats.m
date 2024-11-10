%% paths and names
Path = 'e:\Wild_paper\DataSet_Rears_SPHYNXVsManual\Rears_auto\';
PathOut = 'e:\Wild_paper\DataSet_Rears_SPHYNXVsManual\';

% Lesnye
% FileNames = {'s1d2','s1d3','s2d2','s2d3','s3d2','s3d3','s5d2','s5d3','s7d2','s8d2'};
% TailbasePawscm = 2.7;
% AllBodyPartscm = 19.5;

% % Polevye
% FileNames = {'A1_D2','A2_D2','A3_D2','A4_D2','A4_D3','A6_D2','A7_D2'};
% TailbasePawscm = 2.8;
% AllBodyPartscm = 22.6;

% Polevki
FileNames = {'C22','C23','C24','L12','L5'};
TailbasePawscm = 3.4;
AllBodyPartscm = 21;

%% main part
SensitivityMouse = [];
PrecisionMouse = [];
for file  = 1:length(FileNames)
    load(sprintf('%s%s_WorkSpace.mat',Path,FileNames{file}), 'SensitivityAll', 'PrecisionAll', 'iter');
%     load(sprintf('%s%s_WorkSpace.mat',Path,FileNames{fileMouse}));

% %     tailbase-frames
%     Steps = length(SensitivityAll{2});
%     SensitivityMouse(file,1:Steps) = SensitivityAll{2}(2,:);    
%     PrecisionMouse(file,1:Steps) =  PrecisionAll{2}(2,:);
%     ThresholdLine = iter{2};
    
% %     tailbase-asts
%     Steps = length(SensitivityAll{2});
%     SensitivityMouse(file,1:Steps) = SensitivityAll{2}(1,:);    
%     PrecisionMouse(file,1:Steps) =  PrecisionAll{2}(1,:);
%     ThresholdLine = iter{2};
    
%     % allbodyparts-frames
%     Steps = length(SensitivityAll{1});
%     SensitivityMouse(file,1:Steps) = SensitivityAll{1}(2,:);    
%     PrecisionMouse(file,1:Steps) =  PrecisionAll{1}(2,:);
%     ThresholdLine = iter{1};

%     % allbodyparts-asts
%     Steps = length(SensitivityAll{1});
%     SensitivityMouse(file,1:Steps) = SensitivityAll{1}(1,:);    
%     PrecisionMouse(file,1:Steps) =  PrecisionAll{1}(1,:);
%     ThresholdLine = iter{1};
end

%% pre-plot 

    h = figure;
    plot(ThresholdLine,SensitivityMouse, 'c'); hold on;
    plot(ThresholdLine,PrecisionMouse, 'm'); hold on; 

%% main plots

% Вычисление среднего и стандартного отклонения для каждой матрицы
meanSensitivity = mean(SensitivityMouse);
stdSensitivity = std(SensitivityMouse);

meanAccuracy = mean(PrecisionMouse);
stdAccuracy = std(PrecisionMouse);

% Построение графика
figure;


% Область разброса стандартного отклонения для Чувствительности
upperBoundSensitivity = meanSensitivity + stdSensitivity;
lowerBoundSensitivity = meanSensitivity - stdSensitivity;

fill([ThresholdLine, fliplr(ThresholdLine)], [upperBoundSensitivity, fliplr(lowerBoundSensitivity)], [0.8 0.8 0.8], 'EdgeColor', 'none');

% Область разброса стандартного отклонения для Точности
upperBoundAccuracy = meanAccuracy + stdAccuracy;
lowerBoundAccuracy = meanAccuracy - stdAccuracy;

fill([ThresholdLine, fliplr(ThresholdLine)], [upperBoundAccuracy, fliplr(lowerBoundAccuracy)], [0.8 0.8 0.8], 'EdgeColor', 'none');

% Линия среднего значения для Чувствительности (cyan)
plot(ThresholdLine, meanSensitivity, 'LineWidth', 2, 'Color', [0 1 1]); 
hold on;
% Линия среднего значения для Точности (magenta)
plot(ThresholdLine, meanAccuracy, 'LineWidth', 2, 'Color', [1 0 1]);

hold off;

title('Среднее значение и область разброса');
xlabel('Временные точки');
ylabel('Чувствительность/Точность');

legend('Среднее значение Чувствительности', 'Область разброса Чувствительности', ...
    'Среднее значение Точности', 'Область разброса Точности');


%% пересечение 
% Пример временных рядов
x = ThresholdLine; % переменная абсциссы
y1 = meanSensitivity ; % первый временной ряд
y2 = meanAccuracy ; % второй временной ряд

% Найти точку пересечения
tolerance = 1; % допустимая погрешность
intersection_point = []; % начальное значение

for i = 1:length(x)
    if abs(y1(i) - y2(i)) < tolerance
        intersection_point = [intersection_point; x(i), y1(i), y2(i)];
    end
end

disp('Точки пересечения: Чувст, Точность');
disp(intersection_point);


%% count rears
RearsAllBodyPartNumberMouse = [];
RearsAllBodyPartPercentMouse = [];
RearsHumanAllBodyPartNumberMouse = [];
RearsHumanAllBodyPartPercentMouse = [];

RearsTailbaseNumberMouse = [];
RearsTailbasePercentMouse = [];
RearsHumanTailbaseNumberMouse = [];
RearsHumanTailbasePercentMouse = [];

for file1  = 1:length(FileNames)
    load(sprintf('%s%s_WorkSpace.mat',Path,FileNames{file1}));
    fprintf('Processing of %s\n', FileNames{file1});
    
    % rears definition AllBodyParts
    AllBodyParts = AllBodyPartscm*Options.pxl2sm;
    TempArray = zeros(n_frames,1);
    for i=1:n_frames
        for part=1:BodyPartsNumber
            TempArray(i) = TempArray(i) + sqrt((BodyPartsTracesMainX(Point.Center,i)-BodyPartsTracesMainX(part,i))^2 + (BodyPartsTracesMainY(Point.Center,i)-BodyPartsTracesMainY(part,i))^2);
        end
    end
    TempArraySmooth = smooth(TempArray, Options.FrameRate);
    RearsAllBodyPart = double(TempArraySmooth < AllBodyParts);
    [~, RearsAllBodyPartNumber, RearsAllBodyPartPercent, ~,~,~] = RefineLine(RearsAllBodyPart, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
    [~, RearsHumanAllBodyPartNumber, RearsHumanAllBodyPartPercent, ~,~,~] = RefineLine(rears_human, 0, 0);
      
    % rears definition Tailbase
    TailbasePaws = TailbasePawscm*Options.pxl2sm;
    TempArray = zeros(n_frames,1);
    for i=1:n_frames
        for part = [Point.LeftHindLimb Point.RightHindLimb]
            TempArray(i) = TempArray(i) + sqrt((BodyPartsTracesMainX(Point.Tailbase,i)-BodyPartsTracesMainX(part,i))^2 + (BodyPartsTracesMainY(Point.Tailbase,i)-BodyPartsTracesMainY(part,i))^2);
        end
    end
    TempArraySmooth = smooth(TempArray, ceil(Options.FrameRate/2));
    RearsTailbase = double(TempArraySmooth < TailbasePaws);
    [~, RearsTailbaseNumber, RearsTailbasePercent, ~,~,~] = RefineLine(RearsTailbase, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
    [~, RearsHumanTailbaseNumber, RearsHumanTailbasePercent, ~,~,~] = RefineLine(rears_human, 0, 0);
    
    RearsAllBodyPartNumberMouse = [RearsAllBodyPartNumberMouse RearsAllBodyPartNumber];
    RearsAllBodyPartPercentMouse = [RearsAllBodyPartPercentMouse RearsAllBodyPartPercent];
    RearsHumanAllBodyPartNumberMouse = [RearsHumanAllBodyPartNumberMouse RearsHumanAllBodyPartNumber];
    RearsHumanAllBodyPartPercentMouse = [RearsHumanAllBodyPartPercentMouse RearsHumanAllBodyPartPercent];
    
    RearsTailbaseNumberMouse = [RearsTailbaseNumberMouse RearsTailbaseNumber];
    RearsTailbasePercentMouse = [RearsTailbasePercentMouse RearsTailbasePercent];
%     RearsHumanTailbaseNumberMouse = [RearsHumanTailbaseNumberMouse RearsHumanTailbaseNumber];
%     RearsHumanTailbasePercentMouse = [RearsHumanTailbasePercentMouse RearsHumanTailbasePercent];
    
end


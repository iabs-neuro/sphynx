function DLC_test(PathDLC, FilenameDLC, PathOut, MultiAnimalOpt)
% script for checking DLC performance

StartTime = 1;
Options.LikelihoodThreshold = 0.3;
FrameRate = 30;
Options.pxl2sm = 8.1;
BodyPartsNamesDef.Center = {'mass centre' 'mass center' 'bodycenter' 'bodycentre' 'body center' 'center'};
BodyPartsNamesDef.Tailbase = {'tailbase' 'Tailbase' 'Tail base' 'tail base'};
TraceOption = 'Smoothed';           % {'Interpolated', 'Original', 'Smoothed'}
DegreeSmoothSGolayDefault = 3; % degree of smoothing
SmoothWindowSmallInSeconds = 0.01;
SmoothWindowBigInSeconds = 0.25;
Options.x_kcorr = 1;
Options.StatusBodyPartThreshold = 99;                                   % threshold for missing bodyparts

PlotOption.main = 1;
PlotOption.acts = 1;
PlotOption.track = 1;

SmoothWindowSmallInFrames = round(FrameRate*SmoothWindowSmallInSeconds);
SmoothWindowBigInFrames = round(FrameRate*SmoothWindowBigInSeconds);

Screensize = get(0, 'Screensize');
LineWidth.Traces.Original = 2;
LineWidth.Traces.Interpolated = 1.5;
LineWidth.Traces.Smoothed = 1;

%% loading videotracking files
if nargin<4
    %%
    [FilenameDLC, PathDLC]  = uigetfile('*.csv','Select DLC file with body parts','g:\_Projects\');
    PathOut = uigetdir('g:\_Projects\', 'Pick a Directory for Outputs');
    MultiAnimalOpt = 0;
end

%% creating main folders for outputs
Filename = FilenameDLC(1:end-4);
if ~isfolder(sprintf('%s\\%s', PathOut, Filename))
    mkdir(PathOut,Filename);
end

PathOut = sprintf('%s\\%s', PathOut, Filename);

num_dir = 1;
while isfolder(sprintf('%s\\%s_%d', PathOut, date, num_dir))
	num_dir = num_dir+1;
end
[s, ~, ~] = mkdir(PathOut,sprintf('%s_%d', date, num_dir));
while ~s
   [s, ~, ~] = mkdir(PathOut,sprintf('%s_%d', date, num_dir));
end
PathOut = sprintf('%s\\%s_%d', PathOut, date, num_dir);

mkdir(PathOut,'BodyPartsTraces');
save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));
%% reading videotracking file

file = readtable(sprintf('%s%s', PathDLC,FilenameDLC));
EndTime = size(file,1);
n_frames = EndTime-StartTime+1; % number of frames for pure experiment
frames = linspace(1, n_frames, n_frames);
time = (1:n_frames)/FrameRate;

[~,fileDLC,~] = xlsread(sprintf('%s%s', PathDLC,FilenameDLC));

if MultiAnimalOpt
    NamesIndividualsDLC = strsplit(fileDLC{2},',');
end

NamesDLC = strsplit(fileDLC{2+MultiAnimalOpt},',');
BodyPartsNumber = (length(NamesDLC)-1)/3;
BodyPartsNames = cell(1, BodyPartsNumber);
BodyPartsOptions = zeros(1, BodyPartsNumber);
IndividualsNames = cell(1, BodyPartsNumber);
for PartName = 1:BodyPartsNumber
    BodyPartsNames{PartName} = NamesDLC{(PartName-1)*3+2};
    BodyPartsOptions(PartName) = (PartName-1)*3+2;
    if MultiAnimalOpt
        IndividualsNames{PartName} = NamesIndividualsDLC{(PartName-1)*3+2};
    end
end
save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));
%clear fileDLC;

%% all body parts detection

ExtraLinesNumber = 0;
BodyPartsTraces = struct('BodyPartName', [], 'TraceOriginal', [],'TraceLikelihood', [], 'PercentNaN', [],'PercentLikeliHoodSubThreshold', [], 'Status', [], 'TraceInterpolated', [], 'TraceSmoothed', [], 'AverageDistance', [],'AverageSpeed', []);
BodyPartsTracesMainX = zeros(BodyPartsNumber,n_frames);
BodyPartsTracesMainY = zeros(BodyPartsNumber,n_frames);

for part=1:BodyPartsNumber
    BodyPartsTraces(part).BodyPartName = BodyPartsNames{part};
    BodyPartsTraces(part).TraceOriginal.X = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)))*Options.x_kcorr;
    BodyPartsTraces(part).TraceOriginal.Y = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)+1));
    BodyPartsTraces(part).TraceLikelihood = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)+2)); 
    
    TempArrayX = BodyPartsTraces(part).TraceOriginal.X;
    TempArrayY = BodyPartsTraces(part).TraceOriginal.Y;
    
    TempArrayX(isnan(BodyPartsTraces(part).TraceOriginal.X)) = 0;
    TempArrayY(isnan(BodyPartsTraces(part).TraceOriginal.Y)) = 0;
    
%     TempArrayX(TempArrayX>Options.Width*Options.x_kcorr) = 0;
%     TempArrayY(TempArrayY>Options.Height) = 0;
    
    TempArrayX(TempArrayX<0) = 0;
    TempArrayY(TempArrayY<0) = 0;
    
    TempArrayX(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold) = 0;
    TempArrayY(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold) = 0;
    
    BodyPartsTraces(part).PercentNaN = mean([round(sum(isnan(BodyPartsTraces(part).TraceOriginal.X))/n_frames*100,2) round(sum(isnan(BodyPartsTraces(part).TraceOriginal.Y))/n_frames*100,2)]);
    BodyPartsTraces(part).PercentLikeliHoodSubThreshold = round(sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100,2);
    
    if sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100 > Options.StatusBodyPartThreshold
        disp(['Bodypart ', BodyPartsTraces(part).BodyPartName, ' not found. Percent undetected timestamps: ', num2str(sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100)]);
        BodyPartsTraces(part).Status = 'NotFound';
        continue;
    else
        BodyPartsTraces(part).Status = 'Good';
    end
    
    TempArrayInt.X = interp1(frames(TempArrayX ~=0), TempArrayX(TempArrayX ~=0), find(TempArrayX == 0), 'pchip');
    TempArrayInt.Y = interp1(frames(TempArrayY ~=0), TempArrayY(TempArrayY ~=0), find(TempArrayY == 0), 'pchip');
    
    TempArrayInt.X(TempArrayInt.X<1) = 1;
    TempArrayInt.Y(TempArrayInt.Y<1) = 1;
%     
%     TempArrayInt.X(TempArrayInt.X>Options.Width*Options.x_kcorr) = Options.Width;
%     TempArrayInt.Y(TempArrayInt.Y>Options.Height) = Options.Height;
    
    TempArrayX(TempArrayX == 0) = TempArrayInt.X;
    TempArrayY(TempArrayY == 0) = TempArrayInt.Y;
    BodyPartsTraces(part).TraceInterpolated.X = TempArrayX;
    BodyPartsTraces(part).TraceInterpolated.Y = TempArrayY;
    
%     if any(ismember(BodyPartsCenterNames, BodyPartsTraces(part).BodyPartName)) || any(ismember(BodyPartsTailbaseNames, BodyPartsTraces(part).BodyPartName))
        SmoothWindow = 10;
%     else
%         SmoothWindow = Options.SmoothWindowSmallInFrames;
%     end

    DegreeSmoothSGolay = min(SmoothWindow-1, DegreeSmoothSGolayDefault);
    BodyPartsTraces(part).TraceSmoothed.X = smooth(BodyPartsTraces(part).TraceInterpolated.X,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    BodyPartsTraces(part).TraceSmoothed.Y = smooth(BodyPartsTraces(part).TraceInterpolated.Y,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    
    BodyPartsTraces(part).TraceSmoothed.X(BodyPartsTraces(part).TraceSmoothed.X<1) = 1;
    BodyPartsTraces(part).TraceSmoothed.Y(BodyPartsTraces(part).TraceSmoothed.Y<1) = 1;
    
%     BodyPartsTraces(part).TraceSmoothed.X(BodyPartsTraces(part).TraceSmoothed.X>Options.Width*Options.x_kcorr) = 1;
%     BodyPartsTraces(part).TraceSmoothed.Y(BodyPartsTraces(part).TraceSmoothed.Y>Options.Height) = 1;
    
    switch TraceOption
        case 'Original'
            BodyPartsTracesMainX(part,:) = BodyPartsTraces(part).TraceOriginal.X;
            BodyPartsTracesMainY(part,:) = BodyPartsTraces(part).TraceOriginal.Y;
        case 'Interpolated'
            BodyPartsTracesMainX(part,:) = BodyPartsTraces(part).TraceInterpolated.X;
            BodyPartsTracesMainY(part,:) = BodyPartsTraces(part).TraceInterpolated.Y;
        case 'Smoothed'
            BodyPartsTracesMainX(part,:) = BodyPartsTraces(part).TraceSmoothed.X;
            BodyPartsTracesMainY(part,:) = BodyPartsTraces(part).TraceSmoothed.Y;
    end
    
    histogram(BodyPartsTraces(part).TraceLikelihood, ceil(sqrt(length(BodyPartsTraces(part).TraceLikelihood))+1), 'BinMethod','fd');
    set(gca, 'YScale', 'log');
    title(sprintf('Body part: %s %s. Histogram of Likelihood log', IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    saveas(gcf, sprintf('%s\\BodyPartsTraces\\%s_%s_Likelihood_log.fig', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    saveas(gcf, sprintf('%s\\BodyPartsTraces\\%s_%s_Likelihood_log.png', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    delete(gcf);
    
    histogram(BodyPartsTraces(part).TraceLikelihood, ceil(sqrt(length(BodyPartsTraces(part).TraceLikelihood))+1), 'BinMethod','fd');
    set(gca, 'YScale');
    title(sprintf('Body part: %s %s. Histogram of Likelihood', IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    saveas(gcf, sprintf('%s\\BodyPartsTraces\\%s_%s_Likelihood.fig', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    saveas(gcf, sprintf('%s\\BodyPartsTraces\\%s_%s_Likelihood.png', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    delete(gcf);
    
    if PlotOption.track
        h = figure('Position', Screensize);
        plot(time,BodyPartsTraces(part).TraceOriginal.X./Options.pxl2sm, 'b', 'LineWidth', LineWidth.Traces.Original); hold on;
        plot(time,BodyPartsTraces(part).TraceInterpolated.X./Options.pxl2sm,'r', 'LineWidth', LineWidth.Traces.Interpolated);hold on;
        plot(time,BodyPartsTraces(part).TraceSmoothed.X./Options.pxl2sm,'g', 'LineWidth', LineWidth.Traces.Smoothed);
        legend({'Original','Interpolated','Smoothed'});
        title(sprintf('Body part: %s. X coordinate',BodyPartsTraces(part).BodyPartName));
        xlabel('Time, s');
        ylabel('Coordinate, cm');
        saveas(h, sprintf('%s\\BodyPartsTraces\\%s_X_coordinate.png', PathOut,BodyPartsTraces(part).BodyPartName));
        saveas(h, sprintf('%s\\BodyPartsTraces\\%s_X_coordinate.fig', PathOut,BodyPartsTraces(part).BodyPartName));
        delete(h);
        
        h = figure('Position', Screensize);
        plot(time,BodyPartsTraces(part).TraceOriginal.Y./Options.pxl2sm, 'b', 'LineWidth', LineWidth.Traces.Original); hold on;
        plot(time,BodyPartsTraces(part).TraceInterpolated.Y./Options.pxl2sm,'r', 'LineWidth', LineWidth.Traces.Interpolated);hold on;
        plot(time,BodyPartsTraces(part).TraceSmoothed.Y./Options.pxl2sm,'g', 'LineWidth', LineWidth.Traces.Smoothed);
        legend({'Original','Interpolated','Smoothed'});
        title(sprintf('Body part: %s. Y coordinate',BodyPartsTraces(part).BodyPartName));
        xlabel('Time, s');
        ylabel('Coordinate, cm');
        saveas(h, sprintf('%s\\BodyPartsTraces\\%s_Y_coordinate.png', PathOut,BodyPartsTraces(part).BodyPartName));
        saveas(h, sprintf('%s\\BodyPartsTraces\\%s_Y_coordinate.fig', PathOut,BodyPartsTraces(part).BodyPartName));
        delete(h);
    end
end

points_for_delete = find(strcmp({BodyPartsTraces.Status}, 'NotFound'));
BodyPartsNames(points_for_delete) = [];
BodyPartsOptions(points_for_delete) = [];
BodyPartsTracesMainX(points_for_delete,:) = [];
BodyPartsTracesMainY(points_for_delete,:) = [];
BodyPartsTraces(points_for_delete) = [];
BodyPartsNumber = length(BodyPartsNames);
  

save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));
%% 

% SumError = zeros(1,3);
% for part=1:BodyPartsNumber
%     SumError = SumError + [BodyPartsTraces(part).PercentLikeliHoodSubThreshold(1) BodyPartsTraces(part).PercentLikeliHoodSubThreshold(2) BodyPartsTraces(part).PercentLikeliHoodSubThreshold(3)];
% end
% 
% AverageError = SumError/BodyPartsNumber
% 
% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));
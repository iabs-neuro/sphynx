function DLC_test(PathDLC, FilenameDLC, PathOut, MultiAnimalOpt)
% script for checking DLC performance

StartTime = 1;
LikelihoodThreshold = 0.6;
FrameRate = 30;
pxl2sm = 8.1;
BodyPartsNamesDef.Center = {'mass centre' 'mass center' 'bodycenter' 'bodycentre' 'body center' 'center'};
BodyPartsNamesDef.Tailbase = {'tailbase' 'Tailbase' 'Tail base' 'tail base'};
TraceOption = 'Smoothed';           % {'Interpolated', 'Original', 'Smoothed'}
DegreeSmoothSGolayDefault = 3; % degree of smoothing
SmoothWindowSmallInSeconds = 0.1;
SmoothWindowBigInSeconds = 0.25;

SmoothWindowSmallInFrames = round(FrameRate*SmoothWindowSmallInSeconds);
SmoothWindowBigInFrames = round(FrameRate*SmoothWindowBigInSeconds);

Screensize = get(0, 'Screensize');
LineWidth.Traces.Original = 2;
LineWidth.Traces.Interpolated = 1.5;
LineWidth.Traces.Smoothed = 1;

%% loading videotracking files
if nargin<4
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

BodyPartsTraces = struct('BodyPartName', [],'TraceOriginal', [],'TraceLikelihood', [], 'TraceInterpolated', [], 'TraceSmoothed', [],'PercentNaN', [],'PercentLikeliHoodSubThreshold', [],'AverageDistance', [],'AverageSpeed', []);
BodyPartsTracesMainX = zeros(BodyPartsNumber,n_frames);
BodyPartsTracesMainY = zeros(BodyPartsNumber,n_frames);
for part=1:BodyPartsNumber
% for part=1:13
    BodyPartsTraces(part).BodyPartName = BodyPartsNames{part};
    BodyPartsTraces(part).TraceOriginal.X = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)));
    BodyPartsTraces(part).TraceOriginal.Y = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)+1));
    BodyPartsTraces(part).TraceLikelihood = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)+2));
    
    TempArrayX = BodyPartsTraces(part).TraceOriginal.X;
    TempArrayY = BodyPartsTraces(part).TraceOriginal.Y;
    TempArrayX(isnan(BodyPartsTraces(part).TraceOriginal.X)) = 0;
    TempArrayY(isnan(BodyPartsTraces(part).TraceOriginal.Y)) = 0;
    
    BodyPartsTraces(part).PercentNaN.X = round(sum(isnan(BodyPartsTraces(part).TraceOriginal.X))/n_frames*100,2);
    BodyPartsTraces(part).PercentNaN.Y = round(sum(isnan(BodyPartsTraces(part).TraceOriginal.Y))/n_frames*100,2);
    BodyPartsTraces(part).PercentLikeliHoodSubThreshold = [round(sum(BodyPartsTraces(part).TraceLikelihood > 0.99)/n_frames*100,2)...
        round(sum(BodyPartsTraces(part).TraceLikelihood > 0.95)/n_frames*100,2)...
        round(sum(BodyPartsTraces(part).TraceLikelihood > 0.6)/n_frames*100,2)];
    

     TempArrayX(BodyPartsTraces(part).TraceLikelihood < LikelihoodThreshold) = 0;
     TempArrayY(BodyPartsTraces(part).TraceLikelihood < LikelihoodThreshold) = 0;
    
    %TempArrayX(TempArrayX<10) = 0;
    %TempArrayY(TempArrayY<10) = 0;
    
    TempArrayInt.X = interp1(frames(TempArrayX ~=0), TempArrayX(TempArrayX ~=0), find(TempArrayX == 0),'linear');
    TempArrayInt.Y = interp1(frames(TempArrayY ~=0), TempArrayY(TempArrayY ~=0), find(TempArrayY == 0),'linear');
    
    TempArrayX(TempArrayX == 0) = TempArrayInt.X;
    TempArrayY(TempArrayY == 0) = TempArrayInt.Y;
    BodyPartsTraces(part).TraceInterpolated.X = TempArrayX;
    BodyPartsTraces(part).TraceInterpolated.Y = TempArrayY;
    
    if any(ismember(BodyPartsNamesDef.Center, BodyPartsTraces(part).BodyPartName)) || any(ismember(BodyPartsNamesDef.Tailbase, BodyPartsTraces(part).BodyPartName))
        SmoothWindow = SmoothWindowBigInFrames;
    else
        SmoothWindow = SmoothWindowSmallInFrames;
    end
    DegreeSmoothSGolay = min(SmoothWindow-1, DegreeSmoothSGolayDefault);
    BodyPartsTraces(part).TraceSmoothed.X = smooth(BodyPartsTraces(part).TraceInterpolated.X,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    BodyPartsTraces(part).TraceSmoothed.Y = smooth(BodyPartsTraces(part).TraceInterpolated.Y,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    
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
    
    h = figure('Position', Screensize);
    plot(time,BodyPartsTraces(part).TraceOriginal.X./pxl2sm, 'b', 'LineWidth', LineWidth.Traces.Original); hold on;
    plot(time,BodyPartsTraces(part).TraceInterpolated.X./pxl2sm,'r', 'LineWidth', LineWidth.Traces.Interpolated);hold on;
    plot(time,BodyPartsTraces(part).TraceSmoothed.X./pxl2sm,'g', 'LineWidth', LineWidth.Traces.Smoothed);
    legend({'Original','Interpolated','Smoothed'});
    title(sprintf('Body part: %s %s. X coordinate',IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    xlabel('Time, s');
    ylabel('Coordinate, cm');
    saveas(h, sprintf('%s\\BodyPartsTraces\\%s_%s_X_coordinate.png', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    saveas(h, sprintf('%s\\BodyPartsTraces\\%s_%s_X_coordinate.fig', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    delete(h);    
    
    h = figure('Position', Screensize);
    plot(time,BodyPartsTraces(part).TraceOriginal.Y./pxl2sm, 'b', 'LineWidth', LineWidth.Traces.Original); hold on;
    plot(time,BodyPartsTraces(part).TraceInterpolated.Y./pxl2sm,'r', 'LineWidth', LineWidth.Traces.Interpolated);hold on;
    plot(time,BodyPartsTraces(part).TraceSmoothed.Y./pxl2sm,'g', 'LineWidth', LineWidth.Traces.Smoothed);
    legend({'Original','Interpolated','Smoothed'});
    title(sprintf('Body part: %s %s. Y coordinate',IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    xlabel('Time, s');
    ylabel('Coordinate, cm');
    saveas(h, sprintf('%s\\BodyPartsTraces\\%s_%s_Y_coordinate.png', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    saveas(h, sprintf('%s\\BodyPartsTraces\\%s_%s_Y_coordinate.fig', PathOut,IndividualsNames{part},BodyPartsTraces(part).BodyPartName));
    delete(h);
%     
end

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
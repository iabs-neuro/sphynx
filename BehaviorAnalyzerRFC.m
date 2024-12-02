function [BodyPartsTraces] = BehaviorAnalyzerRFC(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, StartTime, EndTime, PathPreset, FilenamePreset)
% VVP. Deep Behavior analyses tool
% 22.11.24 Rudy fear Conditioning

% Input description
% PathVideo - path of video file
% FilenameVideo - filename of video file
% PathDLC - path of videotracking file
% FilenameDLC - filename of videotracking file
% PathOut - path of folder for main outputs
% StartTime - time point in frames for beginning behavior analysis
% EndTime - time point in frames for ending behavior analysis
% PathPreset - path of file with preset parameters
% FilenamePreset - filename of file with preset parameters

% Types of experiment description
% 'RT' for o-maze track, 0 objects
% 'HT' for maze with holes, circle arena, 1-3 objects
% 'OT' for STFP experiment, rectangle arena, 2-3 objects
% 'OP' for Open Field, square, 0 objects
% 'FT' for freezing chamber box, rectangle arena, real trajectory
% extraction first
% 'NT' for new track, manual parameters selection

% all parameters
BodyPartsCenterNames = {'mass centre' 'mass center' 'bodycenter' 'center'};
BodyPartsTailbaseNames = {'tailbase' 'Tailbase' 'Tail base' 'tail base'};
BodyPartsNoseNames = {'nose', 'Nose'};
Point.LeftBodyCenter = 8;
Point.RightBodyCenter = 9;
Point.LeftHindLimb = 10;
Point.RightHindLimb = 11;
Point.LeftEar = 3;
Point.RightEar = 4;
TraceOption = 'Smoothed';           % 'Original' or 'Interpolated' or 'Smoothed'
FreezingMode = 'NoseAndCenter';     % 'AllBodyParts' or 'NoseAndCenter'
RearMode = 'TailbasePaws';          % 'TailbasePaws' or 'AllBodyParts'
RearsThreshold.AllBodyParts = 170;
RearsThreshold.TailbasePawscm = 3.6; % 2.3
DegreeDerivatives = 3; % how many derivatives of coordinates are needed
DegreeSmoothSGolayDefault = 3;

PlotOption.main = 1;
PlotOption.acts = 1;
PlotOption.track = 1;

MarkSize = 3;
LineWidth.Traces.Original = 2;
LineWidth.Traces.Interpolated = 1.5;
LineWidth.Traces.Smoothed = 1;
VideoScale = 3;
AngleDop = -pi/2;

%% loading all data

if nargin<9
    %% loading video and videotracking files
    [FilenameVideo, PathVideo]  = uigetfile('*.*','Select video file','d:\Projects\H_mice\2_RawCombineVideo\');
    [FilenameDLC, PathDLC]  = uigetfile('*.csv','Select DLC file with body parts','d:\Projects\H_mice\3_DLC\');
    PathOut = uigetdir('d:\Projects\H_mice\5_Behavior\', 'Pick a Directory for Outputs');
    
    % loading preset file
    answer = questdlg('Do you have preset file?', 'Uploading files', 'Yes','No','Yes');
    switch answer
        case 'Yes'
            [FilenamePreset, PathPreset]  = uigetfile('*.mat','Select preset file','d:\Projects\H_mice\4_Presets\');
        case 'No'
            [FilenamePreset, PathPreset] = CreatePreset(FilenameVideo,PathVideo,PathOut);
    end
    
    % loading of trim time parameters
    dlg_data = inputdlg({'Start frame (minimum 1)', 'Last time (0 - for whole video)'}, 'Parameters', 1, {'1', '0'}, 'on');
    StartTime = str2double(dlg_data{1});
    EndTime = str2double(dlg_data{2});
end

%% reading all data

% reading preset file
load(sprintf('%s//%s', PathPreset, FilenamePreset), 'Options','Zones', 'ArenaAndObjects');
Options.EnablePointThreshold = 90;

% reading video file
readerobj = VideoReader(sprintf('%s%s', PathVideo, FilenameVideo));

% reading videotracking file
file = readtable(sprintf('%s%s', PathDLC,FilenameDLC));

try
    [~,fileDLC,~] = xlsread(sprintf('%s%s', PathDLC,FilenameDLC));
catch
    fileID = fopen(sprintf('%s%s', PathDLC,FilenameDLC), 'r');
    numLines = 3;
    fileDLC = cell(3, 1);
    for i = 1:numLines
        fileDLC{i} = fgetl(fileID);
    end
    fclose(fileID);
end

switch Options.ExperimentType
    % for DLC data
    case {'BowlsOpenField','Novelty OF','Holes Track','Odor Track','Freezing Track','New Track','Complex Context','NOL','OF_Obj'}
        NamesDLC = strsplit(fileDLC{2},',');
        BodyPartsNumber = (length(NamesDLC)-1)/3;
        BodyPartsNames = cell(1, BodyPartsNumber);
        BodyPartsOptions = zeros(1, BodyPartsNumber);
        for PartName = 1:BodyPartsNumber
           BodyPartsNames{PartName} = NamesDLC{(PartName-1)*3+2};
           BodyPartsOptions(PartName) = (PartName-1)*3+2;
        end
    case 'Round Track'
        % for tracking markers data
        NamesDLC = strsplit(fileDLC{1},',');
        BodyPartsNumber = length(NamesDLC)/2;
        BodyPartsNames = cell(1, BodyPartsNumber);
        BodyPartsOptions = zeros(1, BodyPartsNumber);
        for PartName = 2:BodyPartsNumber
           BodyPartsNames{PartName-1} = NamesDLC{(PartName-1)*2+1};
           BodyPartsOptions(PartName-1) = (PartName-1)*2+1;
        end
end
clear fileDLC;

if Options.NumFrames == size(file,1)
    fprintf('Synchronization is correct\n');
else
    fprintf('Warning! Synchronization is not correct\n');
end

%% creating main folders for outputs
Filename = FilenameVideo(1:end-4);
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
mkdir(PathOut,'ActsHistogram');
mkdir(PathOut,'ActsVideo');

%% some options

Screensize = get(0, 'Screensize');

if EndTime == 0
    EndTime = size(file,1);
end

n_frames = EndTime-StartTime+1; % number of frames for pure experiment
time = (1:n_frames)/Options.FrameRate;
frames = linspace(1, n_frames, n_frames);

% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% all body parts detection

% % костыль для минископных данных
% BodyPartsNumber =  13;
% BodyPartsNames(14) =  [];
% BodyPartsOptions(14) = [];

% % костыль для БЕЗ минископных данных
% BodyPartsNumber =  12;
% BodyPartsNames(1) =  [];
% BodyPartsOptions(1) = [];
% BodyPartsNames(13) =  [];
% BodyPartsOptions(13) = [];

ExtraLinesNumber = 0;
BodyPartsTraces = struct('BodyPartName', [],'TraceOriginal', [],'TraceLikelihood', [], 'TraceInterpolated', [], 'TraceSmoothed', [],'PercentNaN', [],'PercentLikeliHoodSubThreshold', [],'AverageDistance', [],'AverageSpeed', []);
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
    
    TempArrayX(TempArrayX>Options.Width*Options.x_kcorr) = 0;
    TempArrayY(TempArrayY>Options.Height) = 0;
    
    TempArrayX(TempArrayX<0) = 0;
    TempArrayY(TempArrayY<0) = 0;
    
    BodyPartsTraces(part).PercentNaN.X = round(sum(isnan(BodyPartsTraces(part).TraceOriginal.X))/n_frames*100,2);
    BodyPartsTraces(part).PercentNaN.Y = round(sum(isnan(BodyPartsTraces(part).TraceOriginal.Y))/n_frames*100,2);
    BodyPartsTraces(part).PercentLikeliHoodSubThreshold = round(sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100,2);
    
    TempArrayX(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold) = 0;
    TempArrayY(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold) = 0;
    
    TempArrayInt.X = interp1(frames(TempArrayX ~=0), TempArrayX(TempArrayX ~=0), find(TempArrayX == 0),'pchip');
    TempArrayInt.Y = interp1(frames(TempArrayY ~=0), TempArrayY(TempArrayY ~=0), find(TempArrayY == 0),'pchip');
    
    TempArrayInt.X(TempArrayInt.X<1) = 1;
    TempArrayInt.Y(TempArrayInt.Y<1) = 1;
    
    TempArrayInt.X(TempArrayInt.X>Options.Width*Options.x_kcorr) = Options.Width;
    TempArrayInt.Y(TempArrayInt.Y>Options.Height) = Options.Height;
    
    TempArrayX(TempArrayX == 0) = TempArrayInt.X;
    TempArrayY(TempArrayY == 0) = TempArrayInt.Y;
    BodyPartsTraces(part).TraceInterpolated.X = TempArrayX;
    BodyPartsTraces(part).TraceInterpolated.Y = TempArrayY;
    
    if any(ismember(BodyPartsCenterNames, BodyPartsTraces(part).BodyPartName)) || any(ismember(BodyPartsTailbaseNames, BodyPartsTraces(part).BodyPartName))
        SmoothWindow = Options.SmoothWindowBigInFrames;
    else
        SmoothWindow = Options.SmoothWindowSmallInFrames;
    end
    DegreeSmoothSGolay = min(SmoothWindow-1, DegreeSmoothSGolayDefault);
    BodyPartsTraces(part).TraceSmoothed.X = smooth(BodyPartsTraces(part).TraceInterpolated.X,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    BodyPartsTraces(part).TraceSmoothed.Y = smooth(BodyPartsTraces(part).TraceInterpolated.Y,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    
    BodyPartsTraces(part).TraceSmoothed.X(BodyPartsTraces(part).TraceSmoothed.X<1) = 1;
    BodyPartsTraces(part).TraceSmoothed.Y(BodyPartsTraces(part).TraceSmoothed.Y<1) = 1;
    
    BodyPartsTraces(part).TraceSmoothed.X(BodyPartsTraces(part).TraceSmoothed.X>Options.Width*Options.x_kcorr) = 1;
    BodyPartsTraces(part).TraceSmoothed.Y(BodyPartsTraces(part).TraceSmoothed.Y>Options.Height) = 1;
    
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

% BodyPartsNames(points_for_delete) = [];
% BodyPartsOptions(points_for_delete) = [];
% BodyPartsTracesMainX(points_for_delete,:) = [];
% BodyPartsTracesMainY(points_for_delete,:) = [];
% BodyPartsTraces(points_for_delete) = [];
% BodyPartsNumber = length(BodyPartsNames);

% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

% searching central and tailbase bodyparts
Point.Tailbase = find(strcmp(BodyPartsNames, BodyPartsTailbaseNames(ismember(BodyPartsTailbaseNames, BodyPartsNames))));
Point.Nose = find(strcmp(BodyPartsNames, BodyPartsNoseNames(ismember(BodyPartsNoseNames, BodyPartsNames))));


%% creat real trajectory for freezing track mode
switch Options.ExperimentType
    case 'Freezing Track'
        [BodyPartsTracesMainXReal,BodyPartsTracesMainYReal] = TrackTransformerFC(BodyPartsTracesMainX, BodyPartsTracesMainY, Options, Point, PathOut, Filename, readerobj);
end

%% calculation kinematogramma

MouseCenterX = BodyPartsTracesMainXReal;
MouseCenterY = BodyPartsTracesMainYReal;

MouseCenterX = MouseCenterX/Options.pxl2sm;
MouseCenterY = MouseCenterY/Options.pxl2sm;

%% creating outputs table of features

Features.Name = {'x', 'y'};
Features.Data(1:n_frames,1) = MouseCenterX';
Features.Data(1:n_frames,2) = MouseCenterY';

Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);

writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, Filename));
save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

end

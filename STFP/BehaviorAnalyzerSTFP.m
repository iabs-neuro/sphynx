function [Acts, BodyPartsTraces] = BehaviorAnalyzerSTFP(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut,StartTime, EndTime, PathPreset, FilenamePreset)
% VVP. Deep Behavior analyses tool
% 20.03 Freezing box mod added
% 14.06.24 STFP features added. Options.MinLengthActInFrames = 10 frames
% manually

% ToDo Bowl features

% !!! CHANGE Options.LikelihoodThreshold = [0.01 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.6];

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
Point.LeftBodyCenter = 7;
Point.RightBodyCenter = 8;
Point.LeftHindLimb = 9;
Point.RightHindLimb = 10;
Point.LeftEar = 2;
Point.RightEar = 3;
TraceOption = 'Smoothed';           % 'Original' or 'Interpolated' or 'Smoothed'
FreezingMode = 'NoseAndCenter';     % 'AllBodyParts' or 'NoseAndCenter'
RearMode = 'TailbasePaws';          % 'TailbasePaws' or 'AllBodyParts'
RearsThreshold.AllBodyParts = 19.4;
RearsThreshold.TailbasePawscm = 2.62;
FeedingThresholdInseconds = 5; % in second for feeding
DegreeDerivatives = 3; % how many derivatives of coordinates are needed
DegreeSmoothSGolayDefault = 3;

% plot options
% PlotOption.speed = 1;
% PlotOption.space = 1;
% PlotOption.acts = 1;
PlotOption.main = 1;

% FontSize = 40;
MarkSize = 5;
LineWidth.Traces.Original = 2;
LineWidth.Traces.Interpolated = 1.5;
LineWidth.Traces.Smoothed = 1;
VideoScale = 3;
VideoScaleV = 1.5;
AngleDop = -pi/2;

%% loading all data
if nargin<9
    %% loading video and videotracking files
    [FilenameVideo, PathVideo]  = uigetfile('*.*','Select video file','i:\_STFP\_VideoData\1_RawData\');
    [FilenameDLC, PathDLC]  = uigetfile('*.csv','Select DLC file with body parts','i:\_STFP\_VideoData\2_DLC\');
    PathOut = uigetdir('i:\_STFP\_VideoData\4_Sphynx\', 'Pick a Directory for Outputs');
    
    % loading preset file
    answer = questdlg('Do you have preset file?', 'Uploading files', 'Yes','No','Yes');
    switch answer
        case 'Yes'
            [FilenamePreset, PathPreset]  = uigetfile('*.mat','Select preset file','i:\_STFP\_VideoData\3_Presets\');
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
load(sprintf('%s//%s', PathPreset, FilenamePreset), 'Options','Zones');
Options.EnablePointThreshold = 90;
Options.MinLengthActInFrames = 10;
Options.LikelihoodThreshold = [0.01 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.95 0.6];

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
    case {'Novelty OF','Holes Track','Odor Track','Freezing Track','New Track', 'Complex Context', 'NOL'}
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

% PathOutMain = PathOut;
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

save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% all body parts detection

% костыль для минископных данных
% for NVista
BodyPartsNumber =  13;
BodyPartsNames(1) =  [];
BodyPartsOptions(1) = [];
% for UCLA
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
    BodyPartsTraces(part).PercentLikeliHoodSubThreshold = round(sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold(part))/n_frames*100,2);
    
    TempArrayX(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold(part)) = 0;
    TempArrayY(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold(part)) = 0;
    
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

% BodyPartsNames(points_for_delete) = [];
% BodyPartsOptions(points_for_delete) = [];
% BodyPartsTracesMainX(points_for_delete,:) = [];
% BodyPartsTracesMainY(points_for_delete,:) = [];
% BodyPartsTraces(points_for_delete) = [];
% BodyPartsNumber = length(BodyPartsNames);

save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% creat real trajectory for freezing track mode
switch Options.ExperimentType
    case 'Freezing Track'
        [BodyPartsTracesMainX,BodyPartsTracesMainY] = TrackTransformer(ArenaAndObjects.point_x, ArenaAndObjects.point_y, BodyPartsTracesMainX, BodyPartsTracesMainY, Options);
end

%% calculation kinematogramma

% searching central and tailbase bodyparts
Point.Tailbase = find(strcmp(BodyPartsNames, BodyPartsTailbaseNames(ismember(BodyPartsTailbaseNames, BodyPartsNames))));
Point.Nose = find(strcmp(BodyPartsNames, BodyPartsNoseNames(ismember(BodyPartsNoseNames, BodyPartsNames))));

if any(ismember(BodyPartsCenterNames, BodyPartsNames))
    Point.Center = find(strcmp(BodyPartsNames, BodyPartsCenterNames(ismember(BodyPartsCenterNames, BodyPartsNames))));
    MouseCenterX = BodyPartsTracesMainX(Point.Center,:);
    MouseCenterY = BodyPartsTracesMainY(Point.Center,:);
else
    MouseCenterX = (BodyPartsTracesMainX(Point.LeftBodyCenter,:)+BodyPartsTracesMainX(Point.RightBodyCenter,:))/2;
    MouseCenterY = (BodyPartsTracesMainY(Point.LeftBodyCenter,:)+BodyPartsTracesMainY(Point.RightBodyCenter,:))/2;
    BodyPartsTracesMainX(end+1,:) =  MouseCenterX;
    BodyPartsTracesMainY(end+1,:) =  MouseCenterY;
    Point.Center = size(BodyPartsTracesMainX,1);
end
MouseCenterX = MouseCenterX/Options.pxl2sm;
MouseCenterY = MouseCenterY/Options.pxl2sm;

% creation relative to tailbase coordinates
BodyPartsRelativeX = (BodyPartsTracesMainX - BodyPartsTracesMainX(Point.Tailbase,:));
BodyPartsRelativeY = (BodyPartsTracesMainY - BodyPartsTracesMainY(Point.Tailbase,:));

% convert to polar coordinates
[BodyPartsRelativeTH,BodyPartsRelativeR]=cart2pol(BodyPartsRelativeX,BodyPartsRelativeY); 
AngleRot = BodyPartsRelativeTH(Point.Center,:);
BodyPartsRelativeTH = wrapToPi(BodyPartsRelativeTH - AngleRot);
BodyPartsRelativeR = BodyPartsRelativeR/Options.pxl2sm;
BodyPartsRelativeR(Point.Tailbase,:) = [];
BodyPartsRelativeTH(Point.Center,:) = AngleRot;
BodyPartsRelativeTH(Point.Tailbase,:) = [];

% calculation all derivatives
BodyPartsAbsolut = zeros((DegreeDerivatives+1)*2, n_frames);
BodyPartsAbsolut(1:2,:) = [MouseCenterX;MouseCenterY];

BodyPartsRelativeRDiff = zeros(size(BodyPartsRelativeR,1)*(DegreeDerivatives+1), n_frames);
BodyPartsRelativeRDiff(1:size(BodyPartsRelativeR,1),:) = BodyPartsRelativeR;
for part = 1:size(BodyPartsRelativeR,1)
    for degree = 1:DegreeDerivatives
        TempArray = [0 diff(BodyPartsRelativeRDiff(part+(degree-1)*size(BodyPartsRelativeR,1),:))];
        BodyPartsRelativeRDiff(part+(degree)*size(BodyPartsRelativeR,1),:) = [interp1(min(degree,2)+1:n_frames, TempArray(min(degree,2)+1:end),1:min(degree,2), 'linear', 'extrap') TempArray(min(degree,2)+1:end)].*Options.FrameRate;
    end
end

BodyPartsRelativeTHDiff = zeros(size(BodyPartsRelativeTH,1)*(DegreeDerivatives+1), n_frames);
for line = 1:size(BodyPartsRelativeTH,1)
    BodyPartsRelativeTHDiff(line,:) = unwrap(BodyPartsRelativeTH(line,:), pi);
end

BodyPartsRelativeTHDiff(1:size(BodyPartsRelativeTH,1),:) = unwrap(BodyPartsRelativeTH, pi);
for part = 1:size(BodyPartsRelativeTH,1)
    for degree = 1:DegreeDerivatives
        TempArray = [0 diff(BodyPartsRelativeTHDiff(part+(degree-1)*size(BodyPartsRelativeTH,1),:))];
        BodyPartsRelativeTHDiff(part+(degree)*size(BodyPartsRelativeTH,1),:) = [interp1(min(degree,2)+1:n_frames, TempArray(min(degree,2)+1:end),1:min(degree,2), 'linear', 'extrap') TempArray(min(degree,2)+1:end)].*Options.FrameRate;
    end
end

TempArrayX = BodyPartsAbsolut(1,:);
TempArrayY = BodyPartsAbsolut(2,:);
for degree = 1:DegreeDerivatives
    TempArrayX = [0 diff(TempArrayX)];
    TempArrayY = [0 diff(TempArrayY)];
    BodyPartsAbsolut((degree+1)*2-1,:) = sqrt((TempArrayX).^2+(TempArrayY).^2)*Options.FrameRate;
    BodyPartsAbsolut((degree+1)*2,:) = atan2(TempArrayY,TempArrayX);
    BodyPartsAbsolut((degree+1)*2-1,:) = [interp1(min(degree,2)+1:n_frames, BodyPartsAbsolut((degree+1)*2-1,min(degree,2)+1:end),1:min(degree,2), 'linear', 'extrap') BodyPartsAbsolut((degree+1)*2-1,min(degree,2)+1:end)];
    BodyPartsAbsolut((degree+1)*2,:) = wrapToPi([interp1(min(degree,2)+1:n_frames, BodyPartsAbsolut((degree+1)*2,min(degree,2)+1:end),1:min(degree,2), 'linear', 'extrap') BodyPartsAbsolut((degree+1)*2,min(degree,2)+1:end)]);
end

BodyPartsAll = [BodyPartsAbsolut;BodyPartsRelativeRDiff;BodyPartsRelativeTHDiff];

csvwrite(sprintf('%s\\%s_Kinematogramma.csv',PathOut,Filename), BodyPartsAll');
save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% video with absolut and relative coordinates

BodyPartsX_polar = BodyPartsRelativeR.*cos(BodyPartsRelativeTH+AngleDop);
BodyPartsY_polar = BodyPartsRelativeR.*sin(BodyPartsRelativeTH+AngleDop);
BodyPartsX_polar(end,:) = zeros(1, n_frames);
BodyPartsY_polar(end,:) = zeros(1, n_frames);
BodyPartsX_polar(end+1,:) = BodyPartsRelativeR(end,:).*cos(AngleDop);
BodyPartsY_polar(end+1,:) = BodyPartsRelativeR(end,:).*sin(AngleDop);
BodyPartsX_polar = BodyPartsX_polar.*VideoScale.*Options.pxl2sm + round(Options.Width/2);
BodyPartsY_polar = BodyPartsY_polar.*VideoScale.*Options.pxl2sm + round(Options.Height*2/3);

BodyPartsVRX_polar = BodyPartsRelativeRDiff(BodyPartsNumber:2*(BodyPartsNumber-1),:).*cos(BodyPartsRelativeTH+AngleDop);
BodyPartsVRY_polar = BodyPartsRelativeRDiff(BodyPartsNumber:2*(BodyPartsNumber-1),:).*sin(BodyPartsRelativeTH+AngleDop);
BodyPartsVTHX_polar = BodyPartsRelativeTHDiff(BodyPartsNumber:2*(BodyPartsNumber-1)-1,:).*cos(BodyPartsRelativeTH(1:BodyPartsNumber-2,:)+pi/2.+AngleDop);
BodyPartsVTHY_polar = BodyPartsRelativeTHDiff(BodyPartsNumber:2*(BodyPartsNumber-1)-1,:).*sin(BodyPartsRelativeTH(1:BodyPartsNumber-2,:)+pi/2.+AngleDop);
BodyPartsVRX_polar(end,:) = BodyPartsAbsolut(3,:).*cos(BodyPartsAbsolut(4,:)-AngleRot+AngleDop).*VideoScaleV;
BodyPartsVRY_polar(end,:) = BodyPartsAbsolut(3,:).*sin(BodyPartsAbsolut(4,:)-AngleRot+AngleDop).*VideoScaleV;
BodyPartsVRX_polar(end+1,:) = BodyPartsRelativeRDiff(BodyPartsNumber*2,:).*cos(AngleDop);
BodyPartsVRY_polar(end+1,:) = BodyPartsRelativeRDiff(BodyPartsNumber*2,:).*sin(AngleDop);
BodyPartsVTHX_polar = BodyPartsVTHX_polar.*VideoScale;
BodyPartsVTHY_polar = BodyPartsVTHY_polar.*VideoScale;

%% trajectory analysis
% h = figure;
% plot(MouseCenterX,MouseCenterY);
% title(sprintf('Body part: %s. Y coordinate',BodyPartsTraces(part).BodyPartName));
% xlabel('Time, s');
% ylabel('Coordinate, cm');
% saveas(h, sprintf('%s\\BodyPartsTraces\\%s_Y_coordinate.png', PathOut,BodyPartsTraces(part).BodyPartName));
% saveas(h, sprintf('%s\\BodyPartsTraces\\%s_Y_coordinate.fig', PathOut,BodyPartsTraces(part).BodyPartName));
% delete(h);
%% make a main video

BlackFrame = uint8(zeros(Options.Height,Options.Width));
colorbase = jet(BodyPartsNumber);
if PlotOption.main
    v = VideoWriter(sprintf('%s\\%s_BodyParts',PathOut, Filename),'MPEG-4');
    v.FrameRate = Options.FrameRate;
    open(v);
    h = waitbar(1/n_frames, sprintf('Plotting video, frame %d of %d', 0,  n_frames));
%     for k=1:n_frames
    for k=2000:2200
        if ~mod(k,100)
            h = waitbar(k/n_frames, h, sprintf('Plotting video, frame %d of %d', k,  n_frames));
        end
        RealFrame = read(readerobj,k+StartTime-1);
        
        % points of bodyparts in a moving frame of reference
        IM(:,:,1) = BlackFrame;
        IM(:,:,2) = BlackFrame;
        IM(:,:,3) = BlackFrame;
        for part=1:length(BodyPartsNames)
            IM = insertShape(IM,'filledcircle', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) MarkSize*2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end
        
        % points of bodyparts in a fixed frame of reference
        for part=1:length(BodyPartsNames)
            RealFrame = insertShape(RealFrame,'circle', [BodyPartsTraces(part).TraceOriginal.X(k)/Options.x_kcorr BodyPartsTraces(part).TraceOriginal.Y(k) MarkSize*2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            RealFrame = insertShape(RealFrame,'filledcircle', [BodyPartsTracesMainX(part,k)/Options.x_kcorr BodyPartsTracesMainY(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end
        
%         % radial velocities of bodyparts in a moving frame of reference
%         for part=1:length(BodyPartsNames)
%             if part == Point.Tailbase
%                 IM = insertShape(IM, 'Line', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) BodyPartsX_polar(part,k)+BodyPartsVRX_polar(part,k) BodyPartsY_polar(part,k)+BodyPartsVRY_polar(part,k)], 'LineWidth', 4, 'Color', 'red');
%             else
%                 IM = insertShape(IM, 'Line', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) BodyPartsX_polar(part,k)+BodyPartsVRX_polar(part,k) BodyPartsY_polar(part,k)+BodyPartsVRY_polar(part,k)], 'LineWidth', 2, 'Color', 'red');
%             end
%         end
        
%         % angular velocities of bodyparts in a moving frame of reference
%         for part=1:length(BodyPartsNames)-2
%             IM = insertShape(IM, 'Line', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) BodyPartsX_polar(part,k)+BodyPartsVTHX_polar(part,k) BodyPartsY_polar(part,k)+BodyPartsVTHY_polar(part,k)], 'LineWidth', 2, 'Color', 'yellow');
%         end
        
        IMM = [IM RealFrame];
        writeVideo(v,IMM);
    end
    close(v);
    delete(h);
end
%% velocity zones calculations

% velocity of all bodyparts calculation
h = figure;
for part = 1:BodyPartsNumber
    TempArrayX = [0 diff(BodyPartsTracesMainX(part,:))];
    TempArrayY = [0 diff(BodyPartsTracesMainY(part,:))];    
    if any(ismember(BodyPartsCenterNames, BodyPartsTraces(part).BodyPartName)) || any(ismember(BodyPartsTailbaseNames, BodyPartsTraces(part).BodyPartName))
        SmoothWindow = Options.SmoothWindowBigInFrames;
    else
        SmoothWindow = Options.SmoothWindowSmallInFrames;
    end
    DegreeSmoothSGolay = min(SmoothWindow-1, DegreeSmoothSGolayDefault);
    BodyPartsTraces(part).Velocity = sqrt((TempArrayX).^2+(TempArrayY).^2)*Options.FrameRate./Options.pxl2sm;
    BodyPartsTraces(part).Velocity = [interp1(2:n_frames, BodyPartsTraces(part).Velocity(2:end), 1, 'linear', 'extrap') BodyPartsTraces(part).Velocity(2:end)];
    BodyPartsTraces(part).VelocitySmoothed = smooth(BodyPartsTraces(part).Velocity,SmoothWindow,'sgolay',DegreeSmoothSGolay);
    BodyPartsTraces(part).AverageSpeed = round(mean(BodyPartsTraces(part).VelocitySmoothed),2);
    BodyPartsTraces(part).AverageDistance = round(BodyPartsTraces(part).AverageSpeed*time(end)/100,2);
    plot(time,BodyPartsTraces(part).VelocitySmoothed); hold on;
end
legend({BodyPartsTraces.BodyPartName});
title('Body parts velocity');
xlabel('Time, s');
ylabel('Speed, cm/s');
saveas(h, sprintf('%s\\%s_BodyParts_speeds.fig', PathOut,Filename));
saveas(h, sprintf('%s\\%s_BodyParts_speeds.png', PathOut,Filename));
delete(h);

save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% Acts definition
Acts = struct('ActName', [], 'ActArray', [],'ActArrayRefine', [], 'ActNumber', [], 'ActPercent', [], 'ActDistr', [], 'ActMeanTime', [],'ActMeanSTDTime', [], 'ActMedianTime', [], 'ActMedianMADTime', []);

Options.SpeedOptions{1} = 'rest';
Options.SpeedOptions{2} = 'walk';
Options.SpeedOptions{3} = 'locomotion';
Acts(1).ActName = Options.SpeedOptions{1};
Acts(2).ActName = Options.SpeedOptions{2};
Acts(3).ActName = Options.SpeedOptions{3};
Acts(4).ActName = 'freezing';
Acts(5).ActName = 'rear';
Velocity = BodyPartsTraces(strcmp({BodyPartsTraces.BodyPartName}, Options.BodyPart.Velocity)).VelocitySmoothed;

% rest acts calculation
Acts(1).ActArray = double(Velocity < Options.velocity_rest);
[Acts(1).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(1).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(1).ActArrayRefine = Acts(1).ActArrayRefine';

TempArrayVel = ~Acts(1).ActArrayRefine;

% locomotion acts calculation
Acts(3).ActArray = double((Velocity > Options.velocity_locomotion).*TempArrayVel);
[Acts(3).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(3).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(3).ActArrayRefine = Acts(3).ActArrayRefine';

% other speed acts calculation
Acts(2).ActArray = double(~(Acts(1).ActArrayRefine+Acts(3).ActArrayRefine));
[Acts(2).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(2).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(2).ActArrayRefine = Acts(2).ActArrayRefine';

TempArrayVelOther = Acts(2).ActArray-Acts(2).ActArrayRefine;
[~,~,~,~,frame_in,frame_out] = RefineLine(TempArrayVelOther, 0, 0);

for i=1:length(frame_in)
    if mean(Velocity(frame_in(i):frame_out(i)))>(Options.velocity_locomotion+Options.velocity_rest)/2
        Acts(3).ActArrayRefine(frame_in(i):frame_out(i)) = 1;
    else
        Acts(1).ActArrayRefine(frame_in(i):frame_out(i)) = 1;
    end
end

% freezing definition
switch FreezingMode
    case 'AllBodyParts'
        TempArray = zeros(n_frames,1);
        for part = 1:BodyPartsNumber
            TempArray = TempArray + BodyPartsTraces(part).VelocitySmoothed;
        end
        Acts(4).ActArray = double(TempArray < Options.velocity_rest*BodyPartsNumber);
    case 'NoseAndCenter'
        Acts(4).ActArray = double((BodyPartsTraces(Point.Nose).VelocitySmoothed < Options.velocity_rest*2).*(BodyPartsTraces(Point.Center).VelocitySmoothed < Options.velocity_rest));
end
[Acts(4).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(4).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(4).ActArrayRefine = Acts(4).ActArrayRefine';

% rears definition
RearsThreshold.TailbasePaws = RearsThreshold.TailbasePawscm*Options.pxl2sm;
TempArray = zeros(n_frames,1);
switch RearMode
    case 'AllBodyParts'
        for i=1:n_frames
            for part=1:BodyPartsNumber
                TempArray(i) = TempArray(i) + sqrt((BodyPartsTracesMainX(Point.Center,i)-BodyPartsTracesMainX(part,i))^2 + (BodyPartsTracesMainY(Point.Center,i)-BodyPartsTracesMainY(part,i))^2);
            end
        end
        TempArraySmooth = smooth(TempArray, Options.FrameRate);
        Acts(5).ActArray = double(TempArraySmooth < RearsThreshold.AllBodyParts);
    case 'TailbasePaws'
        for i=1:n_frames
            for part = [Point.LeftHindLimb Point.RightHindLimb]
                TempArray(i) = TempArray(i) + sqrt((BodyPartsTracesMainX(Point.Tailbase,i)-BodyPartsTracesMainX(part,i))^2 + (BodyPartsTracesMainY(Point.Tailbase,i)-BodyPartsTracesMainY(part,i))^2);
            end
        end
        TempArraySmooth = smooth(TempArray, ceil(Options.FrameRate/2));
        Acts(5).ActArray = double(TempArraySmooth < RearsThreshold.TailbasePaws);
end
[Acts(5).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(5).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(5).ActArrayRefine = Acts(5).ActArrayRefine';

%% Acts defining by space zones

% gouged out areas of objects 1
Zones(end+1).name = 'Object1Ring';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(5).maskfilled-Zones(4).maskfilled;

Zones(end+1).name = 'Object1NoHole';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(5).maskfilled-Zones(7).maskfilled;

Zones(end+1).name = 'Object1NoHoleS';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(4).maskfilled-Zones(7).maskfilled;

% gouged out areas of objects 2
Zones(end+1).name = 'Object2Ring';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(11).maskfilled-Zones(10).maskfilled;

Zones(end+1).name = 'Object2NoHole';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(11).maskfilled-Zones(13).maskfilled;

Zones(end+1).name = 'Object2NoHoleS';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(10).maskfilled-Zones(13).maskfilled;

% sum of objects areas
Zones(end+1).name = 'Areas';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(5).maskfilled+Zones(11).maskfilled;

Zones(end+1).name = 'Objects';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(4).maskfilled+Zones(10).maskfilled;

Zones(end+1).name = 'Holes';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(7).maskfilled+Zones(13).maskfilled;

% sum of gouged out objects areas
Zones(end+1).name = 'ObjectsRing';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(64).maskfilled+Zones(67).maskfilled;

Zones(end+1).name = 'ObjectsNoHole';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(65).maskfilled+Zones(68).maskfilled;

Zones(end+1).name = 'ObjectsNoHoleS';
Zones(end).type = 'area';
Zones(end).maskfilled = Zones(66).maskfilled+Zones(69).maskfilled;
% imshow(Zones(end).maskfilled)

ZonesOption.NameZone = {
    'Object1RealOut' 'Object1Real' 'Object1RealOut' 'Object1Real' 'Object2Real' ...
    'Object1Ring' 'Object1NoHole' 'Object1NoHoleS' ...
    'Object3RealOut' 'Object3Real' 'Object3RealOut' 'Object3Real' 'Object4Real' ...
    'Object2Ring' 'Object2NoHole' 'Object2NoHoleS' ...
    'Areas' 'Objects' 'Areas' 'Objects' 'Holes' ...
    'ObjectsRing' 'ObjectsNoHole' 'ObjectsNoHoleS' ...
    };

ZonesOption.NameBodyPart = {
    'bodycenter' 'bodycenter' 'headcenter' 'headcenter' 'headcenter' ...
    'headcenter' 'headcenter' 'headcenter' ...
    'bodycenter' 'bodycenter' 'headcenter' 'headcenter' 'headcenter' ...
    'headcenter' 'headcenter' 'headcenter' ...
    'bodycenter' 'bodycenter' 'headcenter' 'headcenter' 'headcenter' ...
    'headcenter' 'headcenter' 'headcenter' ...
    };

ZonesOption.NameAct = {
    'body_in_area1' 'body_in_object1' 'head_in_area1' 'head_in_object1' 'head_in_hole1' ...
    'interact_object1' 'interact_deep_object1' 'interact_odor1' ...
    'body_in_area2' 'body_in_object2' 'head_in_area2' 'head_in_object2' 'head_in_hole2' ...
    'interact_object2' 'interact_deep_object2' 'interact_odor2' ...
    'body_in_areas' 'body_in_objects' 'head_in_areas' 'head_in_objects' 'head_in_holes' ...
    'interact_objects' 'interact_deep_objects' 'interact_odors' ...
    };

ZonesOption.NumBodyPart = [12 12 4 4 4 4 4 4 12 12 4 4 4 4 4 4 12 12 4 4 4 4 4 4];

ZonesOption.NumZone = zeros(1,length(ZonesOption.NameZone));
for zone = 1:length(ZonesOption.NameZone)
    ZonesOption.NumZone(zone) = find(strcmp({Zones.name}, ZonesOption.NameZone{zone}));
end

for zone = 1:length(ZonesOption.NameZone)
    Acts(end+1).ActName = ZonesOption.NameAct{zone};
    Acts(end).Zone = ZonesOption.NumZone(zone);
    Acts(end).ActArray = zeros(n_frames,1);
    for i=1:n_frames
        if Zones(ZonesOption.NumZone(zone)).maskfilled(round(BodyPartsTracesMainY(ZonesOption.NumBodyPart(zone),i)), round(BodyPartsTracesMainX(ZonesOption.NumBodyPart(zone),i)/Options.x_kcorr))
            Acts(end).ActArray(i,1) = 1;
        end
    end
    [Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
    Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
end

% short and long head_in_hole1
FeedingThresholdInFrames = FeedingThresholdInseconds*Options.FrameRate;
Acts(end+1).ActName = 'head_in_hole1_long';
[Acts(end).ActArray,~,~,~,~,~] = RefineLine(Acts(10).ActArrayRefine, FeedingThresholdInFrames, 0);
Acts(end).ActArray = Acts(end).ActArray';
Acts(end).ActArrayRefine = Acts(end).ActArray;
Acts(end).Zone = 7;

Acts(end+1).ActName = 'head_in_hole1_short';
Acts(end).ActArray = Acts(10).ActArrayRefine - Acts(end-1).ActArrayRefine;
Acts(end).ActArrayRefine = Acts(end).ActArray;
Acts(end).Zone = 7;

% short and long head_in_hole2
FeedingThresholdInFrames = FeedingThresholdInseconds*Options.FrameRate;
Acts(end+1).ActName = 'head_in_hole2_long';
[Acts(end).ActArray,~,~,~,~,~] = RefineLine(Acts(18).ActArrayRefine, FeedingThresholdInFrames, 0);
Acts(end).ActArray = Acts(end).ActArray';
Acts(end).ActArrayRefine = Acts(end).ActArray;
Acts(end).Zone = 13;

Acts(end+1).ActName = 'head_in_hole2_short';
Acts(end).ActArray = Acts(18).ActArrayRefine - Acts(end-1).ActArrayRefine;
Acts(end).ActArrayRefine = Acts(end).ActArray;
Acts(end).Zone = 13;

% short and long head_in_holes
FeedingThresholdInFrames = FeedingThresholdInseconds*Options.FrameRate;
Acts(end+1).ActName = 'head_in_holes_long';
[Acts(end).ActArray,~,~,~,~,~] = RefineLine(Acts(26).ActArrayRefine, FeedingThresholdInFrames, 0);
Acts(end).ActArray = Acts(end).ActArray';
Acts(end).ActArrayRefine = Acts(end).ActArray;
Acts(end).Zone = 72;

Acts(end+1).ActName = 'head_in_holes_short';
Acts(end).ActArray = Acts(26).ActArrayRefine - Acts(end-1).ActArrayRefine;
Acts(end).ActArrayRefine = Acts(end).ActArray;
Acts(end).Zone = 72;

% distance to center of object 1
Point.HeadCenter = find(strcmp(BodyPartsNames, "headcenter"),1);
TempMask = single(~Zones(strcmp({Zones.name}, 'Object2Real')).maskfilled);
TempMask = bwdist(TempMask);
[~, linearIndex] = max(TempMask(:));
[Point.Object1.CenterY, Point.Object1.CenterX] = ind2sub(size(TempMask), linearIndex);
TempArray = zeros(n_frames,1);
for i=1:n_frames
    TempArray(i) = TempArray(i) + sqrt((Point.Object1.CenterX*Options.x_kcorr-BodyPartsTracesMainX(Point.HeadCenter,i))^2 + (Point.Object1.CenterY-BodyPartsTracesMainY(Point.HeadCenter,i))^2);
end
distance_object1 = smooth(TempArray, ceil(Options.FrameRate/2));

% distance to center of object 2
Point.HeadCenter = find(strcmp(BodyPartsNames, "headcenter"),1);
TempMask = single(~Zones(strcmp({Zones.name}, 'Object4Real')).maskfilled);
TempMask = bwdist(TempMask);
[~, linearIndex] = max(TempMask(:));
[Point.Object2.CenterY, Point.Object2.CenterX] = ind2sub(size(TempMask), linearIndex);
TempArray = zeros(n_frames,1);
for i=1:n_frames
    TempArray(i) = TempArray(i) + sqrt((Point.Object2.CenterX*Options.x_kcorr-BodyPartsTracesMainX(Point.HeadCenter,i))^2 + (Point.Object2.CenterY-BodyPartsTracesMainY(Point.HeadCenter,i))^2);
end
distance_object2 = smooth(TempArray, ceil(Options.FrameRate/2));

% correct headdirection
CenterHead.X = BodyPartsTracesMainX(Point.HeadCenter,:);
CenterHead.Y = BodyPartsTracesMainY(Point.HeadCenter,:);
[HeadDirection,~] = cart2pol(BodyPartsTracesMainX(Point.Nose,:)-CenterHead.X,BodyPartsTracesMainY(Point.Nose,:)-CenterHead.Y);
HeadDirection = smooth(HeadDirection,Options.FrameRate,'sgolay',DegreeSmoothSGolay)';

% calculation coordinate features during locomotion
xlocomotion = MouseCenterX'.*Acts(3).ActArrayRefine;
ylocomotion = MouseCenterY'.*Acts(3).ActArrayRefine;
xlocomotion(xlocomotion == 0) = NaN;
ylocomotion(ylocomotion == 0) = NaN;
    
% ToDo Bowl features
%     'mouse_in_area1' 'mouse_interact_object1' 'mouse_in_object1' ...
%     'mouse_in_area2' 'mouse_interact_object2' 'mouse_in_object2' ...
%     'mouse_in_areas' 'mouse_interact_objects' 'mouse_in_objects' ...
        
%% act's statistics

for line = 1:size(Acts,2)
    [~, Acts(line).ActNumber, Acts(line).ActPercent, Acts(line).ActDistr,~,~] = RefineLine(Acts(line).ActArrayRefine, 0,0);
    Acts(line).ActPercent = round(Acts(line).ActPercent/n_frames*100,2);
    Acts(line).ActMeanTime = round(mean(Acts(line).ActDistr),2)/Options.FrameRate;
    Acts(line).ActMeanSTDTime = round(std(Acts(line).ActDistr),2)/Options.FrameRate;
    Acts(line).ActMedianTime = round(median(Acts(line).ActDistr),2)/Options.FrameRate;
    Acts(line).ActMedianMADTime = round(mad(Acts(line).ActDistr),2)/Options.FrameRate;
    Acts(line).Distance = round(mean(BodyPartsTraces(Point.Center).VelocitySmoothed(logical(Acts(line).ActArrayRefine)))*time(end)*Acts(line).ActPercent/10000,2);
    Acts(line).ActMeanDistance = Acts(line).Distance/Acts(line).ActNumber;
    histogram(Acts(line).ActDistr./Options.FrameRate, ceil(sqrt(length(Acts(line).ActDistr))+1));
    title(sprintf('Histogram of acts duration time: %s', strrep(string(Acts(line).ActName), '_', '\_')));
    saveas(gcf, sprintf('%s\\ActsHistogram\\%s_act_%s.png', PathOut,Filename,string(Acts(line).ActName)));
    delete(gcf);
end

h=figure;
plot(time, Velocity, 'k'); hold on;
plot(time, Acts(1).ActArrayRefine, 'r'); hold on;
plot(time, Acts(2).ActArrayRefine*2, 'g'); hold on;
plot(time, Acts(3).ActArrayRefine*3, 'b'); hold on;
plot(time, Acts(4).ActArrayRefine*4, 'c'); hold on;
plot(time, Acts(5).ActArrayRefine*5, 'm'); hold on;
legend(['Speed' {Acts(1:3).ActName} 'Freezing' 'Rear']);
title('Acts division by speed');
xlabel('Time, s');
ylabel('Speed, cm/s');
saveas(h, sprintf('%s\\%s_acts.fig', PathOut,Filename));
delete(h);

h = figure('Position', Screensize);
imshow(Options.GoodVideoFrame, 'InitialMag', 'fit');hold on;
plot(BodyPartsTracesMainX(Point.Center,logical(Acts(3).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(3).ActArrayRefine)), 'b.');
plot(BodyPartsTracesMainX(Point.Center,logical(Acts(2).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(2).ActArrayRefine)), 'g.');
plot(BodyPartsTracesMainX(Point.Center,logical(Acts(1).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(1).ActArrayRefine)), 'r.');
plot(BodyPartsTracesMainX(Point.Center,logical(Acts(4).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(4).ActArrayRefine)), 'k.');
plot(BodyPartsTracesMainX(Point.Center,logical(Acts(5).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(5).ActArrayRefine)), 'm.');
legend('Locomotion','Walk','Rest','Freezing', 'Rear');
saveas(h, sprintf('%s\\%s_track_with_acts.png', PathOut, Filename));
delete(h);

save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% make separate acts videos

MaxPoints = 1000;
% for act = 1:size(Acts,2)
% for act = 30:35
for act = [10 18]
    fprintf('Plotting video %d/%d. Act: %s\n', act, size(Acts,2), string(Acts(act).ActName));
    v = VideoWriter(sprintf('%s\\ActsVideo\\%s_act_%s',PathOut, Filename, string(Acts(act).ActName)),'MPEG-4');
    v.FrameRate = Options.FrameRate;
    open(v);
    h = waitbar(1/n_frames, sprintf('Plotting video, frame %d of %d', 0,  n_frames));
    
    videoframes = find(Acts(act).ActArrayRefine');
    videoframesMax = min(length(videoframes),MaxPoints);
    
    for k = videoframes(1:videoframesMax)
        if ~mod(k,10)
            h = waitbar(k/n_frames, h, sprintf('Plotting video, frame %d of %d', k,  n_frames));
        end
        if isempty(Acts(act).Zone)
            RealFrame = read(readerobj,k+StartTime-1);
        else
            RealFrame = round((Zones(Acts(act).Zone).maskfilled*255 + single(read(readerobj,k+StartTime-1)))./2);
        end
        
        % points of bodyparts in a fixed frame of reference
        for part=1:length(BodyPartsNames)
            RealFrame = insertShape(RealFrame,'circle', [BodyPartsTraces(part).TraceOriginal.X(k)/Options.x_kcorr BodyPartsTraces(part).TraceOriginal.Y(k) MarkSize*2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            RealFrame = insertShape(RealFrame,'filledcircle', [BodyPartsTracesMainX(part,k)/Options.x_kcorr BodyPartsTracesMainY(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end
        
        % radial velocities of bodyparts in a moving frame of reference
        %         for part=1:length(BodyPartsNames)
        %             if part == Point.Tailbase
        %                 IM = insertShape(IM, 'Line', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) BodyPartsX_polar(part,k)+BodyPartsVRX_polar(part,k) BodyPartsY_polar(part,k)+BodyPartsVRY_polar(part,k)], 'LineWidth', 4, 'Color', 'red');
        %             else
        %                 IM = insertShape(IM, 'Line', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) BodyPartsX_polar(part,k)+BodyPartsVRX_polar(part,k) BodyPartsY_polar(part,k)+BodyPartsVRY_polar(part,k)], 'LineWidth', 2, 'Color', 'red');
        %             end
        %         end
        
        %         % angular velocities of bodyparts in a moving frame of reference
        %         for part=1:length(BodyPartsNames)-2
        %             IM = insertShape(IM, 'Line', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) BodyPartsX_polar(part,k)+BodyPartsVTHX_polar(part,k) BodyPartsY_polar(part,k)+BodyPartsVTHY_polar(part,k)], 'LineWidth', 2, 'Color', 'yellow');
        %         end
        
        %         imshow(uint8(RealFrame));
        writeVideo(v,uint8(RealFrame));
    end
    close(v);
    delete(h);
end

%% creating outputs table of features

Features.Name = {'x', 'y', 'x_locomotion', 'y_locomotion', 'speed', 'bodydirection', 'headdirection','distance_object1','distance_object2'};
for act = 1:length(Acts)
    Features.Name{end+1} = Acts(act).ActName;
end
Features.Data(1:n_frames,1) = MouseCenterX';
Features.Data(1:n_frames,2) = MouseCenterY';
Features.Data(1:n_frames,3) = xlocomotion;
Features.Data(1:n_frames,4) = ylocomotion;
Features.Data(1:n_frames,5) = Velocity;
Features.Data(1:n_frames,6) = AngleRot';
Features.Data(1:n_frames,7) = HeadDirection';
Features.Data(1:n_frames,8) = distance_object1;
Features.Data(1:n_frames,9) = distance_object2;

for act=1:length(Acts)
    Features.Data(1:n_frames,end+1) = Acts(act).ActArrayRefine;
end

Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);

writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, Filename));
save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

end
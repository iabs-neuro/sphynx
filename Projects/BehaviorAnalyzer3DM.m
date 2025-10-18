function [Acts, BodyPartsTraces, Point, Options, session] = BehaviorAnalyzer3DM(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut,StartTime, EndTime, PathPreset, FilenamePreset)
% VVP. GAR. Deep Behavior analyses tool
% 27.03.25 2DM OF experiment

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

% Parameters description and defining

TraceOption = 'Smoothed';               % {'Original' 'Interpolated' 'Smoothed'} mode for timeseries processing Track2Acts
FreezingMode = 'HeadAndCenter';         % {'AllBodyParts' 'NoseAndCenter' 'HeadAndcenter'}  mode for act freezing calculation
RearMode = 'TailbasePaws';              % {'TailbasePaws' 'AllBodyParts'} mode for act rear calculation
RearsThreshold.AllBodyParts = 170;      % threshold for rears definition, mode 'AllBodyParts'
RearsThreshold.TailbasePawscm = 3.6;    % threshold for rears definition, mode 'TailbasePaws' (may be 2.3 is better)
DegreeDerivatives = 3;                  % how many derivatives of coordinates are needed
DegreeSmoothSGolayDefault = 3;          % length of window for smoothing
BodyPartsCenterNames = {'mass centre' 'mass center' 'bodycenter' 'center'};
BodyPartsTailbaseNames = {'tailbase' 'Tailbase' 'Tail base' 'tail base'};
tunnel_window_size = 1;                 % in seconds to smooth 3DM

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
    [FilenameVideo, PathVideo]  = uigetfile('*.*','Select video file','w:\Projects\3DM\BehaviorData\2_Combined\');
    [FilenameDLC, PathDLC]  = uigetfile('*.csv','Select DLC file with body parts','w:\Projects\3DM\BehaviorData\4_DLC\');
    PathOut = uigetdir('w:\Projects\3DM\BehaviorData\5_Behavior\', 'Pick a Directory for Outputs');
    
    % loading preset file
    answer = questdlg('Do you have preset file?', 'Uploading files', 'Yes','No','Yes');
    switch answer
        case 'Yes'
            [FilenamePreset, PathPreset]  = uigetfile('*.mat','Select preset file','w:\Projects\3DM\BehaviorData\3_Preset\');
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
load(sprintf('%s//%s', PathPreset, FilenamePreset), 'Options', 'Zones', 'tunnels');

Options.MiddleCenterCm = 20;
Options.StatusBodyPartThreshold = 98;                                   % threshold for missing bodyparts
Options.LikelihoodThreshold = 0.6;
Options.VelocityMax = 50;                                               % threshold for maxima velocity

% reading video file
readerobj = VideoReader(sprintf('%s%s', PathVideo, FilenameVideo));

Options.FrameRate = readerobj.FrameRate;

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
    case {'3DM','BowlsOpenField','Novelty OF','Holes Track','Odor Track','Freezing Track','New Track','Complex Context','NOL','OF_Obj'}
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

n_frames = EndTime-StartTime+1;                                 % number of frames for pure experiment
time = (1:n_frames)/Options.FrameRate;
frames = linspace(1, n_frames, n_frames);

save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

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
    
    TempArrayX(TempArrayX>Options.Width*Options.x_kcorr) = 0;
    TempArrayY(TempArrayY>Options.Height) = 0;
    
    TempArrayX(TempArrayX<0) = 0;
    TempArrayY(TempArrayY<0) = 0;

    TempArrayX(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold) = 0;
    TempArrayY(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold) = 0;
    
    BodyPartsTraces(part).PercentNaN = mean([round(sum(isnan(BodyPartsTraces(part).TraceOriginal.X))/n_frames*100,2) round(sum(isnan(BodyPartsTraces(part).TraceOriginal.Y))/n_frames*100,2)]);
    BodyPartsTraces(part).PercentLikeliHoodSubThreshold = round(sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100,2);

    %% ToDo threshold
    if sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100 > Options.StatusBodyPartThreshold
        disp(['Bodypart ', BodyPartsTraces(part).BodyPartName, ' not found. Percent undetected timestamps: ', num2str(sum(BodyPartsTraces(part).TraceLikelihood < Options.LikelihoodThreshold)/n_frames*100)]);
        BodyPartsTraces(part).Status = 'NotFound';
        continue;
    else
        BodyPartsTraces(part).Status = 'Good';
    end

    TempArrayInt.X = interp1(frames(TempArrayX ~=0), TempArrayX(TempArrayX ~=0), find(TempArrayX == 0), 'pchip', 'extrap');
    TempArrayInt.Y = interp1(frames(TempArrayY ~=0), TempArrayY(TempArrayY ~=0), find(TempArrayY == 0), 'pchip', 'extrap');
    
    TempArrayInt.X(TempArrayInt.X<1) = 1;
    TempArrayInt.Y(TempArrayInt.Y<1) = 1;
    
    TempArrayInt.X(TempArrayInt.X>fix(Options.Width*Options.x_kcorr)) = fix(Options.Width*Options.x_kcorr);
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
%     BodyPartsTraces(part).TraceSmoothed.X = smooth(BodyPartsTraces(part).TraceInterpolated.X,SmoothWindow,'rloess');
%     BodyPartsTraces(part).TraceSmoothed.Y = smooth(BodyPartsTraces(part).TraceInterpolated.Y,SmoothWindow,'rloess');    
    
    
    BodyPartsTraces(part).TraceSmoothed.X(BodyPartsTraces(part).TraceSmoothed.X<1) = 1;
    BodyPartsTraces(part).TraceSmoothed.Y(BodyPartsTraces(part).TraceSmoothed.Y<1) = 1;
    
    BodyPartsTraces(part).TraceSmoothed.X(BodyPartsTraces(part).TraceSmoothed.X>fix(Options.Width*Options.x_kcorr)) = fix(Options.Width*Options.x_kcorr);
    BodyPartsTraces(part).TraceSmoothed.Y(BodyPartsTraces(part).TraceSmoothed.Y>Options.Height) = Options.Height;
    
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

points_for_delete = find(strcmp({BodyPartsTraces.Status}, 'NotFound'));
BodyPartsNames(points_for_delete) = [];
BodyPartsOptions(points_for_delete) = [];
BodyPartsTracesMainX(points_for_delete,:) = [];
BodyPartsTracesMainY(points_for_delete,:) = [];
BodyPartsTraces(points_for_delete) = [];
BodyPartsNumber = length(BodyPartsNames);

% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% 3DM experiment specific calculations

% searching all bodyparts
Point = find_bodyPart(BodyPartsNames);

% add bottom and start zones in tunnels structure
tunnels.count = length(tunnels.mask);
tunnels.mask{tunnels.count+2} = Zones(7).maskfilled;
for tunnel = 1:tunnels.count
    tunnels.mask{tunnels.count+2-tunnel} = tunnels.mask{tunnels.count+1-tunnel};
end
tunnels.mask{1} = Zones(4).maskfilled;
tunnels.zscored = [1 tunnels.zscored];
tunnels.binarized = [0 tunnels.binarized];
tunnels.discreted = [0 tunnels.discreted];
tunnels.count = length(tunnels.mask);

tunnels.act = zeros(1,n_frames);

% create start queue
start_tunnel = [];
for frame = 1:500
%     tunnel_this_frame = [];
    for tunnel = 1:tunnels.count
        if tunnels.mask{tunnel, 1}(round(BodyPartsTracesMainY(Point.Center,frame)), round(BodyPartsTracesMainX(Point.Center,frame)/Options.x_kcorr))
            start_tunnel = [start_tunnel tunnel];
        end
    end    
end

histogram(start_tunnel,'BinMethod','integer');
saveas(gcf, sprintf('%s\\%s_Start_point.png', PathOut, Filename));
delete(gcf);

[unique_values, ~, ~] = unique(start_tunnel);
% counts = accumarray(ic, 1);

% [~, max_idx] = max(counts);
% most_frequent = unique_values(max_idx);

% if any(ismember(unique_values,2))
%     most_frequent = 2;
% elseif  any(ismember(unique_values,3))
%     most_frequent = 3;
% elseif  any(ismember(unique_values,4))
%     most_frequent = 4;
% elseif  any(ismember(unique_values,5))
%     most_frequent = 5;
% elseif  any(ismember(unique_values,6))
%     most_frequent = 6;
% else
%     most_frequent = [];
% end

most_frequent = find(ismember(2:32, unique_values), 1, 'first');
if isempty(most_frequent)
    most_frequent = [];
else
    most_frequent = most_frequent + 1; % так как ищем начиная с 2
end

if isempty(most_frequent)
    fprintf('Стартовый рукав: %d\n', 1);
    queue = [0,0,1,2,2];
else
    fprintf('Стартовый рукав: %d\n', most_frequent);
    queue = [most_frequent-2, most_frequent-1,most_frequent,most_frequent+1, most_frequent+2];
end

for frame = 1:n_frames  
    tunnel_this_frame = [];
    for tunnel = 1:tunnels.count
        if tunnels.mask{tunnel, 1}(round(BodyPartsTracesMainY(Point.Center,frame)), round(BodyPartsTracesMainX(Point.Center,frame)/Options.x_kcorr))
            tunnel_this_frame = [tunnel_this_frame tunnel];
        end
    end
    if ~isempty(tunnel_this_frame)
        
        tunnel_this_frame_real = intersect(queue, tunnel_this_frame);
        if isempty(tunnel_this_frame_real)
            tunnels.act(frame) = queue(3);
        else
            tunnels.act(frame) = min(tunnel_this_frame_real);
        end
        queue = [tunnels.act(frame)-2,tunnels.act(frame)-1,tunnels.act(frame),tunnels.act(frame)+1,tunnels.act(frame)+2];
        
    else
        tunnels.act(frame) = queue(3);
    end
end
tunnels.act_refined = round(medfilt1(tunnels.act, round(Options.FrameRate*tunnel_window_size), 'truncate'));
tunnels.act_refined = max(1, min(32, tunnels.act_refined));

% plot arms indexes
h = figure('Position', Screensize);
set(gcf, 'DefaultAxesFontSize', 14); % Увеличиваем шрифт осей и текста

% Рисуем основные графики с увеличенной толщиной линий (LineWidth=2)
plot(time, tunnels.act, 'b', 'LineWidth', 2); hold on;
plot(time, tunnels.act_refined, 'g', 'LineWidth', 2); hold on;

% Горизонтальные линии (толщина LineWidth=1.5)
plot([min(time) max(time)], [32 32], '--r', 'LineWidth', 1.5); hold on;
text(min(time), 32, ' нижняя площадка', 'VerticalAlignment', 'bottom', 'FontSize', 12); hold on;

plot([min(time) max(time)], [1 1], '--r', 'LineWidth', 1.5); hold on;
text(min(time), 1, ' стартовая площадка', 'VerticalAlignment', 'bottom', 'FontSize', 12);

% Легенда, заголовок и подписи осей с увеличенным шрифтом
legend('ORIGINAL', 'SMOOTHED 3s', 'FontSize', 12);
title(sprintf('3DMaze. %s. Tracking mouse in arm indices', strrep(Filename, '_', '\_')), 'FontSize', 16);
xlabel('Time, s', 'FontSize', 20);
ylabel('Position, indx', 'FontSize', 20);

% Сохраняем и закрываем
saveas(h, sprintf('%s\\%s_Track_arms.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Track_arms.fig', PathOut, Filename));
delete(h);

%% calculate z-coordinate and (x,y) in cm

% total time in seconds in 3DMaze (whithout start zone)
session.duration = (n_frames - length(find(tunnels.act_refined == 1)))/Options.FrameRate;
session.duration_total = n_frames/Options.FrameRate;

tunnels.length.X(1) = 0;
tunnels.length.Y(1) = 0;
tunnels.length.Z(1) = 0;
for corner = 2:tunnels.count-1
    tunnels.length.X(corner) = abs(tunnels.corner3D(corner,1) - tunnels.corner3D(corner-1,1));   
    tunnels.length.Y(corner) = abs(tunnels.corner3D(corner,2) - tunnels.corner3D(corner-1,2));
    tunnels.length.Z(corner) = tunnels.corner3D(corner,3) - tunnels.corner3D(corner-1,3);
end
tunnels.length.X(tunnels.count) = 160;
tunnels.length.Y(tunnels.count) = 160;
tunnels.length.Z(tunnels.count) = 0;

MouseCenterX = zeros(1, n_frames);
MouseCenterY = zeros(1, n_frames);
MouseCenterZ = zeros(1, n_frames);

for frame = 1:n_frames
    if tunnels.act_refined(frame) == 1
        MouseCenterX(frame) = tunnels.corner3D(1,1);
        MouseCenterY(frame) = tunnels.corner3D(1,2);
        MouseCenterZ(frame) = tunnels.corner3D(1,3);
    elseif tunnels.act_refined(frame) == 32
        MouseCenterX(frame) = tunnels.corner3D(31,1) + (BodyPartsTracesMainX(Point.Center,frame)-tunnels.corner(end,1)+20)/abs((tunnels.corner(29,1)-tunnels.corner(31,1)+40))*160;
        MouseCenterY(frame) = tunnels.corner3D(31,2) + (BodyPartsTracesMainY(Point.Center,frame)-tunnels.corner(end,2)-20)/abs((tunnels.corner(30,2)-tunnels.corner(31,2)))*160;
        MouseCenterZ(frame) = 0;
    else
        
        this_tunnel = tunnels.act_refined(frame)-1;
        
        if tunnels.length.X(this_tunnel+1) == 0                 % vertical arm
            MouseCenterX(frame) = tunnels.corner3D(this_tunnel,1);
            MouseCenterY(frame) = tunnels.corner3D(this_tunnel,2) + (BodyPartsTracesMainY(Point.Center,frame)-tunnels.corner(this_tunnel,2))/abs((tunnels.corner(this_tunnel+1,2)-tunnels.corner(this_tunnel,2)))*tunnels.length.Y(this_tunnel+1);
        end
        
        if tunnels.length.Y(this_tunnel+1) == 0                 % horisontal arm
            MouseCenterX(frame) = tunnels.corner3D(this_tunnel,1) + (BodyPartsTracesMainX(Point.Center,frame)-tunnels.corner(this_tunnel,1))/abs((tunnels.corner(this_tunnel+1,1)-tunnels.corner(this_tunnel,1)))*tunnels.length.X(this_tunnel+1);
            MouseCenterY(frame) = tunnels.corner3D(this_tunnel,2);
        end
        
        if tunnels.length.Z(this_tunnel+1) == 0                % z straight arm
            MouseCenterZ(frame) = tunnels.corner3D(this_tunnel,3);
        elseif tunnels.length.Y(this_tunnel+1) == 0            % horisontal arm
            MouseCenterZ(frame) = tunnels.corner3D(this_tunnel,3) + (abs(BodyPartsTracesMainX(Point.Center,frame)-tunnels.corner(this_tunnel,1)))/abs((tunnels.corner(this_tunnel+1,1)-tunnels.corner(this_tunnel,1)))*tunnels.length.Z(this_tunnel+1);
        else                                                   % vertical arm
            MouseCenterZ(frame) = tunnels.corner3D(this_tunnel,3) + (abs(BodyPartsTracesMainY(Point.Center,frame)-tunnels.corner(this_tunnel,2)))/abs((tunnels.corner(this_tunnel+1,2)-tunnels.corner(this_tunnel,2)))*tunnels.length.Z(this_tunnel+1);
        end
        
    end
    
end

% [Velocity, session.mean_velocity, session.total_distance, session.total_height_up, session.total_height_down, session.total_height] = analyze_movement_3D(MouseCenterX/10, MouseCenterY/10, MouseCenterZ/10, time, Options.SmoothWindowBigInFrames);
% nonvalid =  Velocity > Options.VelocityMax;
% 
% Velocity = smooth(Velocity,Options.SmoothWindowBigInFrames,'sgolay',3);
% Velocity = max(0, min(Options.VelocityMax, Velocity));
% 
% TempArrayX = MouseCenterX;
% TempArrayY = MouseCenterY;
% TempArrayZ = MouseCenterZ;
%     
% TempArrayX(nonvalid) = -1;
% TempArrayY(nonvalid) = -1;
% TempArrayZ(nonvalid) = -1;
% 
% TempArrayInt.MouseCenterX = interp1(frames(TempArrayX ~=-1), TempArrayX(TempArrayX ~=-1), find(TempArrayX == -1), 'pchip', 'extrap');
% TempArrayInt.MouseCenterY = interp1(frames(TempArrayY ~=-1), TempArrayY(TempArrayY ~=-1), find(TempArrayY == -1), 'pchip', 'extrap');
% TempArrayInt.MouseCenterZ = interp1(frames(TempArrayZ ~=-1), TempArrayZ(TempArrayZ ~=-1), find(TempArrayZ == -1), 'pchip', 'extrap');
% 
% TempArrayX(TempArrayX == -1) = TempArrayInt.X;
% TempArrayY(TempArrayY == -1) = TempArrayInt.Y;
% TempArrayZ(TempArrayZ == -1) = TempArrayInt.Z;
% 
% MouseCenterX = TempArrayX;
% MouseCenterY = TempArrayY;
% MouseCenterZ = TempArrayZ;
    
% prepairing coordinates
MouseCenterX(MouseCenterX<min(tunnels.corner3D(:,1))) = min(tunnels.corner3D(:,1));
MouseCenterY(MouseCenterY<min(tunnels.corner3D(:,2))) = min(tunnels.corner3D(:,2));
MouseCenterZ(MouseCenterZ<min(tunnels.corner3D(:,3))) = min(tunnels.corner3D(:,3));
    
MouseCenterX(MouseCenterX>max(tunnels.corner3D(:,1))) = max(tunnels.corner3D(:,1));
MouseCenterY(MouseCenterY>max(tunnels.corner3D(:,2))) = max(tunnels.corner3D(:,2));
MouseCenterZ(MouseCenterZ>max(tunnels.corner3D(:,3))) = max(tunnels.corner3D(:,3));

% Параметры фильтра Савицкого-Голая
window_size = 51;
polynomial_order = 3;

% Применение фильтра к каждой координате
MouseCenterX_smoothed = sgolayfilt(MouseCenterX, polynomial_order, window_size);
MouseCenterY_smoothed = sgolayfilt(MouseCenterY, polynomial_order, window_size);
MouseCenterZ_smoothed = sgolayfilt(MouseCenterZ, polynomial_order, window_size);

% Наложение ограничений на значения
MouseCenterX_smoothed = max(min(tunnels.corner3D(:,1)), min(max(tunnels.corner3D(:,1)), MouseCenterX_smoothed));
MouseCenterY_smoothed = max(min(tunnels.corner3D(:,2)), min(max(tunnels.corner3D(:,2)), MouseCenterY_smoothed));
MouseCenterZ_smoothed = max(min(tunnels.corner3D(:,3)), min(max(tunnels.corner3D(:,3)), MouseCenterZ_smoothed));

% Обновление исходных переменных (если нужно)
MouseCenterX = MouseCenterX_smoothed/10;
MouseCenterY = MouseCenterY_smoothed/10;
MouseCenterZ = MouseCenterZ_smoothed/10;

% support plot (X,Y)
h = figure('Position', [300 300 1000 1000]);
set(gcf, 'DefaultAxesFontSize', 14);
plot(MouseCenterX, MouseCenterY, '.b', 'LineWidth', 2); hold on;
axis equal; 
title(sprintf('3DMaze. %s. Tracking mouse in cm, (X,Y) plane', strrep(Filename, '_', '\_')), 'FontSize', 16);
xlabel('X, cm', 'FontSize', 14);
ylabel('Y, cm', 'FontSize', 14);
saveas(h, sprintf('%s\\%s_Track_xy.png', PathOut, Filename));
delete(h);

% support plot (X,Z)
h = figure('Position', [300 300 1000 1000]);
set(gcf, 'DefaultAxesFontSize', 14);
plot(MouseCenterX, MouseCenterZ, 'b', 'LineWidth', 2); hold on;
axis equal; 
title(sprintf('3DMaze. %s. Tracking mouse in cm, (X,Z) plane', strrep(Filename, '_', '\_')), 'FontSize', 16);
xlabel('X, cm', 'FontSize', 14);
ylabel('Z, cm', 'FontSize', 14);
saveas(h, sprintf('%s\\%s_Track_xz.png', PathOut, Filename));
delete(h);

% support plot (Y,Z)
h = figure('Position', [300 300 1000 1000]);
set(gcf, 'DefaultAxesFontSize', 14);
plot(MouseCenterY, MouseCenterZ, 'b', 'LineWidth', 2); hold on;
axis equal; 
title(sprintf('3DMaze. %s. Tracking mouse in cm, (Y,Z) plane', strrep(Filename, '_', '\_')), 'FontSize', 16);
xlabel('Y, cm', 'FontSize', 14);
ylabel('Z, cm', 'FontSize', 14);
saveas(h, sprintf('%s\\%s_Track_yz.png', PathOut, Filename));
delete(h);

% support plot X
h = figure('Position', Screensize);
set(gcf, 'DefaultAxesFontSize', 20);
plot(time, MouseCenterX, 'b', 'LineWidth', 2); hold on;
title(sprintf('3DMaze. %s. Tracking mouse in cm, X coordinate', strrep(Filename, '_', '\_')), 'FontSize', 20);
xlabel('Time, s', 'FontSize', 20);
ylabel('X, cm', 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_time_x.png', PathOut, Filename));
delete(h);

% support plot Y
h = figure('Position', Screensize);
set(gcf, 'DefaultAxesFontSize', 20);
plot(time, MouseCenterY, 'b', 'LineWidth', 2); hold on;
title(sprintf('3DMaze. %s. Tracking mouse in cm, Y coordinate', strrep(Filename, '_', '\_')), 'FontSize', 20);
xlabel('Time, s', 'FontSize', 20);
ylabel('Y, cm', 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_time_y.png', PathOut, Filename));
delete(h);

% support plot Z
h = figure('Position', Screensize);
set(gcf, 'DefaultAxesFontSize', 20);
plot(time, MouseCenterZ, 'b', 'LineWidth', 2); hold on;
title(sprintf('3DMaze. %s. Tracking mouse in cm, Z coordinate', strrep(Filename, '_', '\_')), 'FontSize', 20);
xlabel('Time, s', 'FontSize', 20);
ylabel('Z, cm', 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_time_z.png', PathOut, Filename));
delete(h);

% Построение 3D-траектории
h = figure('Position', [300 300 1000 1000]);
plot3(MouseCenterX, MouseCenterY, MouseCenterZ, 'm-', 'LineWidth', 2);
xlabel('X, cm', 'FontSize', 20);
ylabel('Y, cm', 'FontSize', 20);
zlabel('Z, cm', 'FontSize', 20);
grid on;
title(sprintf('3DMaze. %s. Tracking mouse, 3D', strrep(Filename, '_', '\_')), 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_3D.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Track_3D.fig', PathOut, Filename));
delete(h);

% Построение gif-анимации
create_3d_trajectory_gif(MouseCenterX, MouseCenterY, MouseCenterZ, Filename, ...
    'GifName', sprintf('%s_Track_3D.gif', Filename), ...
    'OutputPath', PathOut, ...
    'RotationSpeed', 2, ...
    'LineColor', 'b', ...
    'LineWidth', 3, ...
    'ShowVisualization', false);

%% analyzing tracking
[Velocity, session.mean_velocity, session.total_distance, session.total_height_up, session.total_height_down, session.total_height] = analyze_movement_3D(MouseCenterX, MouseCenterY, MouseCenterZ, time, Options.SmoothWindowBigInFrames);

% Построение графика скорости
h = figure('Position', Screensize);
set(gcf, 'DefaultAxesFontSize', 20);
plot(time, Velocity, 'b', 'LineWidth', 2); hold on;
xlabel('Время, с', 'FontSize', 20);
ylabel('Скорость, см/с', 'FontSize', 20);
title(sprintf('3DM. %s. Velocity', strrep(Filename, '_', '\_')));
grid on;
saveas(h, sprintf('%s\\%s_Velocity.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Velocity.fig', PathOut, Filename));
delete(h);

% % plot velocity
% h = figure('Position', [300 300 1000 1000]);
% set(gcf, 'DefaultAxesFontSize', 14);
% % Создаем scatter plot с цветом по скорости
% scatter(MouseCenterX, MouseCenterY, 40, Velocity, 'filled', 'Marker', 'o');
% hold on;
% % Соединяем точки линиями (опционально)
% % plot(MouseCenterX, MouseCenterY, '-k', 'LineWidth', 0.5); 
% % Настройка colorbar
% colormap jet;
% c = colorbar;
% c.Label.String = 'Скорость, см/с';
% c.FontSize = 14;
% % Настройки осей
% xlabel('X, см', 'FontSize', 16);
% ylabel('Y, см', 'FontSize', 16);
% title(sprintf('3DM. %s. Track (velocity colored)',strrep(Filename, '_', '\_')), 'FontSize', 18);
% grid on;
% axis equal;
% saveas(h, sprintf('%s\\%s_Velocity_track.png', PathOut, Filename));
% saveas(h, sprintf('%s\\%s_Velocity_track.fig', PathOut, Filename));
% delete(h);

% Создаем 2D-гистограмму скорости
% bin_x = discretize(MouseCenterX', edges{1});
% bin_y = discretize(MouseCenterY', edges{2});

% 2. Создание бинов с явным контролем границ
x_edges = linspace(0, 70, 71); % 70 бинов = 71 edge
y_edges = linspace(0, 68, 69);

% 3. Альтернативный вариант discretize с включением правой границы
bin_x = discretize(MouseCenterX', x_edges, 'IncludedEdge', 'right');
bin_y = discretize(MouseCenterY', y_edges, 'IncludedEdge', 'right');

valid = (bin_x >= 0) & (bin_y >= 0);
bin_x = bin_x(valid);
bin_y = bin_y(valid);

speed_grid = accumarray([bin_x, bin_y], Velocity(valid), [70 68], @mean, NaN)';
count_grid = accumarray([bin_x, bin_y], 1, [70 68], @sum, 0)';

% Пустые бины (менее 5 точек) делаем NaN
speed_grid(count_grid < 3) = NaN;

% Визуализация
figure('Position', [300 300 1000 1000], 'Color', 'w');
set(groot, 'DefaultAxesFontSize', 18);
ax = axes('Parent', gcf);
set(ax, 'Color', 'w', 'FontSize', 18);
hold on;

h = imagesc(x_edges, y_edges, speed_grid);
colormap('jet');
set(h, 'AlphaData', ~isnan(speed_grid));

axis([-1 71 -1 71]);
axis xy;
axis equal;  % Сохраняем пропорции осей

c = colorbar;
c.Label.String = 'Скорость, см/c';
c.FontSize = 16;

xlabel('X, см', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Y, см', 'FontSize', 16, 'FontWeight', 'bold');
title(sprintf('3DM. %s. Velocity HeatMap', strrep(Filename, '_', '\_')), 'FontSize', 18, 'FontWeight', 'bold');
grid on;
set(gca, 'LineWidth', 1);
saveas(h, sprintf('%s\\%s_Velocity_track.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Velocity_track.fig', PathOut, Filename));
close(gcf);

%% kinematogramma calculation 

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

BodyPartsX_polar = BodyPartsRelativeR.*cos(BodyPartsRelativeTH+AngleDop);
BodyPartsY_polar = BodyPartsRelativeR.*sin(BodyPartsRelativeTH+AngleDop);
BodyPartsX_polar(end,:) = zeros(1, n_frames);
BodyPartsY_polar(end,:) = zeros(1, n_frames);
BodyPartsX_polar(end+1,:) = BodyPartsRelativeR(end,:).*cos(AngleDop);
BodyPartsY_polar(end+1,:) = BodyPartsRelativeR(end,:).*sin(AngleDop);
BodyPartsX_polar = BodyPartsX_polar.*VideoScale.*Options.pxl2sm + round(Options.Width/2);
BodyPartsY_polar = BodyPartsY_polar.*VideoScale.*Options.pxl2sm + round(Options.Height*2/3);

csvwrite(sprintf('%s\\%s_Kinematogramma.csv',PathOut,Filename), BodyPartsAll');
% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% make a main video

BlackFrame = uint8(zeros(Options.Height,Options.Width));
colorbase = jet(BodyPartsNumber);
if PlotOption.main
    v = VideoWriter(sprintf('%s\\%s_BodyParts',PathOut, Filename),'MPEG-4');
    v.FrameRate = Options.FrameRate;
    open(v);
    h = waitbar(1/n_frames, sprintf('Plotting video, frame %d of %d', 0,  n_frames));
    %     for k=1:n_frames
    start_frame = 1;
    duration_second = 10;
    for k=start_frame:start_frame + round(Options.FrameRate)*duration_second
        if ~mod(k,10)
            h = waitbar(k/n_frames, h, sprintf('Plotting video, frame %d of %d', k,  n_frames));
        end
        RealFrame = read(readerobj,k+StartTime-1);
        
        % points of bodyparts in a moving frame of reference
        IM(:,:,1) = BlackFrame;
        IM(:,:,2) = BlackFrame;
        IM(:,:,3) = BlackFrame;
        for part=1:length(BodyPartsNames)
            IM = insertShape(IM,'filledcircle', [BodyPartsX_polar(part,k) BodyPartsY_polar(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end
        
        % points of bodyparts in a fixed frame of reference
        for part=1:length(BodyPartsNames)
            RealFrame = insertShape(RealFrame,'circle', [BodyPartsTraces(part).TraceOriginal.X(k)/Options.x_kcorr BodyPartsTraces(part).TraceOriginal.Y(k) MarkSize*2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            RealFrame = insertShape(RealFrame,'filledcircle', [BodyPartsTracesMainX(part,k)/Options.x_kcorr BodyPartsTracesMainY(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end  
        
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

% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

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
    case 'HeadAndCenter'
        Acts(4).ActArray = double((BodyPartsTraces(Point.HeadCenter).VelocitySmoothed < Options.velocity_rest).*Acts(1).ActArrayRefine);
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
        TempArraySmooth = smooth(TempArray, round(Options.FrameRate));
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

% correct headdirection
Point.HeadCenter = find(strcmp(BodyPartsNames, "headcenter"),1);
CenterHead.X = BodyPartsTracesMainX(Point.HeadCenter,:);
CenterHead.Y = BodyPartsTracesMainY(Point.HeadCenter,:);

Point.HD = Point.MiniscopeUCLA;
if isempty(Point.HD)
    Point.HD = Point.Nose;
end

HeadDirection = [];
if ~isempty(Point.HD)
    [HeadDirection,~] = cart2pol(BodyPartsTracesMainX(Point.HD,:)-CenterHead.X,BodyPartsTracesMainY(Point.HD,:)-CenterHead.Y);
    HeadDirection = smooth(HeadDirection,round(Options.FrameRate),'sgolay',DegreeSmoothSGolay)';
end

% calculation coordinate features during locomotion
xlocomotion = MouseCenterX'.*Acts(3).ActArrayRefine;
ylocomotion = MouseCenterY'.*Acts(3).ActArrayRefine;
xlocomotion(xlocomotion == 0) = NaN;
ylocomotion(ylocomotion == 0) = NaN;


%% Task-specific Acts 

% start box
Acts(end+1).ActName = 'start_box';
Acts(end).ActArray = double(tunnels.act == 1)';
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
Acts(end).Zone = tunnels.mask{1, 1};

% all corners
Acts(end+1).ActName = 'corners';
Acts(end).ActArray = zeros(n_frames,1);
search_radius = 4;
for t = 1:length(MouseCenterX)
    mouse_pos = [MouseCenterX(t), MouseCenterY(t), MouseCenterZ(t)];
    distances = sqrt(sum((tunnels.corner3D./10 - mouse_pos).^2, 2));    
    if any(distances < search_radius)
        Acts(end).ActArray(t) = 1;
    end
end
Acts(end).ActArray = Acts(end).ActArray - Acts(6).ActArrayRefine;
Acts(end).ActArray(Acts(end).ActArray < 0) = 0;
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

h = figure('Position', [300 300 1000 1000]);
set(gcf, 'DefaultAxesFontSize', 34);
plot(MouseCenterX, MouseCenterY, '.g', 'LineWidth', 2); hold on;
plot(MouseCenterX(logical(Acts(end).ActArray)), MouseCenterY(logical(Acts(end).ActArray)), '.r', 'LineWidth', 2);
axis equal; 
title(sprintf('3DMaze. %s. Tracking mouse. Corners zones', strrep(Filename, '_', '\_')), 'FontSize', 16);
xlabel('X, cm', 'FontSize', 14);
ylabel('Y, cm', 'FontSize', 14);
saveas(h, sprintf('%s\\%s_Track_corners.png', PathOut, Filename));
delete(h);

% all arms
Acts(end+1).ActName = 'arms';
Acts(end).ActArray = ones(n_frames,1);
Acts(end).ActArray = Acts(end).ActArray - Acts(6).ActArrayRefine - Acts(7).ActArrayRefine;
Acts(end).ActArray(Acts(end).ActArray < 0) = 0;
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

% вычесть стартовый бокс из актов по скорости и углов с коридорами
for act = [1:5]
    Acts(act).ActArray = Acts(act).ActArrayRefine - Acts(6).ActArrayRefine;
    Acts(act).ActArray(Acts(act).ActArray < 0) = 0;
    [Acts(act).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(act).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
    Acts(act).ActArrayRefine = Acts(act).ActArrayRefine';
end

% stright and sloping arms
Acts(end+1).ActName = 'straight_arms';
target_indices = find(tunnels.binarized == 0);
Acts(end).ActArray = double(ismember(tunnels.act, target_indices))';
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
summed_mask = zeros(size(tunnels.mask{target_indices(1), 1}));
for i = 1:length(target_indices)
    summed_mask = summed_mask + tunnels.mask{target_indices(i), 1};
end
summed_mask(summed_mask>1) = 1;
Acts(end).Zone = summed_mask;

% Построение 3D-траектории прямых и наклонных рукавов
h = figure('Position', [300 300 1000 1000]);
plot3(MouseCenterX, MouseCenterY, MouseCenterZ, '.m', 'LineWidth', 2); hold on;
plot3(MouseCenterX(find(Acts(end).ActArrayRefine)), MouseCenterY(find(Acts(end).ActArrayRefine)), MouseCenterZ(find(Acts(end).ActArrayRefine)), '.g', 'LineWidth', 2);
legend('SLOPING ARMS', 'STRAIGHT ARMS', 'FontSize', 12);
xlabel('X, cm', 'FontSize', 20);
ylabel('Y, cm', 'FontSize', 20);
zlabel('Z, cm', 'FontSize', 20);
grid on;
title(sprintf('3DMaze. %s. Tracking mouse, 3D. Straight arms', strrep(Filename, '_', '\_')), 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_3D_Straight_Arms.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Track_3D_Straight_Arms.fig', PathOut, Filename));
delete(h);

% sloping arms
Acts(end+1).ActName = 'sloping_arms';
target_indices = find(tunnels.binarized == 1);
Acts(end).ActArray = double(ismember(tunnels.act, target_indices))';
Acts(end).ActArrayRefine = Acts(end).ActArray;
summed_mask = zeros(size(tunnels.mask{target_indices(1), 1}));
for i = 1:length(target_indices)
    summed_mask = summed_mask + tunnels.mask{target_indices(i), 1};
end
summed_mask(summed_mask>1) = 1;
Acts(end).Zone = summed_mask;

% slop down arms
Acts(end+1).ActName = 'slope_down_arms';
target_indices = find(tunnels.discreted == -1);
Acts(end).ActArray = double(ismember(tunnels.act, target_indices))';
Acts(end).ActArrayRefine = Acts(end).ActArray;
summed_mask = zeros(size(tunnels.mask{target_indices(1), 1}));
for i = 1:length(target_indices)
    summed_mask = summed_mask + tunnels.mask{target_indices(i), 1};
end
summed_mask(summed_mask>1) = 1;
Acts(end).Zone = summed_mask;

% slop up arms
Acts(end+1).ActName = 'slope_up_arms';
target_indices = find(tunnels.discreted == 1);
Acts(end).ActArray = double(ismember(tunnels.act, target_indices))';
Acts(end).ActArrayRefine = Acts(end).ActArray;
summed_mask = zeros(size(tunnels.mask{target_indices(1), 1}));
for i = 1:length(target_indices)
    summed_mask = summed_mask + tunnels.mask{target_indices(i), 1};
end
summed_mask(summed_mask>1) = 1;
Acts(end).Zone = summed_mask;

% Построение 3D-траектории прямых и наклонных вверх-вниз рукавов
h = figure('Position', [300 300 1000 1000]);
plot3(MouseCenterX, MouseCenterY, MouseCenterZ, '.m', 'LineWidth', 2); hold on;
plot3(MouseCenterX(find(Acts(end).ActArrayRefine)), MouseCenterY(find(Acts(end).ActArrayRefine)), MouseCenterZ(find(Acts(end).ActArrayRefine)), '.b', 'LineWidth', 2); hold on;
plot3(MouseCenterX(find(Acts(end-1).ActArrayRefine)), MouseCenterY(find(Acts(end-1).ActArrayRefine)), MouseCenterZ(find(Acts(end-1).ActArrayRefine)), '.g', 'LineWidth', 2);
legend('STRAIGHT ARMS', 'SLOPING UP ARMS', 'SLOPING DOWN ARMS', 'FontSize', 12);
xlabel('X, cm', 'FontSize', 20);
ylabel('Y, cm', 'FontSize', 20);
zlabel('Z, cm', 'FontSize', 20);
grid on;
title(sprintf('3DMaze. %s. Tracking mouse, 3D. Sloping arms', strrep(Filename, '_', '\_')), 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_3D_Sloping_Arms.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Track_3D_Sloping_Arms.fig', PathOut, Filename));
delete(h);

% equal_height arms
[arm_indices, ~, ~] = unique(tunnels.zscored);
h = figure('Position', [300 300 1000 1000]);
for arm_ind = 1:length(arm_indices)
    
    target_indices = find(tunnels.zscored == arm_indices(arm_ind));
    
    Acts(end+1).ActName = sprintf('z_arm_%d', arm_ind);
    Acts(end).ActArray = double(ismember(tunnels.act, target_indices))';
    Acts(end).ActArrayRefine = Acts(end).ActArray;
    summed_mask = zeros(size(tunnels.mask{target_indices(1), 1}));
    for i = 1:length(target_indices)
        summed_mask = summed_mask + tunnels.mask{target_indices(i), 1};
    end
    summed_mask(summed_mask>1) = 1;
    Acts(end).Zone = summed_mask;

    plot3(MouseCenterX(find(Acts(end).ActArrayRefine)), MouseCenterY(find(Acts(end).ActArrayRefine)), MouseCenterZ(find(Acts(end).ActArrayRefine)), '.', 'LineWidth', 2); hold on;
end
title(sprintf('3DMaze. %s. Tracking mouse, 3D. Equal arms', strrep(Filename, '_', '\_')), 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_3D_Equal_Arms.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Track_3D_Equal_Arms.fig', PathOut, Filename));
delete(h); 
    

% velocity acts (rest, walk, locomotion) in zones acts
for act = [9:12]
%     if ~isempty(Acts(act).Zone)
        Acts(end+1).ActName = ['rest_in_' Acts(act).ActName];
        Acts(end).ActArray = Acts(strcmp({Acts.ActName}, 'rest')).ActArrayRefine.*Acts(act).ActArrayRefine;
        [Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
        Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
        Acts(end).Zone = Acts(act).Zone;
        
        Acts(end+1).ActName = ['loc_in_' Acts(act).ActName];
        Acts(end).ActArray = Acts(strcmp({Acts.ActName}, 'locomotion')).ActArrayRefine.*Acts(act).ActArrayRefine;
        [Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
        Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
        Acts(end).Zone = Acts(act).Zone;

        Acts(end+1).ActName = ['walk_in_' Acts(act).ActName];
        Acts(end).ActArray = Acts(strcmp({Acts.ActName}, 'walk')).ActArrayRefine.*Acts(act).ActArrayRefine;
        [Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
        Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
        Acts(end).Zone = Acts(act).Zone;
        
        Acts(end+1).ActName = ['freez_in_' Acts(act).ActName];
        Acts(end).ActArray = Acts(strcmp({Acts.ActName}, 'freezing')).ActArrayRefine.*Acts(act).ActArrayRefine;
        [Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
        Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';
        Acts(end).Zone = Acts(act).Zone;
%     end
end

% Разделение на 3 кластера по высоте
% Находим минимальное и максимальное значения
min_z = 0;
max_z = 57;

% Вычисляем границы кластеров
bound1 = min_z + (max_z - min_z)/3;
bound2 = min_z + 2*(max_z - min_z)/3;

% Создаем бинаризованный массив
Acts(end+1).ActName = 'box_upper';
Acts(end).ActArray = zeros(size(MouseCenterZ))';
Acts(end).ActArray(MouseCenterZ >= bound2) = 1;
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

Acts(end+1).ActName = 'box_middle';
Acts(end).ActArray = zeros(size(MouseCenterZ))';
Acts(end).ActArray(MouseCenterZ >= bound1 & MouseCenterZ < bound2) = 1;
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

Acts(end+1).ActName = 'box_lower';
Acts(end).ActArray = zeros(size(MouseCenterZ))';
Acts(end).ActArray(MouseCenterZ >= min_z & MouseCenterZ < bound1) = 1;
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

% 3D-траектория мыши по высотным кластерам
h = figure('Position', [300 300 1000 1000]);
plot3(MouseCenterX(find(Acts(end).ActArrayRefine)), MouseCenterY(find(Acts(end).ActArrayRefine)), MouseCenterZ(find(Acts(end).ActArrayRefine)), '.r', 'LineWidth', 2); hold on;
plot3(MouseCenterX(find(Acts(end-1).ActArrayRefine)), MouseCenterY(find(Acts(end-1).ActArrayRefine)), MouseCenterZ(find(Acts(end-1).ActArrayRefine)), '.g', 'LineWidth', 2); hold on;
plot3(MouseCenterX(find(Acts(end-2).ActArrayRefine)), MouseCenterY(find(Acts(end-2).ActArrayRefine)), MouseCenterZ(find(Acts(end-2).ActArrayRefine)), '.b', 'LineWidth', 2);
legend('LOWER ARMS', 'MIDDLE ARMS', 'UPPER ARMS', 'FontSize', 12);
xlabel('X, cm', 'FontSize', 20);
ylabel('Y, cm', 'FontSize', 20);
zlabel('Z, cm', 'FontSize', 20);
grid on;
title(sprintf('3DMaze. %s. Tracking mouse, 3D. Z-clusters arms', strrep(Filename, '_', '\_')), 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Track_3D_Z-Cluster_Arms.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_Track_3D_Z-Cluster_Arms.fig', PathOut, Filename));
delete(h);

% Velocity Z acts calculation

% velocity z calculation
dz = diff(MouseCenterZ);
dt = diff(time);
velocity_z = dz ./ dt;
velocity_z = [0, velocity_z]';
velocity_z_smooth = smooth(velocity_z,round(Options.FrameRate),'sgolay',3);

% acts calculation
Acts(end+1).ActName = 'mouse_goes_straight';
Acts(end).ActArray = double(velocity_z_smooth == 0);
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, round(Options.FrameRate), round(Options.FrameRate));
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

Acts(end+1).ActName = 'mouse_goes_up';
Acts(end).ActArray = double(velocity_z_smooth > 0);
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, round(Options.FrameRate), round(Options.FrameRate));
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

Acts(end+1).ActName = 'mouse_goes_down';
Acts(end).ActArray = double(velocity_z_smooth < 0);
[Acts(end).ActArrayRefine,~,~,~,~,~] = RefineLine(Acts(end).ActArray, round(Options.FrameRate), round(Options.FrameRate));
Acts(end).ActArrayRefine = Acts(end).ActArrayRefine';

% plot vel
h = figure('Position', Screensize);
set(gcf, 'DefaultAxesFontSize', 14);
plot(time, velocity_z, 'b', 'LineWidth', 2); hold on;
% plot(time, velocity_z_smooth, 'g', 'LineWidth', 2);
plot(time(find(Acts(end-2).ActArrayRefine)), velocity_z_smooth(find(Acts(end-2).ActArrayRefine)), '.k', 'LineWidth', 2);hold on;
plot(time(find(Acts(end-1).ActArrayRefine)), velocity_z_smooth(find(Acts(end-1).ActArrayRefine)), '.r', 'LineWidth', 2);hold on;
plot(time(find(Acts(end).ActArrayRefine)), velocity_z_smooth(find(Acts(end).ActArrayRefine)), '.m', 'LineWidth', 2);
legend('ORIGINAL/SMOOTHED 1s', 'MOUSE GO STRAIGNT', 'MOUSE GO UP', 'MOUSE GO DOWN', 'FontSize', 12);
title(sprintf('3DMaze. %s. Velocity Z', strrep(Filename, '_', '\_')), 'FontSize', 16);
xlabel('Time, s', 'FontSize', 20);
ylabel('Velocity, cm/s', 'FontSize', 20);
saveas(h, sprintf('%s\\%s_VelocityZ.fig', PathOut, Filename));
delete(h);

%% act's statistics

for line = 1:size(Acts,2)
    [~, Acts(line).ActNumber, Acts(line).ActPercent, Acts(line).ActDistr,~,~] = RefineLine(Acts(line).ActArrayRefine, 0,0);
    Acts(line).ActPercent = round(Acts(line).ActPercent/n_frames*100,2);
    Acts(line).ActMeanTime = round(mean(Acts(line).ActDistr)/Options.FrameRate,2);
    Acts(line).ActMeanSTDTime = round(std(Acts(line).ActDistr)/Options.FrameRate,2);
    Acts(line).ActMedianTime = round(median(Acts(line).ActDistr)/Options.FrameRate,2);
    Acts(line).ActMedianMADTime = round(mad(Acts(line).ActDistr)/Options.FrameRate,2);
    
    Acts(line).Distance = round(mean(Velocity(logical(Acts(line).ActArrayRefine)))*n_frames/Options.FrameRate*Acts(line).ActPercent/100);
    
    Acts(line).ActMeanDistance = round(Acts(line).Distance/Acts(line).ActNumber,2);
    Acts(line).ActVelocity = round(Acts(line).Distance/(Acts(line).ActMeanTime*Acts(line).ActNumber)*100,2);
    Acts(line).ActDuration = round(Acts(line).ActPercent*session.duration_total/100,2);
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
% plot(time, Acts(5).ActArrayRefine*5, 'm'); hold on;
legend(['Speed' {Acts(1:3).ActName} 'Freezing']);
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
% plot(BodyPartsTracesMainX(Point.Center,logical(Acts(5).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(5).ActArrayRefine)), 'm.');
legend('Locomotion','Other','Rest','Freezing');
saveas(h, sprintf('%s\\%s_track_with_acts.png', PathOut, Filename));
delete(h);

% save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

%% make separate acts videos

if PlotOption.acts
    colorbase = jet(BodyPartsNumber);
    MaxPoints = 1000;
%     for act = 1:size(Acts,2)
    for act = [3 7 12]

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
%                 RealFrame = round((Zones(Acts(act).Zone).maskfilled*255 + single(read(readerobj,k+StartTime-1)))./2);
                RealFrame = round((Acts(act).Zone*255 + single(read(readerobj,k+StartTime-1)))./2);
            end
            
            % points of bodyparts in a fixed frame of reference
            for part=1:length(BodyPartsNames)
                RealFrame = insertShape(RealFrame,'circle', [BodyPartsTraces(part).TraceOriginal.X(k)/Options.x_kcorr BodyPartsTraces(part).TraceOriginal.Y(k) MarkSize*2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
                RealFrame = insertShape(RealFrame,'filledcircle', [BodyPartsTracesMainX(part,k)/Options.x_kcorr BodyPartsTracesMainY(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            end
            
            writeVideo(v,uint8(RealFrame));
        end
        close(v);
        delete(h);
    end
    
end
%% creating outputs table of features

Features.Name = {'x', 'y', 'z', 'speed', 'speed_z', 'bodydirection', 'headdirection'};

Features.Data(1:n_frames,1) = MouseCenterX';
Features.Data(1:n_frames,2) = MouseCenterY';
Features.Data(1:n_frames,3) = MouseCenterZ';
Features.Data(1:n_frames,4) = Velocity;
Features.Data(1:n_frames,5) = velocity_z_smooth;
Features.Data(1:n_frames,6) = AngleRot';
Features.Data(1:n_frames,7) = HeadDirection';

% for act=1:length(Acts)
for act = [1:4 6:25 42:47]
    Features.Data(1:n_frames,end+1) = Acts(act).ActArrayRefine;
    Features.Name{end+1} = Acts(act).ActName;
end

Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);

writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, Filename));
save(sprintf('%s\\%s_WorkSpace.mat',PathOut, Filename));

end

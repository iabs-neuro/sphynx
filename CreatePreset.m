function [FilenamePreset, PathPreset] = CreatePreset(FilenameVideo, PathVideo, PathOut)
% Creates preset file, file with parameters of arena, objects and spatial ROI
% for behavior analysis.
% 22.09.23 Download preset mode added
% 06.02.24 Translation bug was fixed

% ToDo:
% -create box for pxlsm calculation
% -configs for experiment type. make new and load prepeared
% -rotation bug for squared arena fix

% Parameters:
% pxl2sm - pixels in sm (y axes)
% x_kcorr - scale factor for x coordinate
% velocity_rest - velocity border for rest state in sm/s
% velocity_locomotion - velocity border for locomotion state in sm/s
% LikelihoodThreshold - threshold for interpolation of DLC tracks

% Created by VVP. 14.02.23

if nargin<3
    %%
    [FilenameVideo, PathVideo]  = uigetfile('*.*','Select video file','c:\Users\Plusnin\PycharmProjects\sphynx\Demo\Video\');
     PathOut = uigetdir('c:\Users\Plusnin\PycharmProjects\sphynx\Demo\Preset\', 'Pick a Directory for outfiles');
end

%%
wall_width_in_default = '10';
wall_width_out_default = '10';
wall_width_object_default = '2.5';
default_objects_count = '1';

%% some local parameters
NumPointsForPlotBorders = 20000;
StepN = 0.001;
Color.Arena = 'k';
Color.Objects = 'g';
LineWidth.Arena = 2;
LineWidth.Objects = 2;
StepDefault = 10;

TypeExpList = ["BowlsOpenField","3DM","Novelty OF","NOL","Round Track","Holes Track","Odor Track","Freezing Track","New Track","Complex Context","OF_Obj"];
ArenaGeometryOptions = ["Circle", "Polygon", "Ellipse", "O-maze"];

FilenameOut = FilenameVideo(1:end-4);
mkdir(PathOut, sprintf('%s_zones',FilenameOut));
PathOut = sprintf('%s\\%s_zones',PathOut, FilenameOut);

question = questdlg('Do you want dowload Preset?', 'Important question', 'Yes','No','Yes');
switch question
    case 'Yes'
        [FilenamePresetDownload, PathPresetDownload]  = uigetfile('*.mat','Select preset file','c:\Users\Plusnin\PycharmProjects\sphynx\Demo\Preset\');
        load(sprintf('%s//%s', PathPresetDownload, FilenamePresetDownload), 'Options','ArenaAndObjects');
end

Options.ExperimentType = TypeExpList{listdlg('PromptString', 'Choose the type of experiment','ListString', TypeExpList, 'ListSize', [160  length(TypeExpList)*20])};
Options.LikelihoodThreshold = 0.95;
Options.SpeedOptions = {'Rest', 'Walk', 'Locomotion'};
Options.velocity_rest = 1;
Options.velocity_locomotion = 5;
Options.x_kcorr = 1;
Options.BodyPart.Velocity = 'bodycenter';
Options.BodyPart.WallsZone = 'bodycenter';
Options.BodyPart.ObjectZone = 'bodycenter';

%% reading a video file
fprintf('Loading video: %s started\n',FilenameVideo);
VideoObj = VideoReader(sprintf('%s%s', PathVideo, FilenameVideo));
Options.FrameRate = get(VideoObj, 'FrameRate');
Options.NumFrames = get(VideoObj, 'NumFrames');
Options.Height = get(VideoObj, 'Height');
Options.Width = get(VideoObj, 'Width');
Options.Duration = get(VideoObj, 'Duration');

Options.MinLengthActInSeconds = 0.25;
Options.SmoothWindowSmallInSeconds = 0.1;
Options.SmoothWindowBigInSeconds = 0.25;
Options.MinLengthActInFrames = round(Options.FrameRate*Options.MinLengthActInSeconds);
Options.SmoothWindowSmallInFrames = round(Options.FrameRate*Options.SmoothWindowSmallInSeconds);
Options.SmoothWindowBigInFrames = round(Options.FrameRate*Options.SmoothWindowBigInSeconds);

Options.PathPreset = PathOut;
Options.FilenamePreset = sprintf('%s_Preset.mat', FilenameOut);
PathPreset = Options.PathPreset;
FilenamePreset = Options.FilenamePreset;
fprintf('Loading video: %s finished\n',FilenameVideo);

%% searching of a good frame
% good frame is a good when you can observe the boundaries of the arena and
% objects without obstruction

gframe = round(Options.NumFrames/2);
prmt = 0;
while prmt==0
    VidFrames = read(VideoObj,gframe);
    h=figure;
    %     IM = VidFrames(:,:,1);
    IM = VidFrames;
    imshow(IM);hold on;
    answer = questdlg('Is it good frame?', 'Arena parameters definition', 'Yes','No','Yes');
    switch answer
        case 'Yes'
            prmt = 1;
            Options.GoodVideoFrame = IM;
            Options.GoodVideoFrameGray = VidFrames(:,:,1);
        case 'No'
            prmt = 0;
            gframe = randi([round(Options.NumFrames/2), Options.NumFrames]);
    end
    delete(h);
end

%% 
% switch Options.ExperimentType
%     case 'BowlsOpenField'
%         [Options.pxl2sm, Options.x_kcorr] = CalculatePxlInCm(Options.GoodVideoFrame);
% %         Options.pxl2sm = 9.3; % BOF 2024 1T
% %        Options.pxl2sm = ;  % BOF 2024 2T
%     case 'Complex Context'
%         [Options.pxl2sm, Options.x_kcorr] = CalculatePxlInCm(Options.GoodVideoFrame);
%     case 'Novelty OF'
%         Options.pxl2sm = 350/44;
%        Options.pxl2sm = 22.2; % NOF 2024 H01-10, 1 wave
%         Options.pxl2sm = 28.1; % NOF 2024 H11-23, 2 wave
%         Options.pxl2sm = 20.6; % NOF 2024 H26-39, 3 wave
%         Options.pxl2sm = 10.8; % feed 2024 H26-39, 3 wave
        [Options.pxl2sm, Options.x_kcorr] = CalculatePxlInCm(Options.GoodVideoFrame);
%     case 'NOL'
%         Options.pxl2sm = 16.5;
%     case 'Round Track'
%         Options.pxl2sm = 1;
%     case 'Holes Track'
%         Options.pxl2sm = 95/4;
%     case 'Odor Track'
%         Options.pxl2sm = 95/4;
%     case 'Freezing Track'
%         Options.pxl2sm = 1;
%         Options.TailHeight = 22;
%         Options.WidthReal = 29;
%         Options.HeightReal = 24;
%     case "OF_Obj"
%         Options.pxl2sm = 5.9;
%     case 'New Track'
%         Options.pxl2sm = str2double(inputdlg('Specify the number of pixels in 1 cm', 'Parameters', 1, {'8'}, 'on'));
%         % create box from user
% end

%% rescale downloaded preset to current video

if strcmp(question, 'Yes')
    rotationAngle = 0;
    rotationCenterX = mean(ArenaAndObjects(1).border_x);
    rotationCenterY = mean(ArenaAndObjects(1).border_y);
    y_rotated = cell(1,size(ArenaAndObjects, 2));
    x_rotated = cell(1,size(ArenaAndObjects, 2));
    x_relative = cell(1,size(ArenaAndObjects, 2));
    y_relative = cell(1,size(ArenaAndObjects, 2));
    figure;
    imshow(Options.GoodVideoFrame);hold on;
    title(sprintf('Move objects by arrows, + and - to change step. \n Current step = %d, Current Angle = %d', StepDefault,rotationAngle));
    for line = 1:length(ArenaAndObjects)
        plot(ArenaAndObjects(line).border_x,ArenaAndObjects(line).border_y, Color.Arena,'LineWidth',LineWidth.Arena);hold on;
    end
    key = 0;
    while key ~= 's'
        waitforbuttonpress;
        key = get(gcf, 'CurrentCharacter');
        if key == 28  
            for line = 1:length(ArenaAndObjects)
                ArenaAndObjects(line).border_x = ArenaAndObjects(line).border_x - StepDefault;
                if line==1 && ~isempty(ArenaAndObjects(1).border_separate_x)
                    for separateline = 1:4
                        ArenaAndObjects(line).border_separate_x{separateline} = ArenaAndObjects(line).border_separate_x{separateline} - StepDefault;
                    end
                end
            end
        elseif key == 29  
            for line = 1:length(ArenaAndObjects)
                ArenaAndObjects(line).border_x = ArenaAndObjects(line).border_x + StepDefault;
                if line==1 && ~isempty(ArenaAndObjects(1).border_separate_x)
                    for separateline = 1:4
                        ArenaAndObjects(line).border_separate_x{separateline} = ArenaAndObjects(line).border_separate_x{separateline} + StepDefault;
                    end
                end
            end
        elseif key == 30  
            for line = 1:length(ArenaAndObjects)
                ArenaAndObjects(line).border_y = ArenaAndObjects(line).border_y - StepDefault;
                if line==1 && ~isempty(ArenaAndObjects(1).border_separate_x)
                    for separateline = 1:4
                        ArenaAndObjects(line).border_separate_y{separateline} = ArenaAndObjects(line).border_separate_y{separateline} - StepDefault;
                    end
                end
            end
        elseif key == 31  
            for line = 1:length(ArenaAndObjects)
                ArenaAndObjects(line).border_y = ArenaAndObjects(line).border_y + StepDefault;
                if line==1 && ~isempty(ArenaAndObjects(1).border_separate_x)
                    for separateline = 1:4 
                        ArenaAndObjects(line).border_separate_y{separateline} = ArenaAndObjects(line).border_separate_y{separateline} + StepDefault;
                    end
                end
            end
        elseif key == '-'  
            StepDefault = round(StepDefault/2);
            if StepDefault < 1
                StepDefault = 1;
            end
        elseif key == '+'  
            StepDefault = round(StepDefault*2);
        elseif key == '['
            rotationAngle = rotationAngle + StepDefault; % увеличиваем угол вращени�? на StepDefault граду�?ов по ча�?овой �?трелке
        elseif key == ']'
            rotationAngle = rotationAngle - StepDefault; % уменьшаем угол вращени�? на StepDefault граду�?ов против ча�?овой �?трелки
        elseif key == 13
            delete(gcf);
        end

        if rotationAngle ~= 0 && (key == ']' || key == '[')
            if key == ']'
                rotationAngleRad = -StepDefault/180*pi;
            else
                rotationAngleRad = StepDefault/180*pi;
            end
            rotationMatrix = [cos(rotationAngleRad), -sin(rotationAngleRad); sin(rotationAngleRad), cos(rotationAngleRad)];
            for line = 1:length(ArenaAndObjects)
                x_relative{line} = ArenaAndObjects(line).border_x - rotationCenterX;
                y_relative{line} = ArenaAndObjects(line).border_y - rotationCenterY;
            end

            for line = 1:length(ArenaAndObjects)
                x_rotated{line} = rotationMatrix(1,1)*x_relative{line} + rotationMatrix(1,2)*y_relative{line};
                y_rotated{line} = rotationMatrix(2,1)*x_relative{line} + rotationMatrix(2,2)*y_relative{line};
            end

            for line = 1:length(ArenaAndObjects)
                ArenaAndObjects(line).border_x = [x_rotated{line}] + rotationCenterX;
                ArenaAndObjects(line).border_y = [y_rotated{line}] + rotationCenterY;
            end
        end

        delete(gcf);
        figure;
        imshow(Options.GoodVideoFrame);hold on;
        title(sprintf('Move objects by arrows, + and - to change step. \n Current step = %d, Current Angle = %d', StepDefault,rotationAngle));
        for line = 1:length(ArenaAndObjects)
            plot(ArenaAndObjects(line).border_x,ArenaAndObjects(line).border_y, Color.Arena,'LineWidth',LineWidth.Arena);hold on;
        end
    end

    for line = 1:length(ArenaAndObjects)
        if line == 1
            ArenaAndObjects(line).maskborder = {MaskCreator(zeros(Options.Height,Options.Width), ArenaAndObjects(line).border_x, ArenaAndObjects(line).border_y)};
            ArenaAndObjects(line).maskfilled = imfill(ArenaAndObjects(line).maskborder{1});
        else
            ArenaAndObjects(line).maskborder = MaskCreator(zeros(Options.Height,Options.Width), ArenaAndObjects(line).border_x, ArenaAndObjects(line).border_y);
            ArenaAndObjects(line).maskfilled = imfill(ArenaAndObjects(line).maskborder);
        end
    end
else

%% reading arena coordinates

[ArenaGeometryOptionIndex,~] = listdlg('PromptString','Choose the geometry of the arena','SelectionMode','single','ListString',ArenaGeometryOptions, 'ListSize', [160  length(ArenaGeometryOptions)*15]);
Options.ArenaGeometry = ArenaGeometryOptions{ArenaGeometryOptionIndex};
ArenaAndObjects = struct('type',[],'geometry',[],'maskborder', [], 'maskfilled', [], 'border_x',[],'border_y',[], 'border_separate_x', [], 'border_separate_y', []);

prmt = 0;
th = linspace(0,2*pi,NumPointsForPlotBorders)';
while prmt==0
    x_arena = [];
    y_arena = [];
    h=figure;
    imshow(Options.GoodVideoFrame);hold on;
    switch Options.ArenaGeometry
        case 'Polygon'
%             uiwait(msgbox('Indicate all points of the corners of the polygon arena','Message for you','modal'));
            [x_ar, y_ar] = ginput;
            if length(x_ar)>=3
                [x_arena, y_arena, ArenaAndObjects(1).border_separate_x, ArenaAndObjects(1).border_separate_y] = PolygonFit(x_ar*Options.x_kcorr,y_ar);
            end
            for border = 1:4
                ArenaAndObjects(1).border_separate_x{border} = ArenaAndObjects(1).border_separate_x{border}/Options.x_kcorr;
            end
        case 'Circle'
            uiwait(msgbox('Indicate at least 3 points of the circle arena','Message for you','modal'));
            [x_ar, y_ar] = ginput;
            if length(x_ar)>=3
                [xc,yc,R,~] = circfit(x_ar*Options.x_kcorr,y_ar);
                x_arena = xc + R*cos(th);
                y_arena = yc + R*sin(th);
            end
        case 'Ellipse'
            uiwait(msgbox('Indicate at least 5 points of the ellipse arena','Message for you','modal'));
            [x_ar, y_ar] = ginput;
            if length(x_ar)>=5
                ellipse = my_fit_ellipse(x_ar*Options.x_kcorr,y_ar);
                y_arena = ellipse.Y0_in+(ellipse.b)*cos(th)*cos(ellipse.phi)-(ellipse.a)*sin(th)*sin(ellipse.phi);
                x_arena = ellipse.X0_in+(ellipse.b)*cos(th)*sin(ellipse.phi)+(ellipse.a)*sin(th)*cos(ellipse.phi);
            end
        case 'O-maze'
            uiwait(msgbox('Indicate at least 3 points of OUTER border of the o-maze arena','Message for you','modal'));
            [x_ar, y_ar] = ginput;
            if length(x_ar)>=3
                [xc,yc,R,~] = circfit(x_ar*Options.x_kcorr,y_ar);
                x_arena(:,1) = xc + R*cos(th);
                y_arena(:,1) = yc + R*sin(th);
            end
            uiwait(msgbox('Indicate at least 3 points of INNER border of the o-maze arena','Message for you','modal'));
            [x_ar, y_ar] = ginput;
            if length(x_ar)>=3
                [xc,yc,R,~] = circfit(x_ar*Options.x_kcorr,y_ar);
                x_arena(:,2) = xc + R*cos(th);
                y_arena(:,2) = yc + R*sin(th);
            end
    end
    if isempty(x_arena) || (Options.ArenaGeometry == "O-maze" && size(x_arena,2) < 2)
        answer = 0;
        uiwait(msgbox('Not enough points! Try again','Message for you','modal'));
    else
        plot(x_arena(:,1)/Options.x_kcorr,y_arena(:,1), Color.Arena,'LineWidth',LineWidth.Arena);hold on;
        if size(x_arena,2) == 2
            plot(x_arena(:,2)/Options.x_kcorr,y_arena(:,2), Color.Arena,'LineWidth',LineWidth.Arena);hold on;
        end
        answer = questdlg('Is it correct?', 'Arena with borders', 'Yes','No','Yes');
    end
    switch answer
        case 'Yes'
            prmt = 1;
        case 'No'
            prmt = 0;
    end
    delete(h);
end

ArenaAndObjects(1).type = 'Arena';
ArenaAndObjects(1).geometry = Options.ArenaGeometry;

if ~strcmp(ArenaAndObjects(1).geometry, 'O-maze')
    ArenaAndObjects(1).maskborder = {MaskCreator(zeros(Options.Height,Options.Width), x_arena/Options.x_kcorr, y_arena)};
    ArenaAndObjects(1).maskfilled = imfill(ArenaAndObjects(1).maskborder{1});
else
    ArenaAndObjects(1).maskborder = {MaskCreator(zeros(Options.Height,Options.Width), x_arena(:,1)/Options.x_kcorr, y_arena(:,1))...
    MaskCreator(zeros(Options.Height,Options.Width), x_arena(:,2)/Options.x_kcorr, y_arena(:,2))};
    ArenaAndObjects(1).maskfilled = imfill(ArenaAndObjects(1).maskborder{1}) - imfill(ArenaAndObjects(1).maskborder{2});
end
ArenaAndObjects(1).border_x = x_arena/Options.x_kcorr;
ArenaAndObjects(1).border_y = y_arena;

%% reading objects coordinates

Options.ObjectsNumber = str2double(inputdlg('Specify the number of objects', 'Parameters', 1, {default_objects_count}, 'on'));
for object=1:Options.ObjectsNumber
    ObjectGeometry = questdlg('Choice geometry of object', 'Parameters', 'Polygon', 'Circle', 'Ellipse', 'Polygon');
    prmt = 0;
    while prmt==0
        x_object = [];
        y_object = [];
        h=figure;
        imshow(Options.GoodVideoFrame);hold on;
        switch ObjectGeometry
            case 'Polygon'
%                 uiwait(msgbox('Indicate all points of the corners of the polygon object','Message for you','modal'));
                [x_ob, y_ob] = ginput;
                if length(x_ob)>=3
                    [x_object, y_object,~,~] = PolygonFit(x_ob*Options.x_kcorr,y_ob);
                end
            case 'Circle'
%                 uiwait(msgbox('Indicate at least 3 points of the circle object','Message for you','modal'));
                [x_ob, y_ob] = ginput;
                if length(x_ob)>=3
                    [xc,yc,R,~] = circfit(x_ob*Options.x_kcorr,y_ob);
                    x_object = xc + R*cos(th);
                    y_object = yc + R*sin(th);
                end
            case 'Ellipse'
%                 uiwait(msgbox('Indicate at least 5 points of the ellipse object','Message for you','modal'));
                [x_ob, y_ob] = ginput;
                if length(x_ob)>=5
                    ellipse = my_fit_ellipse(x_ob*Options.x_kcorr,y_ob);
                    y_object = ellipse.Y0_in+(ellipse.b)*cos(th)*cos(ellipse.phi)-(ellipse.a)*sin(th)*sin(ellipse.phi);
                    x_object = ellipse.X0_in+(ellipse.b)*cos(th)*sin(ellipse.phi)+(ellipse.a)*sin(th)*cos(ellipse.phi);
                end
        end
        if isempty(x_object)
            answer = 0;
            uiwait(msgbox('Not enough points! Try again','Message for you','modal'));
        else
            plot(x_object/Options.x_kcorr, y_object, Color.Objects,'LineWidth',LineWidth.Objects);hold on;
            answer = questdlg('Is it correct?', 'Arena with border',	'Yes','No','Yes');
        end
        switch answer
            case 'Yes'
                prmt = 1;
            case 'No'
                prmt = 0;
        end
        delete(h);
    end
    ArenaAndObjects(1+object).type = ['Object' num2str(object)];
    ArenaAndObjects(1+object).geometry = ObjectGeometry;
    ArenaAndObjects(1+object).maskborder = MaskCreator(zeros(Options.Height,Options.Width), x_object/Options.x_kcorr, y_object);
    ArenaAndObjects(1+object).maskfilled = imfill(ArenaAndObjects(1+object).maskborder);
    ArenaAndObjects(1+object).border_x = x_object;
    ArenaAndObjects(1+object).border_y = y_object;
end
end

%% finding all zones
switch Options.ExperimentType
    case 'Freezing Track'
        ArenaAndObjects(1).point_x = x_ar;
        ArenaAndObjects(1).point_y = y_ar;
        save(sprintf('%s\\%s',Options.PathPreset, Options.FilenamePreset),'Options','ArenaAndObjects');

    case {'3DM', 'BowlsOpenField', 'Round Track', 'Holes Track', 'Odor Track', 'Novelty OF', 'New Track', 'Complex Context', 'NOL','OF_Obj'}
        Zones = struct('name',[],'type',[], 'maskfilled', []);
        prmt = 0;
        while prmt == 0
            dlg_prompt = {'Specify width of wall outside zone (cm)','Specify width of wall inside zone (cm)', 'Specify width of object zone (cm)'};            
            dlg_default_data = {wall_width_in_default, wall_width_out_default, wall_width_object_default};
            dlg_data = inputdlg(dlg_prompt, 'Parameters', 1, dlg_default_data, 'on');

            Options.WidthWallOutCm = str2double(dlg_data{1});
            Options.WidthWallInCm = str2double(dlg_data{2});
            Options.WidthObjectCm = str2double(dlg_data{3});
            Options.WidthCornerCm = Options.WidthWallInCm*sqrt(2);

            Options.WidthWallOutPxl = Options.WidthWallOutCm*Options.pxl2sm;
            Options.WidthWallInPxl = Options.WidthWallInCm*Options.pxl2sm;
            Options.WidthObjectPxl = Options.WidthObjectCm*Options.pxl2sm;
            Options.WidthCornerPxl = Options.WidthCornerCm*Options.pxl2sm;

            % defining arena and objects areas
            zone_cnt = 1;
            for i=1:size(ArenaAndObjects,2)
                Zones(zone_cnt).name = [ArenaAndObjects(i).type 'Real'];
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = single(ArenaAndObjects(i).maskfilled);
                zone_cnt = zone_cnt+1;
                if i == 1
                    WidthOutThis = Options.WidthWallOutPxl;
                else
                    WidthOutThis = Options.WidthObjectPxl;
                end
                BWDMask = bwdist(ArenaAndObjects(i).maskfilled);
                BWDMask(BWDMask<WidthOutThis) = 0;
                Zones(zone_cnt).name = [ArenaAndObjects(i).type 'RealOut'];
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = single(~BWDMask);
                zone_cnt = zone_cnt+1;

                Zones(zone_cnt).name = [ArenaAndObjects(i).type 'Out'];
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = Zones(zone_cnt-1).maskfilled-Zones(zone_cnt-2).maskfilled;
                zone_cnt = zone_cnt+1;
            end

            % defining all objects area, real, out and realout
            if Options.ObjectsNumber > 0
                TempMask = zeros(Options.Height, Options.Width);
                SumTempMask = zeros(Options.Height, Options.Width);
                ExtraMask = zeros(Options.Height, Options.Width);

                for object = 1:length(ArenaAndObjects)-1
                    TempMask = TempMask + Zones(strcmp({Zones.name}, sprintf('Object%dRealOut', object))).maskfilled;
                    SumTempMask = SumTempMask + Zones(strcmp({Zones.name}, sprintf('Object%dReal', object))).maskfilled;
                    ExtraMask = ExtraMask + Zones(strcmp({Zones.name}, sprintf('Object%dOut', object))).maskfilled;
                end

                Zones(zone_cnt).name = 'ObjectAllRealOut';
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = TempMask;
                zone_cnt = zone_cnt+1;

                Zones(zone_cnt).name = 'ObjectAllReal';
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = SumTempMask;
                zone_cnt = zone_cnt+1;

                Zones(zone_cnt).name = 'ObjectAllOut';
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = ExtraMask;
                zone_cnt = zone_cnt+1;
            end

            if ~strcmp(ArenaAndObjects(1).geometry, 'O-maze')
                % defining center area
                TempMask = single(~Zones(strcmp({Zones.name}, 'ArenaReal')).maskfilled);
                TempMask = bwdist(TempMask);
                TempMask(TempMask<=Options.WidthWallInPxl) = 0;
                TempMask(TempMask>0) = 1;

                Zones(zone_cnt).name = 'Center';
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = single(TempMask);
                zone_cnt = zone_cnt+1;

                % defining all walls plus corners area
                Zones(zone_cnt).name = 'WallsAndCornersRealOut';
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = Zones(strcmp({Zones.name}, 'ArenaRealOut')).maskfilled-Zones(strcmp({Zones.name}, 'Center')).maskfilled;
                zone_cnt = zone_cnt+1;

                % defining all walls plus corners area
                Zones(zone_cnt).name = 'WallsAndCornersReal';
                Zones(zone_cnt).type = 'area';
                Zones(zone_cnt).maskfilled = Zones(strcmp({Zones.name}, 'WallsAndCornersRealOut')).maskfilled-Zones(strcmp({Zones.name}, 'ArenaOut')).maskfilled;
                zone_cnt = zone_cnt+1;

                % defining separate area of corners and points of corners for Polygon
                % geometry
                if strcmp(ArenaAndObjects(1).geometry, 'Polygon')
                    SumTempMask = zeros(Options.Height, Options.Width);
                    for corner = 1:length(ArenaAndObjects(1).border_separate_x)
                        Zones(zone_cnt).name = ['ArenaCorner' num2str(corner)];
                        Zones(zone_cnt).type = 'point';
                        Zones(zone_cnt).maskfilled = [ArenaAndObjects(1).border_separate_x{1,corner}(1) ArenaAndObjects(1).border_separate_y{1,corner}(1)];
                        zone_cnt = zone_cnt+1;

                        TempMask = zeros(Options.Height, Options.Width);
                        TempMask(round(Zones(zone_cnt-1).maskfilled(2)),round(Zones(zone_cnt-1).maskfilled(1))) = 1;
                        Zones(zone_cnt).name = ['ArenaCornerPoint' num2str(corner)];
                        Zones(zone_cnt).type = 'pointarea';
                        Zones(zone_cnt).maskfilled = single(TempMask);
                        zone_cnt = zone_cnt+1;

                        TempMask = bwdist(Zones(zone_cnt-1).maskfilled);
                        TempMask(TempMask>Options.WidthCornerPxl) = 0;
                        TempMask(TempMask>0) = 1;
                        TempMask = TempMask + Zones(strcmp({Zones.name}, 'WallsAndCornersReal')).maskfilled;
                        TempMask(TempMask<2) = 0;
                        TempMask(TempMask>0) = 1;
                        TempMask = TempMask + Zones(zone_cnt-1).maskfilled;
                        Zones(zone_cnt).name = ['ArenaCornerReal' num2str(corner)];
                        Zones(zone_cnt).type = 'area';
                        Zones(zone_cnt).maskfilled = TempMask;
                        zone_cnt = zone_cnt+1;
                        SumTempMask = SumTempMask + TempMask;
                    end
                    Zones(zone_cnt).name = 'ArenaCornersAllReal';
                    Zones(zone_cnt).type = 'area';
                    Zones(zone_cnt).maskfilled = SumTempMask;
                    zone_cnt = zone_cnt+1;

                    % defining equation of borders
                    k_perpendicular_border = zeros(1,length(ArenaAndObjects(1).border_separate_x));
                    for line = 1:length(ArenaAndObjects(1).border_separate_x)
                        [Zones(zone_cnt).maskfilled] = GetLineEquation([ArenaAndObjects(1).border_separate_x{line}(1) ArenaAndObjects(1).border_separate_y{line}(1)], [ArenaAndObjects(1).border_separate_x{line}(end) ArenaAndObjects(1).border_separate_y{line}(end)]);
                        Zones(zone_cnt).name = ['Border' num2str(line)];
                        Zones(zone_cnt).type = 'equation';
                        if isnan(Zones(zone_cnt).maskfilled(3)) && ~isnan(Zones(zone_cnt).maskfilled(1)) && ~isnan(Zones(zone_cnt).maskfilled(2))
                            if Zones(zone_cnt).maskfilled(1) ~= 0
                                k_perpendicular_border(line) = -1/Zones(zone_cnt).maskfilled(1);
                            else
                                k_perpendicular_border(line) = nan;
                            end
                        else
                            k_perpendicular_border(line) = 0;
                        end
                        zone_cnt = zone_cnt+1;
                    end

                    %defining CornerOut areas
                    SumTempMask = zeros(Options.Height, Options.Width);
                    for corner = 1:length(ArenaAndObjects(1).border_separate_x)
                        TempMask = Zones(strcmp({Zones.name}, 'ArenaOut')).maskfilled;
                        if corner == 1
                            TempArray.Left.x = ArenaAndObjects(1).border_separate_x{end}(end:-1:1);
                            TempArray.Left.y = ArenaAndObjects(1).border_separate_y{end}(end:-1:1);
                        else
                            TempArray.Left.x = ArenaAndObjects(1).border_separate_x{corner-1}(end:-1:1);
                            TempArray.Left.y = ArenaAndObjects(1).border_separate_y{corner-1}(end:-1:1);
                        end
                        TempArray.Right.x = ArenaAndObjects(1).border_separate_x{corner};
                        TempArray.Right.y = ArenaAndObjects(1).border_separate_y{corner};

                        count.left = 1;
                        while sqrt((TempArray.Left.x(1)-TempArray.Left.x(count.left))^2+(TempArray.Left.y(1)-TempArray.Left.y(count.left))^2) < Options.WidthCornerPxl
                            count.left = count.left + 1;
                        end

                        count.right = 1;
                        while sqrt((TempArray.Right.x(1)-TempArray.Right.x(count.right))^2+(TempArray.Right.y(1)-TempArray.Right.y(count.right))^2) < Options.WidthCornerPxl
                            count.right = count.right + 1;
                        end

                        for direction = 1:2
                            switch direction
                                case 1
                                    if corner == 1
                                        k_perpendicular_border_dir = k_perpendicular_border(corner);
                                    else
                                        k_perpendicular_border_dir = k_perpendicular_border(corner);
                                    end
                                    count.dir = count.right;
                                    TempArray.Dir.y = TempArray.Right.y;
                                    TempArray.Dir.x = TempArray.Right.x;
                                case 2
                                    if corner == 1
                                        k_perpendicular_border_dir = k_perpendicular_border(end);
                                    else
                                        k_perpendicular_border_dir = k_perpendicular_border(corner-1);
                                    end
                                    count.dir = count.left;
                                    TempArray.Dir.y = TempArray.Left.y;
                                    TempArray.Dir.x = TempArray.Left.x;
                            end

                            dx = 0;
                            dy = 0;
                            while TempMask(round(TempArray.Dir.y(count.dir) + dy), round(TempArray.Dir.x(count.dir) + dx)) == 0 && TempMask(round(TempArray.Dir.y(count.dir) - dy), round(TempArray.Dir.x(count.dir) - dx)) == 0
                                if ~isnan(k_perpendicular_border_dir)
                                    dx = dx + StepN;
                                    dy = k_perpendicular_border_dir*dx;
                                else
                                    dx = 0;
                                    dy = dy + StepN;
                                end
                            end

                            if TempMask(round(TempArray.Dir.y(count.dir) + dy), round(TempArray.Dir.x(count.dir) + dx)) == 1
                                PointP.x = TempArray.Dir.x(count.dir) + dx;
                                PointP.y = TempArray.Dir.y(count.dir) + dy;
                            else
                                PointP.x = TempArray.Dir.x(count.dir) - dx;
                                PointP.y = TempArray.Dir.y(count.dir) - dy;
                                dx = -dx;
                                dy = -dy;
                            end

                            PointK.x = PointP.x;
                            PointK.y = PointP.y;
                            cnt=1;
                            PointsToZero = struct('x',[],'y',[]);
                            while TempMask(round(PointK.y),round(PointK.x)) == 1 && ...
                                    (PointK.x + StepN*sign(dx) < Options.Width) && ...
                                    (PointK.x + StepN*sign(dx) >= 1) && ...
                                    ((dx ~= 0 && PointK.y + k_perpendicular_border_dir*StepN*sign(dx) < Options.Height && PointK.y + k_perpendicular_border_dir*StepN*sign(dx) >= 1) || (dx == 0 && PointK.y + StepN*sign(dy) < Options.Height && PointK.y + StepN*sign(dy)>= 1))
                                PointsToZero.x(cnt) = round(PointK.x);
                                PointsToZero.y(cnt) = round(PointK.y);
                                if dx ~= 0
                                    PointK.x = PointK.x + StepN*sign(dx);
                                    PointK.y = PointK.y + k_perpendicular_border_dir*StepN*sign(dx);
                                else
                                    PointK.x = PointK.x;
                                    PointK.y = PointK.y + StepN*sign(dy);
                                end
                                cnt = cnt + 1;
                            end

                            for dot = 1:length(PointsToZero.x)
                                TempMask(round(PointsToZero.y(dot)), round(PointsToZero.x(dot))) = 0;
                            end
                        end

                        [TempMaskLabeled,~] = bwlabel(TempMask,4);
                        TempMaskOpt = regionprops(TempMaskLabeled, 'PixelList', 'Area');

                        [~,region_max] = max([TempMaskOpt.Area]);
                        TempMask(TempMaskLabeled == TempMaskLabeled(TempMaskOpt(region_max).PixelList(1,2),TempMaskOpt(region_max).PixelList(1,1))) = 0;
                        TempMask(TempMask > 0) = 1;
                        Zones(zone_cnt).name = ['ArenaCornerOut' num2str(corner)];
                        Zones(zone_cnt).type = 'area';
                        Zones(zone_cnt).maskfilled = TempMask;
                        SumTempMask = SumTempMask + TempMask;
                        zone_cnt = zone_cnt+1;
                    end
                    Zones(zone_cnt).name = 'ArenaCornersAllOut';
                    Zones(zone_cnt).type = 'area';
                    Zones(zone_cnt).maskfilled = SumTempMask;
                    zone_cnt = zone_cnt+1;

                    % defining CornerRealOut areas and CornersAllRealOut area
                    SumTempMask = zeros(Options.Height, Options.Width);
                    for corner = 1:length(ArenaAndObjects(1).border_separate_x)
                        Zones(zone_cnt).name = ['ArenaCornerRealOut' num2str(corner)];
                        Zones(zone_cnt).type = 'area';
                        Zones(zone_cnt).maskfilled = Zones(strcmp({Zones.name}, sprintf('ArenaCornerReal%d',corner))).maskfilled + Zones(strcmp({Zones.name}, sprintf('ArenaCornerOut%d',corner))).maskfilled;
                        SumTempMask = SumTempMask + Zones(zone_cnt).maskfilled;
                        zone_cnt = zone_cnt+1;
                    end
                    Zones(zone_cnt).name = 'ArenaCornersAllRealOut';
                    Zones(zone_cnt).type = 'area';
                    Zones(zone_cnt).maskfilled = SumTempMask;
                    zone_cnt = zone_cnt+1;

                    % defining all walls real area
                    Zones(zone_cnt).name = 'ArenaWallsAllReal';
                    Zones(zone_cnt).type = 'area';
                    Zones(zone_cnt).maskfilled = Zones(strcmp({Zones.name}, 'WallsAndCornersReal')).maskfilled - Zones(strcmp({Zones.name}, 'ArenaCornersAllReal')).maskfilled;
                    zone_cnt = zone_cnt+1;

                    % defining all walls out area
                    Zones(zone_cnt).name = 'ArenaWallsAllOut';
                    Zones(zone_cnt).type = 'area';
                    Zones(zone_cnt).maskfilled = Zones(strcmp({Zones.name}, 'ArenaOut')).maskfilled - Zones(strcmp({Zones.name}, 'ArenaCornersAllOut')).maskfilled;
                    zone_cnt = zone_cnt+1;

                    % defining all walls realout area
                    Zones(zone_cnt).name = 'ArenaWallsAllRealOut';
                    Zones(zone_cnt).type = 'area';
                    Zones(zone_cnt).maskfilled = Zones(strcmp({Zones.name}, 'WallsAndCornersRealOut')).maskfilled - Zones(strcmp({Zones.name}, 'ArenaCornersAllRealOut')).maskfilled;
                    zone_cnt = zone_cnt+1;

                    % defining separate walls
                    [TempMaskLabeled(:,:,1),~] = bwlabel(Zones(strcmp({Zones.name}, 'ArenaWallsAllReal')).maskfilled,4);
                    [TempMaskLabeled(:,:,2),~] = bwlabel(Zones(strcmp({Zones.name}, 'ArenaWallsAllOut')).maskfilled,4);
                    for wall = 1:length(ArenaAndObjects(1).border_separate_x)
                        PointC.x = round(ArenaAndObjects(1).border_separate_x{wall}(round(end/2)));
                        PointC.y = round(ArenaAndObjects(1).border_separate_y{wall}(round(end/2)));
                        label = zeros(1,2);
                        for i = [-1 0 1]
                            for j = [-1 0 1]
                                for mask = [1 2]
                                    if TempMaskLabeled(PointC.y + i,PointC.x + j,mask) ~= 0
                                        label(mask) = TempMaskLabeled(PointC.y + i,PointC.x + j,mask);
                                    end
                                end
                            end
                        end
                        Zones(zone_cnt).name = ['ArenaWallReal' num2str(wall)];
                        Zones(zone_cnt).type = 'area';
                        Zones(zone_cnt).maskfilled = single(TempMaskLabeled(:,:,1) == label(1));
                        zone_cnt = zone_cnt+1;

                        Zones(zone_cnt).name = ['ArenaWallOut' num2str(wall)];
                        Zones(zone_cnt).type = 'area';
                        Zones(zone_cnt).maskfilled = single(TempMaskLabeled(:,:,2) == label(2));
                        zone_cnt = zone_cnt+1;

                        Zones(zone_cnt).name = ['ArenaWallRealOut' num2str(wall)];
                        Zones(zone_cnt).type = 'area';
                        Zones(zone_cnt).maskfilled = Zones(zone_cnt-1).maskfilled + Zones(zone_cnt-2).maskfilled;
                        zone_cnt = zone_cnt+1;
                    end
                end
            end

            % plot of main zones
            [X,Y] = meshgrid(1:Options.Width,1:Options.Height);
            PlotArray = Y.*ArenaAndObjects(1).maskborder{1};
            switch ArenaAndObjects(1).geometry
                case 'Polygon'
                    zone_for_plot = [
                        find(strcmp({Zones.name}, 'ArenaWallsAllRealOut')) ...
                        find(strcmp({Zones.name}, 'Center')) ...
                        find(strcmp({Zones.name}, 'ArenaCornersAllRealOut'))...
                        ];
                    IIM(:,:,1) = round((Zones(zone_for_plot(1)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                    IIM(:,:,2) = round((Zones(zone_for_plot(2)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                    IIM(:,:,3) = round((Zones(zone_for_plot(3)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                case {'Circle', 'Ellipse'}
                    zone_for_plot = [
                        find(strcmp({Zones.name}, 'WallsAndCornersRealOut')) ...
                        find(strcmp({Zones.name}, 'Center'))];
                    IIM(:,:,1) = round((Zones(zone_for_plot(1)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                    IIM(:,:,2) = round((Zones(zone_for_plot(2)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                    IIM(:,:,3) = single(Options.GoodVideoFrameGray);
                case 'O-maze'
                    zone_for_plot = [
                        find(strcmp({Zones.name}, 'ArenaReal')) ...
                        find(strcmp({Zones.name}, 'ArenaOut'))];
                    PlotArray = PlotArray + Y.*ArenaAndObjects(1).maskborder{2};
                    IIM(:,:,1) = round((Zones(zone_for_plot(1)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                    IIM(:,:,2) = round((Zones(zone_for_plot(2)).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
                    IIM(:,:,3) = single(Options.GoodVideoFrameGray);
            end

            if Options.ObjectsNumber > 0
                zone_for_plot = [
                    find(strcmp({Zones.name}, 'ObjectAllOut'))...
                    find(strcmp({Zones.name}, 'ObjectAllReal'))...
                    ]; 
                IIM(:,:,3) = Zones(zone_for_plot(1)).maskfilled*255 + Zones(zone_for_plot(2)).maskfilled*125 + IIM(:,:,3);
            end

            h = figure;
            imshow(uint8(IIM)); hold on;
            PlotArray(PlotArray < 1) = nan;
            plot(X, PlotArray, 'k.');

            answer = questdlg('Is it correct?', 'Arena with borders','Yes','No','Yes');
            switch answer
                case 'Yes'
                    prmt = 1;
                case 'No'
                    prmt = 0;
            end
            saveas(h, sprintf('%s\\%s_Main_Zones.png',PathOut, FilenameOut));
            delete(h);
        end
        % plot of all zones
%         for zone = 1:length(Zones)
%             if strcmp(Zones(zone).type, 'area')
%                 IIM(:,:,1) = round((Zones(zone).maskfilled*255 + single(Options.GoodVideoFrameGray))./2);
%                 IIM(:,:,2) = round(single(Options.GoodVideoFrameGray)./2);
%                 IIM(:,:,3) = round(single(Options.GoodVideoFrameGray)./2);
%                 imwrite(uint8(IIM), sprintf('%s\\%s_Zone_%s.png',PathOut, FilenameOut, Zones(zone).name));
%                 fprintf('Saving zones masks %d/%d\n', zone, length(Zones));
%             end
%         end
        fprintf('Saving preset file\n');
        save(sprintf('%s\\%s',Options.PathPreset, Options.FilenamePreset),'Options','ArenaAndObjects','Zones');
        fprintf('Analyze finished\n')
end
end

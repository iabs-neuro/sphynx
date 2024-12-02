function [x_transform, y_transform] = TrackTransformerFC(BodyPartsTracesMainX, BodyPartsTracesMainY, Options, Point, PathOut, Filename, readerobj)
% transform original trajectory from freezing chamber to real trajectory
% vvp. 20.03.23
% vvp. 21.11.24 implementation in Sphynx
PlotVideo = 0;
StartTime = 1;
x_original = BodyPartsTracesMainX(Point.Tailbase,:);
y_original = BodyPartsTracesMainY(Point.Tailbase,:);

%% local parameters
WidthReal = Options.WidthReal;
HeightReal = Options.HeightReal;
n_frames = length(x_original);
frames = linspace(1, n_frames, n_frames);

x_arena = [1,Options.Width,Options.Width,1,1];
y_arena = [1,1,Options.Height,Options.Height,1];
x_arena_real = x_arena/Options.Width*WidthReal;
y_arena_real = y_arena/Options.Height*HeightReal;
colorbase = parula(size(BodyPartsTracesMainX,1));

%% real trajectory of tail

% 2022 RNF
% xD = 1; %left-bottom corner
% yD = 216;
% xK = 165; %center-bottom corner
% yK = 216;
% xF = 165; %perspective point
% yF = 112;
% xO = 320; %rigt-bottom2 corner
% yO = 216;

% 2024 RNF (RFC)
xD = 1; %left-bottom corner
yD = 185;
xK = 165; %center-bottom corner
yK = 185;
xF = 165; %perspective point
yF = 110;
xO = 320; %rigt-bottom2 corner
yO = 185;

k_y5 = 0; %up line
B_y5 = 160;

% xH = 320; %right-bottom corner
% yH = 208;

k_y1 = (yD-yK)/(xD-xK); %bottom line
B_y1 = (yK*xD-yD*xK)/(xD-xK);
k_y4 = (yD-yF)/(xD-xF); %DF line
B_y4 = (yF*xD-yD*xF)/(xD-xF);
[xE,yE] = LinesPoint(k_y4,B_y4,k_y5,B_y5); %left-up corner
k_y7 = (yD-yE)/(xD-xE); %left line
B_y7 = (yE*xD-yD*xE)/(xD-xE);

k_y8 = -k_y4; %right line
B_y8 = yF - k_y8*xF;

% k_y8 = (yH-yF)/(xH-xF); %right line
% B_y8 = (yF*xH-yH*xF)/(xH-xF);

[xJ,yJ] = LinesPoint(k_y8,B_y8,k_y5,B_y5); %right-up corner
xH = 320;
yH = k_y8*xH+B_y8;

% interpolation of outborders
for k=1:n_frames
    if (y_original(k) >= k_y1*x_original(k)+B_y1) || (y_original(k) <= k_y5*x_original(k)+B_y5) || (y_original(k) <= k_y7*x_original(k)+B_y7) || (y_original(k) <= k_y8*x_original(k)+B_y8)
        x_original(k) = 0;
        y_original(k) = 0;
    end
end

x_original_int = interp1(frames(x_original ~=0), x_original(x_original ~=0), find(x_original == 0),'linear');
y_original_int = interp1(frames(y_original ~=0), y_original(y_original ~=0), find(y_original == 0),'linear');
x_original(x_original == 0) = x_original_int;
y_original(y_original == 0) = y_original_int;

x_transform = zeros(1,n_frames);
y_transform = zeros(1,n_frames);

A = sqrt((xD-xE)^2+(yD-yE)^2);
L = sqrt((xD-xF)^2+(yD-yF)^2);
C = L*(L-A)*HeightReal/A;
for k=1:n_frames
    k_y6 = (yF-(y_original(k)))/(xF-x_original(k));
    B_y6 = ((y_original(k))*xF-yF*x_original(k))/(xF-x_original(k));
    [xG,~] = LinesPoint(k_y6,B_y6,k_y1,B_y1);
    x_transform(k) = abs((xG-xD)/(xD-xK))*WidthReal/2;
    xx = (y_original(k)-B_y4)/k_y4;
    X = sqrt((xD-xx)^2+(yD-(y_original(k)))^2);
    y_transform(k) = C*(1/(L-X)-1/L);
end

% h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
h = figure;
plot(x_transform, y_transform, 'g', 'LineWidth', 1);
hold on;plot(x_arena_real,y_arena_real, 'k', 'LineWidth',3);
title('Real trajectory', 'Fontsize', 15);
saveas(h, sprintf('%s\\%s_real_trajectory_tailbase', PathOut, Filename), 'png');
saveas(h, sprintf('%s\\%s_real_trajectory_tailbase', PathOut, Filename), 'fig');
delete(h);

h = figure;
title('Real trajectory', 'Fontsize', 20);
hold on;imshow(Options.GoodVideoFrame,'InitialMagnification','fit');hold on;
hold on;plot(x_original,y_original, 'g');
% hold on;plot(x_arena,y_arena, 'k', 'LineWidth',3);
AreaX = [xD xE xJ xH xO];
AreaY = [yD yE yJ yH yO];
% AreaX = [xF xD xK xF xO];
% AreaY = [B_y5 yD yK yF yO];
patch(AreaX,AreaY,'green','EdgeColor','red','FaceColor','none','LineWidth',2);
% x_array = (1:320);
% plot(x_array,k_y1*x_array+B_y1);
saveas(h, sprintf('%s\\%s_cage_and_trajectory.png', PathOut, Filename));
saveas(h, sprintf('%s\\%s_cage_and_trajectory.fig', PathOut, Filename));
delete(h);

%% animation video plot (points)
if PlotVideo == 1
    MaxFrame = 1000;
    v = VideoWriter(sprintf('%s\\%s_track',PathOut, Filename),'MPEG-4');
    v.FrameRate = readerobj.FrameRate;
    open(v);
    h = waitbar(1/n_frames, sprintf('Plotting main video, frame %d of %d', 0,  n_frames));
%     for k=1:n_frames
    for k=1000:1200
        if mod(k,20) == 0
            h = waitbar(k/n_frames, h, sprintf('Plotting main video, frame %d of %d', k,  n_frames));
        end
        IM = read(readerobj,k+StartTime-1);
        BlackFrame = ones(Options.Height,Options.Width)*255;
        BlackFrame = uint8(BlackFrame);
        startf = max(1, k-MaxFrame);
        for point=startf:k
            BlackFrame = insertShape(BlackFrame,'filledcircle', [x_transform(point)*Options.Width/WidthReal (HeightReal-y_transform(point))*Options.Height/HeightReal 1],'Color',colorbase(3,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end
        BlackFrame = insertShape(BlackFrame,'filledcircle', [x_transform(k)*Options.Width/WidthReal (HeightReal-y_transform(k))*Options.Height/HeightReal 2],'Color','black', 'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        BlackFrame = insertShape(BlackFrame,'Polygon', [3 240 318 240 318 3 3 3], 'Color', 'red', 'LineWidth', 2, 'Opacity', 1, 'SmoothEdges', false);
        BlackFrame = insertShape(BlackFrame,'Line', [1 240 320 240], 'Color', 'blue', 'LineWidth', 2, 'Opacity', 1, 'SmoothEdges', false);
        
        for part=1:size(BodyPartsTracesMainX,1)
            IM = insertShape(IM,'filledcircle', [BodyPartsTracesMainX(part,k) BodyPartsTracesMainY(part,k) 2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end
        IM = insertShape(IM,'Polygon', [xD yD xE yE xJ yJ xH yH xO yO],'Color','red','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        IM = insertShape(IM,'Line', [xD yD xO yO],'Color','blue','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        
        IMM = [IM BlackFrame];
%         imshow(IMM);
        writeVideo(v,IMM);
    end
    close(v);
    delete(h);
end
end
function [dist, dist_v] = FearAnalyzer(PlotVideo,PathCSV,FilenameCSV,PathVideo,FilenameVideo,PathOut)

%% main parameters

if nargin < 6
    [FilenameCSV, PathCSV]  = uigetfile('*.csv','load the csv file','g:\_Projects\2023_Rogozhnikova\DLC\Train\');
    [FilenameVideo, PathVideo]  = uigetfile('*.wmv','load the VT file','g:\_Projects\2023_Rogozhnikova\VT\Train\');
    PathOut = 'g:\_Projects\2023_Rogozhnikova\RealTracks\';
    PlotVideo = 1;
end

% PlotVideo = 0;
BodyPartsNames = {'Nose','MiniScope','TailBase'};
ExtraLinesNumber = 0;
NoseXColumn = 2;
MiniScopeXColumn = 5;
TailBaseXColumn = 8;
MainBodyPart = 3;
BodyPartsOptions  = [NoseXColumn, MiniScopeXColumn, TailBaseXColumn];

LikelihoodThreshold = 0.95;
stance_height = 40;
axesFat = 2;
AxesColor = 'r';
LineColor = 'c';

WidthReal = 29; %in sm
HeightReal = 24; %in sm

MarkSize = 5;
colorbase = jet(length(BodyPartsNames));
MaxFrame = 30;
    
Screensize = get(0, 'Screensize');
FilenameOut = FilenameVideo(1:end-4);

%% loading data
% videotracking (csv)
file = readtable(sprintf('%s%s', PathCSV,FilenameCSV));
n_frames = size(file,1);

% video (wmv)
readerobj = VideoReader(sprintf('%s%s', PathVideo, FilenameVideo));
% vidFrames = read(readerobj);
FrameRate = get(readerobj, 'FrameRate');
numFrames = get(readerobj, 'NumFrames');
Height = get(readerobj, 'Height');
Width = get(readerobj, 'Width');
StartTime = 1;
EndTime = numFrames;
x_kcorr = 1;
SmoothWindow = FrameRate;

if abs(n_frames - numFrames)<3
    fprintf('Sync csv and wmv correct\n');
    n_frames = min(n_frames,numFrames);
    numFrames = min(n_frames,numFrames);
else
    fprintf('Sync csv and wmv not correct\n');
end
time = (1:numFrames)/FrameRate;

save(sprintf('%s\\WorkSpace_%s.mat',PathOut, FilenameOut));

%% all parts detection

BodyPartsX_bad = [];
BodyPartsY_bad = [];
BodyPartsLH = [];
for part=1:length(BodyPartsOptions)
    BodyPartsX_bad(part,:) = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)))*x_kcorr;
    BodyPartsY_bad(part,:) = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)+1));
    BodyPartsLH(part,:) = table2array(file(StartTime+ExtraLinesNumber:EndTime+ExtraLinesNumber,BodyPartsOptions(part)+2));
    x_nan(part,:) = find(isnan(BodyPartsX_bad(part,:))); 
    y_nan(part,:) = find(isnan(BodyPartsY_bad(part,:)));
    x(part,:) = BodyPartsX_bad(part,:); 
    y(part,:) = BodyPartsY_bad(part,:);
    x(part, x_nan(part,:)) = 0; 
    y(part, y_nan(part,:)) = 0;
    for frame=1:numFrames
        if BodyPartsLH(part, frame)<LikelihoodThreshold
            x(part, frame) = 0;
            y(part, frame) = 0;
        end
    end

    x_zero = find(x(part,:)==0);
    y_zero = find(y(part,:)==0);
%     length(x_zero)
%     length(y_zero)
    BodyPartsX_int(part,:)=interpolation_VP(x(part,:),x_zero); 
    BodyPartsY_int(part,:)=interpolation_VP(y(part,:),y_zero);
    BodyPartsX_int_sm(part,:) = smooth(BodyPartsX_int(part,:),SmoothWindow);
    BodyPartsY_int_sm(part,:) = smooth(BodyPartsY_int(part,:),SmoothWindow);

    h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
    plot(time,BodyPartsX_bad(part,:)); hold on;plot(time,BodyPartsX_int_sm(part,:),'r'); 
    title(sprintf('X: %s original vs %s smoothed and interpolated',string(BodyPartsNames(part)),string(BodyPartsNames(part))));
    
    hh = figure('Position', [1 1 Screensize(3) Screensize(4)]);
    plot(time,BodyPartsY_bad(part,:)); hold on;plot(time,BodyPartsY_int_sm(part,:),'r'); 
    title(sprintf('Y: %s original vs %s smoothed and interpolated',string(BodyPartsNames(part)),string(BodyPartsNames(part))));
    
    saveas(h, sprintf('%s\\%s_%s_X_coordinate.png', PathOut,FilenameOut, string(BodyPartsNames(part))));
    saveas(hh, sprintf('%s\\%s_%s_Y_coordinate.png', PathOut,FilenameOut, string(BodyPartsNames(part))));
    delete(h);delete(hh);
end

x_int_sm = BodyPartsX_int_sm(MainBodyPart,:);
y_int_sm = BodyPartsY_int_sm(MainBodyPart,:);

x_arena = [1,Width,Width,1,1];
y_arena = [1,1,Height,Height,1];
x_arena_real = x_arena/Width*WidthReal;
y_arena_real = y_arena/Height*HeightReal;
save(sprintf('%s\\WorkSpace_%s.mat',PathOut, FilenameOut));

%% searching of stances

stand_line  = BodyPartsY_int_sm(3,:)-BodyPartsY_int_sm(1,:);
stances_line(1:n_frames) = 0;
for i=1:n_frames
    if stand_line(i) >= stance_height
        stances_line(i) = 1;
    end
end

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
plot(time,stand_line, 'r','LineWidth', 1);hold on;
plot(time, ones(1,n_frames)*40, 'g','LineWidth', 2);hold on;
plot(time, stances_line*40, 'b','LineWidth', 3);hold on;
title('Tailbase and nose coordinate y difference', 'FontSize', 20);
saveas(h, sprintf('%s\\%s_Stances.png', PathOut,FilenameOut));
delete(h);
 
%% reading good frame for finding arena coordinates

gframe = round(numFrames/2);
% prmt = 0;
% while prmt==0    
    vidFrames = read(readerobj,gframe);
%     h=figure;
    IM = vidFrames(:,:,1);
%     imshow(IM);hold on;
%     answer = questdlg('Is it good frame?', 'Freezing chamber main axes searching',	'Yes','No','Yes');
%     switch answer
%         case 'Yes'      
%             prmt = 1;            
%         case 'No'        
%             prmt = 0;
%             gframe=gframe+100;            
%     end
%     delete(h);
% end

%% real trajectory of tail

% % for Rogozhnilova 2023 Train
% xD = 1; %left-bottom corner
% yD = 216;
% xK = 165; %center-bottom corner
% yK = 216;
% xF = 165; %perspective point
% yF = 112;
% xO = 320; %rigt-bottom2 corner
% yO = 216;
% k_y5 = 0; %up line
% B_y5 = 180;

% % for Rogozhnilova 2023 Test
% xD = 1; %left-bottom corner
% yD = 190;
% xK = 159; %center-bottom corner
% yK = 190;
% xF = 159; %perspective point
% yF = 110;
% xO = 320; %rigt-bottom2 corner
% yO = 190;
% k_y5 = 0; %up line
% B_y5 = 162;

% % for Rogozhnilova 2023 Test 2
% xD = 1; %left-bottom corner
% yD = 193;
% xK = 159; %center-bottom corner
% yK = 193;
% xF = 159; %perspective point
% yF = 114;
% xO = 320; %rigt-bottom2 corner
% yO = 193;
% k_y5 = 0; %up line
% B_y5 = 167;
% 
% for Rogozhnilova 2023 2 group
xD = 1; %left-bottom corner
yD = 180;
xK = 164; %center-bottom corner
yK = 180;
xF = 164; %perspective point
yF = 112;
xO = 320; %rigt-bottom2 corner
yO = 180;
k_y5 = 0; %up line
B_y5 = 158;

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
    if (y_int_sm(k) >= k_y1*x_int_sm(k)+B_y1) || (y_int_sm(k) <= k_y5*x_int_sm(k)+B_y5) || (y_int_sm(k) <= k_y7*x_int_sm(k)+B_y7) || (y_int_sm(k) <= k_y8*x_int_sm(k)+B_y8)
        x_int_sm(k) = 0;
        y_int_sm(k) = 0;       
    end
end

x_int_sm_zero = find(x_int_sm==0);
y_int_sm_zero = find(y_int_sm==0);
x_int_sm=interpolation_VP(x_int_sm,x_int_sm_zero); 
y_int_sm=interpolation_VP(y_int_sm,y_int_sm_zero);

A = sqrt((xD-xE)^2+(yD-yE)^2);
L = sqrt((xD-xF)^2+(yD-yF)^2);
C = L*(L-A)*HeightReal/A;
for k=1:n_frames  
    k_y6 = (yF-(y_int_sm(k)))/(xF-x_int_sm(k));
    B_y6 = ((y_int_sm(k))*xF-yF*x_int_sm(k))/(xF-x_int_sm(k));
    [xG,~] = LinesPoint(k_y6,B_y6,k_y1,B_y1);
    x_real(k) = abs((xG-xD)/(xD-xK))*WidthReal/2;
    xx = (y_int_sm(k)-B_y4)/k_y4;
    X = sqrt((xD-xx)^2+(yD-(y_int_sm(k)))^2); 
    y_real(k) = C*(1/(L-X)-1/L);
end

save(sprintf('%s\\WorkSpace_%s.mat',PathOut, FilenameOut));
%% searching easy kinematics

% distance calculation
dist = zeros(1, 1);
for i=2:n_frames
    dist = dist + sqrt((x_real(i)-x_real(i-1))^2+(y_real(i)-y_real(i-1))^2);
end
dist = round(dist/100,2); %in meters

% velocity calculation
vel(1:n_frames) = 0;
for i=2:n_frames
    vel(i)= sqrt((x_real(i)-x_real(i-1))^2+(y_real(i)-y_real(i-1))^2)*FrameRate;
end
vel(1) = vel(2);

vel_int=interpolation_VP(vel,find(vel>25));
x_int_sm = interpolation_VP(x_int_sm,find(vel>25));
y_int_sm = interpolation_VP(y_int_sm,find(vel>25));
x_real = interpolation_VP(x_real,find(vel>25));
y_real = interpolation_VP(y_real,find(vel>25));

vel_sm = smooth(vel_int,SmoothWindow);
dist_v = sum(vel_sm(find(vel_sm>5)))/n_frames*300;
dist_v = round(dist_v/100,2); %in meters

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
plot(x_real, y_real, 'g', 'LineWidth', 1);
hold on;plot(x_arena_real,y_arena_real, 'k', 'LineWidth',3);
title('Real trajectory', 'Fontsize', 15);
saveas(h, sprintf('%s\\RealTrajectory\\%s_real_trajectory_tailbase', PathOut, FilenameOut), 'png');
delete(h);

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
title('Real trajectory', 'Fontsize', 20);
hold on;imshow(IM,'InitialMagnification','fit');hold on;
hold on;plot(x_int_sm,y_int_sm, 'g');
hold on;plot(x_arena,y_arena, 'k', 'LineWidth',3); 
AreaX = [xD xE xJ xH xO];
AreaY = [yD yE yJ yH yO];
patch(AreaX,AreaY,'green','EdgeColor','red','FaceColor','none','LineWidth',2);
x_array = (1:320);
plot(x_array,k_y1*x_array+B_y1);
saveas(h, sprintf('%s\\RealTrajectory\\%s_cage_and_trajectory.png', PathOut, FilenameOut));
delete(h);

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
histogram(vel_sm,100);
title(sprintf('Histogram of velocity. Total distance = %2.2f m.\n Total distance (5 m/s<v<25 m/s) = %2.2f m.', dist, dist_v));
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\%s_velocity_hist.png', PathOut, FilenameOut));
delete(h);

h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
plot(time, vel, 'b');hold on;
plot(time, vel_sm, 'r');
title('Velocity of tailbase vs smooth');
saveas(h, sprintf('%s\\%s_velocity_tailbase.png', PathOut,FilenameOut));
delete(h);

%% animation video plot (points)
if PlotVideo == 1 
    v = VideoWriter(sprintf('%s\\video_real\\%s_track_F',PathOut, FilenameOut),'MPEG-4');
    v.FrameRate = FrameRate;
    open(v);
    h = waitbar(1/n_frames, sprintf('Plotting main video, frame %d of %d', 0,  n_frames));
%     for k=1:n_frames
    for k=1:500
        if mod(k,20) == 0
            h = waitbar(k/n_frames, h, sprintf('Plotting main video, frame %d of %d', k,  n_frames));  
        end
        IM = read(readerobj,k+StartTime-1);
        BlackFrame = ones(Height,Width)*255;
        BlackFrame = uint8(BlackFrame);
        startf = max(1, k-MaxFrame);
        for point=startf:k
            BlackFrame = insertShape(BlackFrame,'filledcircle', [x_real(point)*Width/WidthReal (HeightReal-y_real(point))*Height/HeightReal 2],'Color','green','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            for part=1:length(BodyPartsOptions)
                IM = insertShape(IM,'filledcircle', [BodyPartsX_int_sm(3,point) BodyPartsY_int_sm(3,point) 2],'Color','green','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            end
        end
        BlackFrame = insertShape(BlackFrame,'filledcircle', [x_real(k)*Width/WidthReal (HeightReal-y_real(k))*Height/HeightReal MarkSize],'Color',colorbase(3,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        BlackFrame = insertShape(BlackFrame,'Polygon', [3 240 318 240 318 3 3 3],'Color','red','LineWidth',2, 'Opacity', 1, 'SmoothEdges', false);
        BlackFrame = insertShape(BlackFrame,'Line', [1 240 320 240],'Color','blue','LineWidth',2, 'Opacity', 1, 'SmoothEdges', false);

        for part=1:length(BodyPartsOptions)
            IM = insertShape(IM,'filledcircle', [BodyPartsX_int_sm(part,k) BodyPartsY_int_sm(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
        end   
        IM = insertShape(IM,'Polygon', [xD yD xE yE xJ yJ xH yH xO yO],'Color','red','LineWidth',2, 'Opacity', 1, 'SmoothEdges', false);
        IM = insertShape(IM,'Line', [xD yD xO yO],'Color','blue','LineWidth',2, 'Opacity', 1, 'SmoothEdges', false);

        IMM = [IM BlackFrame];
    %     imshow(IMM);
        writeVideo(v,IMM);
    end
    close(v);
    delete(h);
end

csvwrite(sprintf('%s\\CSV\\%s_coord.csv',PathOut, FilenameVideo(1:length(FilenameVideo)-4)), [x_real; y_real]');
save(sprintf('%s\\WorkSpace_%s.mat',PathOut, FilenameVideo(1:length(FilenameVideo)-4)));
end


%% drawing amanual lines 
% [kx,Bx,ky,By,kz,Bz,x_axesX,x_axesY,x_axesZ,y_axesX,y_axesY,y_axesZ] = AxesDraw(IM,AxesColor,axesFat);
% 
% %drawing line for square of level of mouse centoid
% text = 'Draw y1 line (bottom border of mouse trajectory)';
% [k_y1,B_y1,x_y1,y_y1] = LineDraw(IM,LineColor,axesFat, text);
% % if position_observer == 1
%     xD = 1; 
% % else
% %     xD = Width;
% % end
% yD = k_y1*xD+B_y1;
% 
% %drawing center vertical line
% text = 'Draw y3 line (center vertical line)';
% [k_y3,B_y3,x_y3,y_y3] = LineDraw(IM,LineColor,axesFat,text);
% 
% %drawing upper line
% text = 'Draw y2 line (upper perspective line)';
% [k_y2,B_y2,x_y2_bad,~] = LineDraw(IM,LineColor,axesFat,text);
% % if position_observer == 1
%     x_y2 = min(x_y2_bad):round(mean(x_y3)); y_y2 = k_y2*x_y2+B_y2;
% % else
% %     x_y2 = round(mean(x_y3)):max(x_y2_bad); y_y2 = k_y2*x_y2+B_y2;
% % end
% 
% %finding central perspective point (y2 and axesX)
% [xF1,yF1] = LinesPoint(k_y2,B_y2,kx,Bx);
% [xF2,yF2] = LinesPoint(k_y2,B_y2,k_y3,B_y3);
% [xF3,yF3] = LinesPoint(k_y3,B_y3,kx,Bx);
% xF = (xF1+xF2+xF3)/3;
% yF = (yF1+yF2+yF3)/3;
% 
% %finding  point (y1 and y3)
% [xK,yK] = LinesPoint(k_y1,B_y1,k_y3,B_y3);
% 
% %drawing line for real square for mouse
% k_y4 = (yF-yD)/(xF-xD);
% B_y4 = (yD*xF-yF*xD)/(xF-xD);
% % if position_observer == 1
%     x_y4 = 1:round(mean(x_y3)); y_y4 = k_y4*x_y4+B_y4;
% % else
% %     x_y4 = round(mean(x_y3)):Width; y_y4 = k_y4*x_y4+B_y4;
% % end
% 
% %finding point (y4 and axesZ)
% [xE,yE] = LinesPoint(k_y4,B_y4,kz,Bz);
% 
% %finding line for real square (upper)
% k_y5 = ky;
% B_y5 = -ky*xE+yE;
% % if position_observer == 1
%     x_y5 = xE:round(mean(x_y3)); 
% % else
% %     x_y5 = round(mean(x_y3)):xE;
% % end
% y_y5 = k_y5*x_y5+B_y5;
% 
% [xM,yM] = LinesPoint(k_y5,B_y5,k_y3,B_y3);

%% proof of realtracking
% imshow(IM);
% [x, y] = ginput;  
% test_x1 = round(x(1)):round(x(2)); 
% k = (y(1)-y(2))/(x(1)-x(2));
% B = (y(2)*x(1)-y(1)*x(2))/(x(1)-x(2));
% test_y1 = k*test_x1+B;
% hold on;plot(test_x1, test_y1, LineColor, 'LineWidth',2);
% 
% [x, y] = ginput;  
% test_x2 = round(x(1)):round(x(2)); 
% k = (y(1)-y(2))/(x(1)-x(2));
% B = (y(2)*x(1)-y(1)*x(2))/(x(1)-x(2));
% test_y2 = k*test_x2+B;
% hold on;plot(test_x2, test_y2, LineColor, 'LineWidth',2);
% 
% for k=1:length(test_x1) 
% %     y_real(k) = abs((Height-y_int_sm(k)-yD)/(yD-yE))*HeightReal;
%     k_y5 = (yF-(test_y1(k)))/(xF-test_x1(k));
%     B_y5 = ((test_y1(k))*xF-yF*test_x1(k))/(xF-test_x1(k));
%     [xG,yG] = LinesPoint(k_y5,B_y5,k_y1,B_y1);
%     x_real_t1(k) = abs((xG-xD)/(xD-xK))*WidthReal/2;
%     x = (test_y1(k)-B_y4)/k_y4;
%     X = sqrt((xD-x)^2+(yD-(test_y1(k)))^2); 
%     y_real_t1(k) = C*(1/(L-X)-1/L);
% end
% 
% for k=1:length(test_x2)   
% %     y_real(k) = abs((Height-y_int_sm(k)-yD)/(yD-yE))*HeightReal;
%     k_y5 = (yF-(test_y2(k)))/(xF-test_x2(k));
%     B_y5 = ((test_y2(k))*xF-yF*test_x2(k))/(xF-test_x2(k));
%     [xG,yG] = LinesPoint(k_y5,B_y5,k_y1,B_y1);
%     x_real_t2(k) = abs((xG-xD)/(xD-xK))*WidthReal/2;
%     x = (test_y2(k)-B_y4)/k_y4;
%     X = sqrt((xD-x)^2+(yD-(test_y2(k)))^2); 
%     y_real_t2(k) = C*(1/(L-X)-1/L);
% end
% 
% h = figure;
% plot(x_real_t1,y_real_t1,'r');hold on;
% plot(x_real_t2,y_real_t2, 'g');
% 
% saveas(h, sprintf('%s\\%s_test.png', PathOut, FilenameOut));
% delete(h);

% %area distribution
% time_zone(1:3,1:length(time_line)) = 0;
% for k=1:length(time_line)
%     for i=frame_line(k):frame_line(k+1)
%         if x_real(i)>=2/3*WidthReal
%             time_zone(1,k) = time_zone(1,k)+1;
%         elseif x_real(i)>=1/3*WidthReal && x_real(i)<2/3*WidthReal
%             time_zone(2,k) = time_zone(2,k)+1;
%         else
%             time_zone(3,k) = time_zone(3,k)+1;
%         end
%     end
% end
% time_zone = time_zone/FrameRate;

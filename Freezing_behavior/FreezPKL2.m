clear all;
%function m=FreezPKL2(filename, path,x0,y0,L0,L,frame_rate)
%% 
%if nargin < 1 
    [filename, path]  = uigetfile('*.csv','load the centoid file','g:\_Projects\_APTSD [2022]\APTSD\Video\PKL\'); 
%end
file = load(sprintf('%s%s', path, filename));
%%
start = 2; %start and end of the video's interest 
endd = size(file,1);
% affin = 71.92/54.29; %affine transformation for correction of the length
affin = 1;
frame_rate = 20; %framerate of video
L0 = 0.13*5; %diametr of arena in meters
L = 447; %diametr of arena in pixels
mov_thres = 0.2; %movement trhesold in sm/s
MinLengthFreez = 3;
MaxLengthFreez = 10;
x_bad = file(start:endd,2).*affin; 
y_bad = file(start:endd,3); 
zone = file(start:endd,4);
n_frames=length(x_bad); % number of frames

% TimeAct = 2;
% TimeSilenceAct = 2;

x_nan = find(isnan(x_bad)); 
y_nan = find(isnan(y_bad));%array of NaN in x_bad and y_bad

x = x_bad; y = y_bad;%new good arrays
x(x_nan) = 0; y(y_nan) = 0;% fill NaN with zeros
x_zero = find(x==0); y_zero = find(y==0);%array of zero in x/y
x_int=interpolation_VP(x,x_zero); %interpolation of zeros
y_int=interpolation_VP(y,y_zero);

for i=1:endd-start+1
    time_x(i) = (start+i-1)/frame_rate;
end

%% 
% figure;plot(time_x,x); hold on;plot(time_x,x_int,'r'); title('x vs x inerpolate');
% figure;plot(time_x,y); hold on;plot(time_x,y_int,'r'); title('y vs y inerpolate');

% x_int_sm = smooth(x_int,40);
% y_int_sm = smooth(y_int,40);
x_int_sm = smoothdata(x_int,'movmean',10);
y_int_sm = smoothdata(y_int,'movmean',10);
% figure;plot(time_x,x_int);hold on;plot(time_x,x_int_sm,'r'); title('x inerpolate vs x smooth');
% figure;plot(time_x,y_int);hold on;plot(time_x,y_int_sm,'r'); title('y inerpolate vs y smooth');

% R=sqrt((x_int_sm).^2+(y_int_sm).^2); % distance between arrow and center coordinates
% figure;plot(time_x,R); title('R');

% calculate the average speed
for i=1:n_frames-1
    speedx(i) = (x_int_sm(i+1)-x_int_sm(i))*frame_rate;
    speedy(i) = (y_int_sm(i+1)-y_int_sm(i))*frame_rate;
    speed(i) = sqrt(speedx(i)^2+speedy(i)^2);
end

%searching of freez time
speed_sm = smoothdata(speed,5);
speed_in_sm = speed_sm*L0/L*100;
freez(1:n_frames-1) = 0;
for i = 1:n_frames-1
    if abs(speed_in_sm(i)) < mov_thres
        freez(i) = 1;    
    end
end

% filtering
freez_filt0 = MyFilt1(freez,MinLengthFreez, 0);
freez_filt1 = MyFilt1(freez_filt0,MaxLengthFreez, 1);

%calculating time parameters of freezing
[freez_ref, freez_ref_number, freez_ref_time, freez_ref_count, freez_ref_frame_in, freez_ref_frame_out] = RefineLine(freez_filt1, 0, 0);

%plot raw and ref freez signal
freez_ref_plot = freez_ref;
freez_ref_plot(find(freez_ref_plot == 0)) = NaN;
numFramesV=n_frames-1;
time2 = linspace(1,numFramesV,numFramesV);

h = figure;
title('Raw and refined freez line','FontSize', 15);
xlabel('Frame, 20Hz','FontSize', 15);hold on;
ylabel('Freezing acts/Motion index','FontSize', 15);hold on;
plot(time2,speed, 'b');hold on;
plot(1:length(freez),freez.*20 ,'g','LineWidth', 2);hold on;
plot(1:length(freez_ref),freez_ref.*(20+3) ,'c','LineWidth', 2);    
legend('Motion index','Freez raw','Freez refine');
saveas(h,fullfile(path, sprintf('%s_FreezRawVsRef_%d_%d.png',filename(1:end-4),MinLengthFreez,MaxLengthFreez)));
saveas(h,fullfile(path, sprintf('%s_FreezRawVsRef_%d_%d.fig',filename(1:end-4),MinLengthFreez,MaxLengthFreez)));
delete(h);

% [Acts, freez_number, ~, Act_duration, ~, ~] = RefineLine(freez, TimeAct, TimeSilenceAct);
% [Acts, ActsNumber] = ActFinder(freez_ref, TimeAct,TimeSilenceAct);

PrcntFreez = freez_ref_time*60*20/n_frames*100;
freez_ref(end+1) = freez_ref(end);
speed_in_sm(end-1) = speed_in_sm(end);
csvwrite(sprintf('%s\\%s_Freezing_%d_%d_%g.csv',path,filename(1:end-4),MinLengthFreez,MaxLengthFreez,mov_thres), freez_ref');
csvwrite(sprintf('%s\\%s_MotionIndext_speed_%d_%d_%g.csv',path,filename(1:end-4),MinLengthFreez,MaxLengthFreez,mov_thres), speed_in_sm');


%% zones analyze
%%
zone_ref = zone;
zone_ref(find(zone==1)) = 0;
zone_ref(find(zone==2)) = 1;
csvwrite(sprintf('%s\\%s_Zones.csv',path,filename(1:end-4)), zone_ref');

% figure;plot(time_x(1:n_frames-1),speed*L0/L*100);hold on;plot(time_x(1:n_frames-1),speed_sm*L0/L*100,'r'); title('speed vs speed smooth');xlabel('time, s'); ylabel('speed, sm/s');hold on;
% plot(time_x(1:n_frames-1),freez ,'g','LineWidth', 2);hold on; plot(time_x(1:n_frames-1),Acts*2 ,'k','LineWidth', 2)
% 
% figure; hist(Act_duration/frame_rate,100);title('histogram of freez'); xlabel('time of freez, s'); ylabel('Number, s');hold on;

% csvwrite(sprintf('%s%s_MovThres_%g.csv',path,filename,mov_thres), Acts');
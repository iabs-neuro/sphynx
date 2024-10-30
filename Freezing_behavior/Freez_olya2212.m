% clear all;
%load line of freezing 
[FilenameFreez, PathFreez]  = uigetfile('*.csv','load the freezing file','D:\_projects\Olya\Tanya_olya\Индукция_ПТСР_Обучение_УРЗ\');
freez_raw = load(sprintf('%s%s', PathFreez, FilenameFreez));
LengthName = length(FilenameFreez);
filenameout = FilenameFreez(LengthName-19:LengthName-18);
%all vital parameters (all time in seconds)
FrameRateFreez = 30;
FrameRateNeuro = 5;
RateRatio = round(FrameRateFreez/FrameRateNeuro);
MinLengthFreez = 5;%change to seconds
MaxLengthFreez = 5;

neuro0_mean = 1;
neuro1_mean = 2;

%calculating time parameters of freezing
[freez_ref, freez_ref_number, freez_ref_time, freez_ref_count, freez_ref_frame_in, freez_ref_frame_out] = RefineLine(freez_raw, MinLengthFreez, MaxLengthFreez);

%make freez 5Hz again
k=1;
count=1;
summa=0;
for i=1:length(freez_ref)
    if count == RateRatio        
        freez_5hz(k) = round(summa/RateRatio);
        summa=0;
        count=0;
        k=k+1;
    end
    summa = summa + freez_ref(i);
    count = count+1;
end

%ready freez data: Hz like neuro, correct time
frames = length(freez_5hz);
freez = freez_5hz(1:frames);

%plot raw freez signal
% h = figure;
% title(FilenameFreez(1),'FontSize', 15);
% xlabel('Frame','FontSize', 15); 
% ylabel('Freezing acts','FontSize', 15);hold on;
% plot(1:length(freez_raw),freez_raw.*neuro0_mean ,'g','LineWidth', 2);hold on;
% plot(1:length(freez_raw),freez_ref.*neuro1_mean ,'c','LineWidth', 2);
% legend('freez raw','freez refine');
% saveas(h,fullfile(PathFreez, sprintf('%s_FreezRawVsRef.fig',FilenameFreez(1))));
% delete(h);

%searching of freezing acts parameters
[freez_act] = StatLine(freez,1);
[freez_gap] = StatLine(freez,0);

%plot and save hist
h = figure('Position', get(0, 'Screensize'));
hist(freez_act,max(freez_act));
title(sprintf('Distribution of freezing time, %s',FilenameFreez(1)), 'FontSize', 18);
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\%s_FreezTime.png',PathFreez,filenameout));         
% delete(h); 

h = figure('Position', get(0, 'Screensize'));
hist(freez_gap,max(freez_gap));
title(sprintf('Distribution of gap between freezing, %s',FilenameFreez(1)), 'FontSize', 18);
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\%s_GapTime.png',PathFreez,filenameout));         
% delete(h); 

%filtering
freez_filt0 = MyFilt1(freez,FrameRateNeuro, 0);
freez_filt1 = MyFilt1(freez_filt0,2, 1);

f = figure;
title(FilenameFreez(1),'FontSize', 15);
xlabel('Time, s','FontSize', 15);
ylabel('dF/F','FontSize', 15);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez.*neuro0_mean ,'g','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez_filt1.*neuro1_mean ,'c','LineWidth', 2);hold on;
legend('freezing','freezing filtered');
saveas(f,fullfile(PathFreez, sprintf('%s_FreezVsFreezFilt.fig',filenameout)));
% delete(f);

csvwrite(fullfile(PathFreez, sprintf('%s_FreezFilt.csv',filenameout)), freez_filt1');

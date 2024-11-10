% function [freez_act, freez_gap] = FreezKiller(PathFreez,FilenameFreez,PathNeuro,FilenameNeuro,start_neuro)
%load line of freezing 
[FilenameFreez, PathFreez]  = uigetfile('*.csv','load the freezing file','D:\_projects\Olya\Tanya_olya\Индукция_ПТСР_Обучение_УРЗ\');
freez_raw = load(sprintf('%s%s', PathFreez, FilenameFreez));

%load neuro data
[FilenameNeuro, PathNeuro]  = uigetfile('*.csv','load the neuro file','C:\Plusnin\_PROJECTS\Olya\CG-FR_data\Ca_data\Predexp\');
neuro = load(sprintf('%s%s', PathNeuro, FilenameNeuro));

%all vital parameters (all time in seconds)
FrameRateFreez = 30;
FrameRateNeuro = 5;
RateRatio = round(FrameRateFreez/FrameRateNeuro);
TimeAct = 1; 
TimeSilenceAct = 1;
TimeBeforeAct = 2;
TimeAfterAct = 8;
MinLengthFreez = 5;%change to seconds
MaxLengthFreez = 5;

start_neuro = 30;
end_neuro = length(neuro);
neuro0 = neuro(start_neuro:end_neuro,2); neuro0_mean = mean(neuro0);
neuro1 = neuro(start_neuro:end_neuro,3); neuro1_mean = mean(neuro1);
frames = length(neuro0);

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
freez = freez_5hz(1:frames);

%plot raw freez signal
h = figure;
title(FilenameNeuro(1:2),'FontSize', 15);
xlabel('Frame','FontSize', 15); 
ylabel('Freezing acts','FontSize', 15);hold on;
plot(1:length(freez_raw),freez_raw.*neuro0_mean ,'g','LineWidth', 2);hold on;
plot(1:length(freez_raw),freez_ref.*neuro1_mean ,'c','LineWidth', 2);
legend('freez raw','freez refine');
% saveas(h,fullfile(PathFreez, sprintf('%s_FreezRawVsRef.fig',FilenameNeuro(1:2))));
% delete(h);

%searching of freezing acts parameters
[freez_act] = StatLine(freez,1);
[freez_gap] = StatLine(freez,0);
% freez_act = freez_act./FrameRateNeuro;
% freez_gap = freez_gap./FrameRateNeuro;

%plot and save hist
h = figure('Position', get(0, 'Screensize'));
hist(freez_act,max(freez_act));
title(sprintf('Distribution of freezing time, %s',FilenameNeuro(1:2)), 'FontSize', 18);
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\%s_FreezTime.png',PathFreez,FilenameNeuro(1:2)));         
delete(h); 

h = figure('Position', get(0, 'Screensize'));
hist(freez_gap,max(freez_gap));
title(sprintf('Distribution of gap between freezing, %s',FilenameNeuro(1:2)), 'FontSize', 18);
F = getframe(h);
imwrite(F.cdata, sprintf('%s\\%s_GapTime.png',PathFreez,FilenameNeuro(1:2)));         
delete(h); 

hh = figure;
title(FilenameNeuro(1:2),'FontSize', 15);
xlabel('Time, s','FontSize', 15); 
ylabel('dF/F','FontSize', 15);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro0,'b','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro1,'r','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez.*neuro0_mean ,'g','LineWidth', 2);hold on;
legend('BrainRegion0','BrainRegion1', 'freezing');
saveas(hh,fullfile(PathFreez, sprintf('%s_FreezVsNeuro.fig',FilenameNeuro(1:2))));
delete(hh);

%filtering
freez_filt0 = MyFilt1(freez,FrameRateNeuro, 0);
freez_filt1 = MyFilt1(freez_filt0,2, 1);

f = figure;
title(FilenameNeuro(1:2),'FontSize', 15);
xlabel('Time, s','FontSize', 15); 
ylabel('dF/F','FontSize', 15);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro0,'b','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro1,'r','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez.*neuro0_mean ,'g','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez_filt1.*neuro1_mean ,'c','LineWidth', 2);hold on;
legend('BrainRegion0','BrainRegion1', 'freezing','freezing ref median');
saveas(f,fullfile(PathFreez, sprintf('%s_FreezVsFreezFilt.fig',FilenameNeuro(1:2))));
delete(f);

%searching of good acts (2s+8s)
[Acts_mask, ActsNumber] = ActFinder(freez_filt1,TimeAct*FrameRateNeuro,TimeSilenceAct*FrameRateNeuro);
[Acts, ~] = ActFinder2(freez_filt1,TimeAct*FrameRateNeuro,TimeSilenceAct*FrameRateNeuro);

f = figure;
title(FilenameNeuro(1:2),'FontSize', 15);
xlabel('Time, s','FontSize', 15); 
ylabel('dF/F','FontSize', 15);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro0'.*Acts_mask,'b','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro1'.*Acts_mask,'r','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez_filt1.*neuro1_mean ,'c','LineWidth', 2);hold on;
legend('BrainRegion0','BrainRegion1', 'freezing acts');
saveas(f,fullfile(PathFreez, sprintf('%s_FreezingActs.fig',FilenameNeuro(1:2))));
delete(f);

Neuro0_mask = {};
FrameZero(1:size(Acts,1))=0;
h = figure;
title(FilenameNeuro(1:2),'FontSize', 15);
xlabel('Time, frame','FontSize', 15); 
ylabel('zscored dF/F','FontSize', 15);hold on;
for i = 1:size(Acts,1)
    FrameStart = max(1, Acts(i,1)-TimeBeforeAct*FrameRateNeuro);
    FrameEnd = min(Acts(i,1)+TimeAfterAct*FrameRateNeuro-1,frames);
    FrameZero(i) = Acts(i,1);
    Neuro0_mask{i} = zscore(neuro1(FrameStart:FrameEnd));
    Neuro0_mask{i} = Neuro0_mask{i}-Neuro0_mask{i}(FrameZero(i)-FrameStart+1);    
%     plot(-(FrameZero-FrameStart):FrameEnd-FrameZero,zscore(neuro1(FrameStart:FrameEnd)-neuro1(FrameZero)),'b','LineWidth', 2);hold on;
    plot(-(FrameZero(i)-FrameStart):FrameEnd-FrameZero(i),Neuro0_mask{i},'b','LineWidth', 2);hold on;
end
saveas(h,fullfile(PathFreez, sprintf('%s_NeuroFreez.fig',FilenameNeuro(1:2))));
delete(h);
% plot(zeros(100),linspace(-3,3),'r-','LineWidth', 2);

h=figure;
Neuro0_mask2 = cell2mat(Neuro0_mask)';
stdshade(Neuro0_mask2,  0.5, 'b',1:50, 1);
saveas(h,fullfile(PathFreez, sprintf('%s_NeuroMean.fig',FilenameNeuro(1:2))));
delete(h);
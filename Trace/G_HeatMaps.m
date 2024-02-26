%% load data
clc;clear;
load ca1_habitauion_heatmap;
for s=1:3
    baseline_mean=nanmean(habituation.all_baseline_response(:,:,s),2);
    trace_responsez(:,:,s)=(habituation.all_trace_response(:,:,s)-baseline_mean);  
    tone_responsez(:,:,s)=(habituation.all_tone_response(:,:,s)-baseline_mean);
    whole_responsez(:,:,s)=(habituation.all_whole_response(:,:,s)-baseline_mean);  
end

trace_responsezmean=nanmean(trace_responsez,3);
tone_responsezmean=nanmean(tone_responsez,3);
whole_responsezmean=nanmean(whole_responsez,3);
%% plot CS-only
xline1 = 20*30; 
xline2 = 20*30 + 30 * 30;
xline3 = 20*30 + 50*30; 

[c1,~]=colorGradient(RGB('red'),RGB('darkred'),64*2); % red to black
[c2,~]=colorGradient(RGB('orange'),RGB('red'),64*0.5); % yellow to red
[c3,~]=colorGradient(RGB('white'), RGB('orange'),64*0.5); % blue to yellow
[c4,~]=colorGradient(RGB('blue'),RGB('white'),64);
[c5,~]=colorGradient(RGB('midnightblue'),RGB('blue'),64*2);
c = [c5;c4;c3;c2;c1];
clear valmax;clear indmax;clear indsort;
figure('Position',[300, 100, 320,296]);
[valmax,indmax]=max(tone_responsezmean(tone_only,:),[],2);% indmax is represent the frame ID for max response.
% sort the cell order by the earlist frame ID with max response.
[~,indsort]=sort(indmax); 
plot_tone_id=tone_only(indsort);
imagesc(whole_responsezmean(plot_tone_id,:));
colormap(c); 
caxis([-10 10]);
%  colorbar;
hold on;
xline( xline1, '--k','linewidth',1); xline(xline2,'--k','linewidth',1);xline(xline3,'--k','linewidth',1); xticks([]);
%% plot CS-trace
clear valmax;clear indmax;clear indsort;
tone_trace_resp=whole_responsezmean(:,601:2100);
figure('Position',[300, 100, 320,158]);
[valmax,indmax]=max(tone_trace_resp(habituation.habi_all_persistent3,:),[],2);% indmax is represent the frame ID for max response.
% sort the cell order by the earlist frame ID with max response.
[~,indsort]=sort(indmax); 
plot_tone_id=habituation.habi_all_persistent3(indsort);
imagesc(whole_responsezmean(plot_tone_id,:));
colormap(c); 
caxis([-10 10]);
%colorbar;
hold on;
xline( xline1, '--k','linewidth',1); xline(xline2,'--k','linewidth',1);xline(xline3,'--k','linewidth',1); xticks([]);

%% plot trace-only cell
clear valmax;clear indmax;clear indsort;
figure('Position',[300, 100, 320,391]);
[valmax,indmax]=max(trace_responsezmean(trace_only,:),[],2);% indmax is represent the frame ID for max response.
% sort the cell order by the earlist frame ID with max response.
[~,indsort]=sort(indmax); 
plot_tone_id=trace_only(indsort);
imagesc(whole_responsezmean(plot_tone_id,:));
colormap(c); 
caxis([-10 10]);
% colorbar;
hold on;
xline( xline1, '--k','linewidth',1); xline(xline2,'--k','linewidth',1);xline(xline3,'--k','linewidth',1); xticks([]);





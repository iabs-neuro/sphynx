clear all;close all; 
%load line of freezing 
[FilenameFreez, PathFreez]  = uigetfile('*.csv','load the freezing file','I:\SCRIPTS_for_VT_NV_disk\CG-FR_data\behav\Test');
freez_raw = load(sprintf('%s%s', PathFreez, FilenameFreez));

%load neuro data
[FilenameNeuro, PathNeuro]  = uigetfile('*.csv','load the neuro file','I:\SCRIPTS_for_VT_NV_disk\CG-FR_data\Ca_data\');
neuro = load(sprintf('%s%s', PathNeuro, FilenameNeuro));

%all vital parameters
FrameRateFreez = 30;
FrameRateNeuro = 5;
RateRatio = round(FrameRateFreez/FrameRateNeuro);
n_frames_after = 5;
n_frames_before = 10;
MinLengthFreez = 5;
MaxLengthFreez = 5;

start_neuro = 20;
end_neuro = length(neuro);
neuro0 = neuro(start_neuro:end_neuro,2); neuro0_mean = mean(neuro0);
neuro1 = neuro(start_neuro:end_neuro,3); neuro1_mean = mean(neuro1);
frames = length(neuro0);

%calculating time parameters of freezing
[freez_ref, freez_ref_number, freez_ref_time, freez_ref_count, freez_ref_frame_in, freez_ref_frame_out] = RefineLine(freez_raw, MinLengthFreez, MaxLengthFreez);
freez_ref_time = freez_ref_time*20/FrameRateFreez*60;%in seconds

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

% %searching of good acts (2s+8s)
% count=0;
% k=1;
% freez_acts(1:frames) = 0;
% for i=2:frames
%     if freez(i) == 1
%         count = count+1;
%     end
%     if (freez(i) == 0) && (freez(i-1) == 1)   
%         freez_time(k) = count;  
%         if count >n_frames_after                      
%             if (count >= n_frames_after) && (i > count+n_frames_before)      
%                 if sum(freez(i-count-n_frames_before:i-count-1)) == 0 
%                     for j=1:n_frames_after+n_frames_before
%                         freez_acts(i-count-n_frames_before+j-1) = 1;
%                     end
%                 end
%             end            
%         end  
%         count = 0;
%         k=k+1;
%     end
% end
% freez_number=length(find(freez_time>=n_frames_after));
% freez_time = sum(freez_time)/FrameRateNeuro/60;

%plot raw freez signal
h = figure;
title('-----','FontSize', 15);
xlabel('Frame','FontSize', 15); 
ylabel('Freezing acts','FontSize', 15);hold on;
plot(1:length(freez_raw),freez_raw.*neuro0_mean ,'g','LineWidth', 2);hold on;
plot(1:length(freez_raw),freez_ref.*neuro1_mean ,'c','LineWidth', 2);
legend('freez raw','freez refine');
saveas(h,fullfile(PathFreez, sprintf('%s_FreezRawVsRef.fig',FilenameNeuro(1:2))));
% delete(h);

hh = figure;
title('-----','FontSize', 15);
xlabel('Time, s','FontSize', 15); 
ylabel('dF/F','FontSize', 15);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro0,'b','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,neuro1,'r','LineWidth', 2);hold on;
plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez.*neuro0_mean ,'g','LineWidth', 2);hold on;
% plot(0:1/FrameRateNeuro:(frames-1)/FrameRateNeuro,freez_acts.*neuro1_mean ,'c','LineWidth', 2);
legend('BrainRegion0','BrainRegion1', 'freezing');
saveas(hh,fullfile(PathFreez, sprintf('%s_FreezVsNeuro.fig',FilenameNeuro(1:2))));
% delete(hh);

% 
% 
% for cell=1:n_cells
%     mask_cup1(cell,:) = file_NV_TR(:,cell+1)'.*cup1_line_5s;
%     mask_cup2(cell,:) = file_NV_TR(:,cell+1)'.*cup2_line_5s;
% %plot(1:n_frames,mask_cup1(cell,:).*cell); hold on;
% 
% neuro_obj1(1:n_frames_after+n_frames_before)=0;
% k=1;
% j=1;
% for i=2:n_frames
%     if mask_cup1(cell,i) ~= 0
%         neuro_obj1(j,k) = mask_cup1(cell,i);
%         k=k+1;
%     end
%     if mask_cup1(cell,i) == 0 && mask_cup1(cell,i-1) ~= 0
%         k=1;
%         j=j+1;
%     end
% end
% 
% neuro_obj2(1:n_frames_after+n_frames_before)=0;
% kk=1;
% jj=1;
% for i=2:n_frames
%     if mask_cup2(cell,i) ~= 0
%         neuro_obj2(jj,kk) = mask_cup2(cell,i);
%         kk=kk+1;
%     end
%     if mask_cup2(cell,i) == 0 && mask_cup2(cell,i-1) ~= 0
%         kk=1;
%         jj=jj+1;
%     end
% end
% 
% neuro_average_obj1(cell,1:n_frames_after+n_frames_before)=0; 
% for i=1:n_frames_after+n_frames_before
%     neuro_average_obj1(cell,i) = mean(neuro_obj1(:,i));
%     neuro_median_obj1(cell,i) = median(neuro_obj1(:,i));
% end
% 
% neuro_average_obj2(cell,1:n_frames_after+n_frames_before)=0; 
% for i=1:n_frames_after+n_frames_before
%     neuro_average_obj2(cell,i) = mean(neuro_obj2(:,i));
%     neuro_median_obj2(cell,i) = median(neuro_obj2(:,i));
% end
% 
% %figure;plot(1:n_frames_after+n_frames_before,neuro_average_obj,'r','LineWidth', 3); title('neuro_average');xlabel('time, s'); ylabel('dF/F');
% for i=1:n_frames_after+n_frames_before  
% Z_score1(cell,:) = zscore(neuro_average_obj1(cell,:));
% end
% 
% for i=1:n_frames_after+n_frames_before  
% Z_score2(cell,:) = zscore(neuro_average_obj2(cell,:));
% end
% %figure;plot(0.05:0.05:7,Z_score,'g','LineWidth', 3); title('Z-score');xlabel('time, s'); ylabel('dF/F');
% end
% % h = HeatMap(neuro_average_obj1,'Colormap','jet');
% % hh = HeatMap(neuro_median_obj1,'Colormap','jet');
% % hhh = HeatMap(Z_score1,'Colormap','jet');
% 
% %sorting
% if max(max(Z_score1)) == 0
%     error = sprintf('No suitable entrances of Object %d', place)
%     csvwrite(sprintf('%s%s_z_score_%d_obj.csv', spike_path, spike_name, place),Z_score);
% else
%     h = HeatMap(Z_score1,'Colormap','jet');
%     %addTitle(h,sprintf('Object %d', place),'Color','red'); 
%     %csvwrite(sprintf('%s%s_z_score_%d_obj.csv', spike_path, spike_name, place),Z_score);
%     %h.Title=sprintf('Object %d', place);    
% bins = size(Z_score1, 2);
% for i=1:n_cells
% mean_befor(i) = mean(Z_score1(i,21:60));
% mean_after(i) = mean(Z_score1(i,61:100));
% % mean_befor(i) = mean(Z_score(i,81:100));
% % mean_after(i) = mean(Z_score(i,101:120));
% diff(i) = mean_after(i)-mean_befor(i);
% end
% Z_score1(:,121) = diff'; 
% zscore_sor1 = sortrows(Z_score1,121);
% h = HeatMap(zscore_sor1(:,1:120),'Colormap','jet');
% %addTitle(h,sprintf('SORT_Object %d', place),'Color','red'); 
% %csvwrite(sprintf('%s%s_z_score_sort%d_obj.csv', spike_path, spike_name, place),zscore_sor(:,1:140));
% end
% 
% %sorting
% if max(max(Z_score2)) == 0
%     error = sprintf('No suitable entrances of Object %d', place)
%     csvwrite(sprintf('%s%s_z_score_%d_obj.csv', spike_path, spike_name, place),Z_score);
% else
%     h = HeatMap(Z_score2,'Colormap','jet');
%     %addTitle(h,sprintf('Object %d', place),'Color','red'); 
%     %csvwrite(sprintf('%s%s_z_score_%d_obj.csv', spike_path, spike_name, place),Z_score);
%     %h.Title=sprintf('Object %d', place);    
% bins = size(Z_score2, 2);
% for i=1:n_cells
% mean_befor(i) = mean(Z_score2(i,21:60));
% mean_after(i) = mean(Z_score2(i,61:100));
% % mean_befor(i) = mean(Z_score(i,81:100));
% % mean_after(i) = mean(Z_score(i,101:120));
% diff(i) = mean_after(i)-mean_befor(i);
% end
% Z_score2(:,121) = diff'; 
% zscore_sor2 = sortrows(Z_score2,121);
% h = HeatMap(zscore_sor2(:,1:120),'Colormap','jet');
% %addTitle(h,sprintf('SORT_Object %d', place),'Color','red'); 
% %csvwrite(sprintf('%s%s_z_score_sort%d_obj.csv', spike_path, spike_name, place),zscore_sor(:,1:140));
% end
% 
% %  for i=1:n_cells
% %      spike_t = find(file_NV(:,i+1));
% %      if length(spike_t) >2
% %      spike_t_good = round(spike_t/20*20.005);
% %      
% %      h = figure; 
% %      hold on;plot(x_int_sm,y_int_sm, 'g');
% %      hold on;plot(x_int_sm(find(cup1_line>0)),y_int_sm(find(cup1_line>0)), 'r');
% %      hold on;plot(x_int_sm(find(cup2_line>0)),y_int_sm(find(cup2_line>0)), 'c');
% %      hold on;plot(x_int_sm(spike_t_good),y_int_sm(spike_t_good),'k*');
% %      hold on;plot(x_arena,y_arena, 'k');
% %      title('real trajectory of mouse');
% %      t=[0:pi/180:2*pi];
% %      x_cup1=cup1_centr_x+rad_cup_y*cos(t);y_cup1=cup1_centr_y+rad_cup_y*sin(t); 
% %      x_cup2=cup2_centr_x+rad_cup_y*cos(t);y_cup2=cup2_centr_y+rad_cup_y*sin(t); 
% %      hold on;plot(x_cup1,y_cup1, 'r');
% %      hold on;plot(x_cup2,y_cup2, 'r');     
% %      saveas(h, sprintf('%s\\STFP_5_D3_plots\\spike_plot_%d.png', path, i));    
% %      delete(h);
% %      end
% %  end
% % 
% % %plot of cup1 area
% % % figure;plot(1:n_frames,x_int_sm,'r'); title('x vs x cup1');
% % % hold on; plot(1:n_frames,cup1_line*513*96/72, 'k');
% % 
% % %animation of track
% % for i=1:n_frames 
% %     hold on
% %     plot(x_int_sm(i),y_int_sm(i),'o');
% %     pause(0.04); %(0.027); %
% %     %saveastiff((plot(x_real(i),y_real(i),'o'),'track.tif', options);%60/25 
% % end
% 
% %all spikes
%      figure; plot(x_int_sm,y_int_sm, 'g');
%      hold on;plot(x_arena,y_arena, 'k');
%      hold on;plot(x_int_sm(find(cup1_line>0)),y_int_sm(find(cup1_line>0)), 'r');
%      hold on;plot(x_int_sm(find(cup2_line>0)),y_int_sm(find(cup2_line>0)), 'c');
%      t=[0:pi/180:2*pi];
%      x_cup1=cup1_centr_x+rad_cup_y*cos(t);y_cup1=cup1_centr_y+rad_cup_y*sin(t); 
%      x_cup2=cup2_centr_x+rad_cup_y*cos(t);y_cup2=cup2_centr_y+rad_cup_y*sin(t); 
%      title('real trajectory of mouse'); 
%      hold on;plot(x_cup1,y_cup1, 'r');
%      hold on;plot(x_cup2,y_cup2, 'r');   
%  for i=1:n_cells
%      spike_t = find(file_NV(:,i+1));
%      if length(spike_t) >2
%      spike_t_good = round(spike_t/20*20.005);    
%      hold on;plot(x_int_sm(spike_t_good),y_int_sm(spike_t_good),'k*');                
%      %saveas(h, sprintf('%s\\STFP_5_D3_plots\\spike_plot_%d.png', path, i));    
%      delete(h);
%      end
%  end
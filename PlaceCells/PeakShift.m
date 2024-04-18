function [true_fields, mu_fields, sigma_fields, Nsig_fields] = PeakShift(spike_t_good, mask_t, N_time_sm, x_ind, y_ind, orig_peaks, N_shift, shift, S_sigma)

%creating time shift
Peak_shift(1:2,1:N_shift+1)=0;       
Time_Sum = sum(sum(N_time_sm)); %overall time in minutes
for k=2:N_shift+1
    Peak_shift(1,k) = rand*Time_Sum*shift;
end

for i=1:N_shift+1

    spike_t_shift = round(mod(spike_t_good+round(Peak_shift(1,i)*20*60), Time_Sum*20*60));

    N(1:size(N_time_sm,1),1:size(N_time_sm,2)) = 0;
    N_freq(1:size(N_time_sm,1),1:size(N_time_sm,2)) = 0;

    for k=1:length(spike_t_shift)
        if spike_t_shift(k) == 0
            spike_t_shift(k) = 1;
        end
        N(y_ind(spike_t_shift(k)),x_ind(spike_t_shift(k)))=N(y_ind(spike_t_shift(k)),x_ind(spike_t_shift(k)))+1;
    end
    
    [N_sm, ~] = ConvBorderFix(N,mask_t);
    
    N_freq_bad = N_sm./N_time_sm;    
    N_freq = N_freq_bad;
    N_freq(find(isnan(N_freq_bad))) = 0;
    N_freq(find(isinf(N_freq_bad))) = 0;
    
    [N_freq_sm, ~] = ConvBorderFix(N_freq,mask_t); 

    
    Peak_shift(2,i) = max(max(N_freq_sm));
    
%     %support plot 
%     h = figure('Position', [1 1 Screensize(3) Screensize(4)]);
%     DrawHeatMapMod (n_objects,0,1,1,0,0,1, N_freq_sm, Peak_shift(2,1), cup1_centr_x, cup1_centr_y, cup1_rad, cup2_centr_x, cup2_centr_y, cup2_rad, cup3_centr_x, cup3_centr_y, cup3_rad, x_arena, y_arena, x_int_sm, y_int_sm, bin_size, x_kcorr,cup1_line_ref,cup2_line_ref,cup3_line_ref, spike_t_shift);
%     title(sprintf('Firing rate of shifted #%i TimeShift = %.2f, PeakShift = %.3f',i,Peak_shift(1:2,i)), 'FontSize', 20);
%     F = getframe(h);
%     imwrite(F.cdata, sprintf('%s\\Peak_shift\\Heatmap_Peak_shift_%d.png', path,i));         
%     delete(h);
end

[~,mu_fields,sigma_fields] = zscore(Peak_shift(2,2:N_shift+1));
for field = 1:length(orig_peaks)
    true_fields(field) = double(orig_peaks(field) > mu_fields+S_sigma*sigma_fields);
    Nsig_fields(field) = (orig_peaks(field)-mu_fields)/sigma_fields;    
end

end
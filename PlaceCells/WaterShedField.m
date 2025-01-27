function [n_wfield, mask_wfield, spike_in_field] = WaterShedField(L, spike_t_good, x_int_sm, y_int_sm, bin_size_x)

x_shift = 0;
y_shift = 0;

n_wfield = double(max(max(L))); %number of fields in current cell
% wfields=wfields+n_wfield; %number of all fields 

%creation of empty arrays
mask_wfield = zeros(size(L,1),size(L,2),n_wfield);
spike_in_field = {};
for i=1:n_wfield    
     spike_in_field{i,1}=0;
end

for field=1:n_wfield
%creation of mask for separate field
    for ii=1:size(L,1)
        for jj=1:size(L,2)
            if L(ii, jj) == field
                mask_wfield(ii,jj,field)=field;
            end
        end
    end
    
%creation of cell array of spikes in separate field
k=1;
    for ii=1:size(L,1)
        for jj=1:size(L,2)
            if mask_wfield(ii,jj, field)
                for spike=1:length(spike_t_good)
%                     if abs(x_int_sm(spike_t_good(spike))/x_kcorr-(jj+x_shift-0.5)*bin_size_x/x_kcorr)<=bin_size_x && abs(y_int_sm(spike_t_good(spike))-(ii+y_shift-0.5)*bin_size_x)<=bin_size_x
                    if abs(x_int_sm(spike_t_good(spike))-(jj+x_shift+0.5)*bin_size_x)<=bin_size_x && abs(y_int_sm(spike_t_good(spike))-(ii+y_shift+0.5)*bin_size_x)<=bin_size_x                        
                        if isempty(find([spike_in_field{field,:}]==spike_t_good(spike)))
                            spike_in_field{field, k}= spike_t_good(spike);
                            k=k+1;
                        end
                    end
                end
            end
        end
    end    
end

line=1;
while line<=size(spike_in_field,1)
    if spike_in_field{line,1} == 0
        spike_in_field(line,:) = [];
        mask_wfield(:,:,line) = [];
        n_wfield = n_wfield-1;
        line=line-1;
    end
    line=line+1;
end
end
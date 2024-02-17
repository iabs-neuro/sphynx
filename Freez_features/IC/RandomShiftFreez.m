function [Cell_IC] = RandomShiftFreez(neuro_data, freez_data, knn, N_shift, shift, S_sigma, FrameRate)
% 12.01.23 vvp

% neuro_data = Neuro(:,i)';
% freez_data = Freez;

%creating time shift
IC_shift = zeros(2,N_shift+1);
Time_Sum = length(freez_data)/FrameRate; %overall time in minutes/seconds

for k=2:N_shift+1
    IC_shift(1,k) = rand*Time_Sum*shift;
end

%% IC calculation   
freez_time = find(freez_data);
for i=1:N_shift+1
    freez_time_shift = round(mod(freez_time+round(IC_shift(1,i)*FrameRate), Time_Sum*FrameRate));
    freez_time_shift(find(freez_time_shift == 0)) = length(freez_data);
    freez_shufl = zeros(1, length(freez_data));
    freez_shufl(freez_time_shift) = 1;  
    IC_shift(2,i) = mi_discrete_cont(neuro_data,freez_shufl, knn);
end
[~,MU,SIGMA] = zscore(IC_shift(2,2:N_shift+1));

if IC_shift(2,1) >MU+S_sigma*SIGMA
    Cell_IC(1,1) = 1;
    Cell_IC(1,2) = IC_shift(2,1);
    Cell_IC(1,3) = MU;
    Cell_IC(1,4) = SIGMA;
else
    Cell_IC(1,1) = 0;
    Cell_IC(1,2) = IC_shift(2,1);
    Cell_IC(1,3) = MU;
    Cell_IC(1,4) = SIGMA;
end    
end

function [n_cells, n_IC_cells, Cell_IC] = IC_Freez_FAD(PathFreez,PathNeuro,PathOut, FilenameFreez, FilenameNeuro)
% 12.01.23 vvp
% 06.02.23 added sync for FC experiment

%% main parameters and loading data
FrameRateTrack = 30;
N_shift=100; %number of shift for random distribution
shift=0.9; %percent of all time occupancy for random shift
S_sigma = 2; %criteria for informative place cell(~95%)
knn = 10;
FontSizeLabel = 5;

if nargin<5
    [FilenameFreez, PathFreez]  = uigetfile('*.csv','load the freez file','g:\_Projects\_RNF [2022]\_Freez\');
    [FilenameNeuro, PathNeuro]  = uigetfile('*.csv','load the neuro file','g:\_Projects\_RNF [2022]\_Traces\');
    PathOut = 'g:\_Projects\_RNF [2022]\Freez_IC\';
end
FilenameOut = FilenameNeuro(1:8);

Freez_bad = load(sprintf('%s%s', PathFreez, FilenameFreez))';
Freez_orig = Freez_bad(2,:);
Neuro_bad = load(sprintf('%s%s', PathNeuro, FilenameNeuro));
Neuro = Neuro_bad(2:end, 2:end);

n_cells = size(Neuro,2);
n_frames = size(Neuro,1);

% time = (1:n_frames)/FrameRate;

%% sync part
end_track = size(Freez_orig,2);
end_spike = size(Neuro,1);
FrameRate  = end_spike/(end_track/FrameRateTrack);
time = (1:n_frames)/FrameRate;
Freez = zeros(1,end_spike);
for i=1:end_spike
    Freez(i) = Freez_orig(round(i*(FrameRateTrack/FrameRate)));
end
%% main part

Cell_IC(1,1:n_cells)=linspace(1,n_cells,n_cells);

h = waitbar(1/n_cells, sprintf('IC calculation, cell %d of %d', 0,  n_cells));
for i=1:n_cells      
    h = waitbar(i/n_cells,h, sprintf('IC calculation, cell %d of %d', i,  n_cells));
    
    %IC calculation
    Cell_IC(2:5,i) = RandomShiftFreez(Neuro(:,i)', Freez, knn, N_shift, shift, S_sigma, FrameRate);
    Cell_IC(6,i) = (Cell_IC(3,i)-Cell_IC(4,i))/Cell_IC(5,i);         
end
delete(h);
n_IC_cells = sum(Cell_IC(2,:));

% plotting
Freez_plot = Freez;
Freez_plot(find(Freez==0)) = NaN;
for i = find(Cell_IC(2,:) == 1)
    h = figure;
    plot(time,Neuro(:,i) ,'g','LineWidth', 1);hold on;
    plot(time,Freez_plot*mean(Neuro(:,i)),'b', 'Linewidth', 4); hold on;
    title(sprintf('Специализированный на акты замирания нейрон, SIGMA = %g', Cell_IC(6,i)));
    xlabel('Время, с','FontSize', FontSizeLabel);
    ylabel('df/F','FontSize', FontSizeLabel);
    saveas(h, sprintf('%s\\%s_neuron_%d.png',PathOut,FilenameOut, i));
    delete(h);
end

save(sprintf('%s\\%s_WorkSpace_freez.mat',PathOut, FilenameOut));
writematrix(Cell_IC, sprintf('%s\\%s_Freez_IC.csv',PathOut,FilenameOut));
end

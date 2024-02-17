function [n_cells, n_IC_cells] = IC_Freez(N_shift,S_sigma, PathFreez,PathNeuro,PathOut, FilenameFreez, FilenameNeuro)
% 12.01.22 vvp
% иправить привязку к фреймрейту

%% main parameters and loading data

shift = 0.9; %percent of all time occupancy for random shift
knn = 10;
FontSizeLabel = 5;
if nargin<7
    [FilenameFreez, PathFreez]  = uigetfile('*.csv','load the freez file','g:\_Projects\_APTSD [2022]\APTSD\sync_traces\');
    [FilenameNeuro, PathNeuro]  = uigetfile('*.csv','load the neuro file','g:\_Projects\_APTSD [2022]\APTSD\sync_traces\');
    PathOut = 'g:\_Projects\_APTSD [2022]\APTSD\IC_freez\';
    N_shift = 100; %number of shift for random distribution
    S_sigma = 2; %criteria for informative place cell(~95%)
end
FilenameOut = FilenameFreez(1:end-4);

Freez = load(sprintf('%s%s', PathFreez, FilenameFreez))';
% Neuro_bad = load(sprintf('%s%s', PathNeuro, FilenameNeuro));
Neuro_bad = table2array(readtable(sprintf('%s%s', PathNeuro, FilenameNeuro)));
Neuro = Neuro_bad(2:end, 2:end);
Freez(Freez>0)=1;

n_cells = size(Neuro,2);
n_frames = size(Neuro,1);
FrameRate = n_frames/Neuro_bad(end,1);
fprintf('%d frames, %d total time\n',n_frames,Neuro_bad(end,1))

time = (1:n_frames)/FrameRate;
%% main part

if ~isempty(Neuro)
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
    Freez_plot(Freez==0) = NaN;
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
    
    save(sprintf('%s\\WorkSpace_freez_%s.mat',PathOut, FilenameOut));
    writematrix(Cell_IC, sprintf('%s\\%s_Freez_IC.csv',PathOut,FilenameOut));
else
    n_IC_cells = 0;
    fprintf('Нет ни одного нейрона в нейродате\n')
end

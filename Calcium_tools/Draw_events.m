%% paths and names
path = 'w:\Projects\RFC\CalciumData\6_Traces\';
sp_path = 'w:\Projects\RFC\CalciumData\6_Traces\';
% sp_path = 'd:\Projects\СС\Spikes\';
fname = 'RFC_F30_3D_traces.csv';
sp_fname = 'RFC_F30_3D_spikes.csv';
NumFirst = 20; % or [];
bckg_med_wind = 500;

%% main
TRACES = csvread(strcat(path, fname), 1);
SPIKES = csvread(strcat(sp_path, sp_fname), 1);

dim = size(TRACES);
X = TRACES(1:dim(1),1);
maxim = max(max(TRACES(1:dim(1),2:dim(2))));
minim = min(min(TRACES(1:dim(1),2:dim(2))));
absmax = max(max(abs(maxim), abs(minim)));
offset = 2;
if isempty(NumFirst)
    NumFirst = dim(2);
end
%% traces drawing
w = waitbar(0, sprintf('Plotting trace %d of %d', 1,  NumFirst-1));    
hold on
for i = 2:NumFirst
    waitbar((i-1)/(NumFirst-1), w, sprintf('Processing cell %d of %d', i-1,  NumFirst-1));
    if nnz(SPIKES(1:dim(1),i))
        line_width = 2;
    else
        line_width = 1;
    end
    plot(X, TRACES(1:dim(1),i)/max(TRACES(1:dim(1),i)) + offset*(i-2), 'Color', sd_colornum_metro(i-2), 'LineWidth', line_width);
    
    %drawing median
    TraceMedian = median(TRACES(1:dim(1),i))/max(TRACES(1:dim(1),i));
%     plot(X, ones(1,dim(1))*TraceMedian + offset*(i-2),'--', 'Color', sd_colornum_metro(i-2), 'LineWidth', 1);
    TraceMedianWindow = medfilt1(TRACES(1:dim(1),i)/max(TRACES(1:dim(1),i)), bckg_med_wind);
    plot(X, TraceMedianWindow + offset*(i-2),'--', 'Color', sd_colornum_metro(i-2), 'LineWidth', 1);

    %drawing mad
    TraceMad = mad(TRACES(1:dim(1),i))/max(TRACES(1:dim(1),i));    
%     plot(X, ones(1,dim(1))*(TraceMedian+TraceMad*1) + offset*(i-2),'-.', 'Color', sd_colornum_metro(i-2), 'LineWidth', 1);
%     plot(X, ones(1,dim(1))*(TraceMedian+TraceMad*2) + offset*(i-2),'-.', 'Color', sd_colornum_metro(i-2), 'LineWidth', 1);
%     plot(X, ones(1,dim(1))*(TraceMedian+TraceMad*3) + offset*(i-2),'-.', 'Color', sd_colornum_metro(i-2), 'LineWidth', 1);
    plot(X, (TraceMedianWindow+TraceMad*3) + offset*(i-2),'-.', 'Color', sd_colornum_metro(i-2), 'LineWidth', 1);
end
delete(w);

%% spikes drawing
w = waitbar(0, sprintf('Drawing spikes: trace %d of %d', 1,  NumFirst-1));

for i = 2:NumFirst
    waitbar((i-1)/(NumFirst-1), w, sprintf('Processing cell %d of %d', i-1,  NumFirst-1));
    for j = 1:dim(1)
        if SPIKES (j,i)
            sp_ampl = SPIKES (j,i)/max(TRACES(1:dim(1),i));
            patch([X(j)-0.3, X(j), X(j)+0.3, X(j)], [offset*(i-1.8) + sp_ampl, offset*(i-1.65) + sp_ampl, offset*(i-1.8) + sp_ampl, offset*(i-1.95) + sp_ampl], sd_colornum_metro(i-2), 'EdgeColor', 'none');
        end
    end
end

delete(w);

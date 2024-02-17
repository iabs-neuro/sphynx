PathFreez = 'g:\_Projects\2023_Rogozhnikova\Freez\';
PathNeuro = 'g:\_Projects\2023_Rogozhnikova\Neurotraces\';
PathOut = 'g:\_Projects\2023_Rogozhnikova\IC_freez\';
% path = 'g:\_Projects\2023_Rogozhnikova\PlaceCells\';

Filenames = {
    'M12.wmv',...
    'M13.wmv',...
    'M14.wmv',...
    'M16.wmv',...
    'M21old.wmv',...
    'M22old.wmv',...
    'M25old.wmv',...
    'M27old.wmv'
    };

%% main
Sum_Cell = zeros(1,length(Filenames));
Sum_Cell_IC = zeros(1,length(Filenames));
for file = 1:length(Filenames)
% for file = [1 2 3]
    fprintf('%s in progress\n', Filenames{file});
    FilenameFreez = sprintf('FcOY_%s_Test_sync_Freezing_13_5_30_15.csv',Filenames{file}(1:end-4));
    FilenameNeuro = sprintf('FcOY_%s_Test_traces.csv',Filenames{file}(1:end-4));
    [n_cells, n_IC_cells] = IC_Freez(100, 2, PathFreez,PathNeuro,PathOut, FilenameFreez, FilenameNeuro);
    Sum_Cell(file) = n_cells;
    Sum_Cell_IC(file) = n_IC_cells;   
    
%     PlaceFieldAnalyzer(path, filename, filenameNV, filename_V, 1, 1, 0, 0,'IC_orig')
end



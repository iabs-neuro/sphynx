%%
path = 'g:\_Projects\_APTSD [2022]\APTSD\sync_traces\';
PathOut = 'g:\_Projects\_APTSD [2022]\APTSD\IC_freez\';

FilenameFreez = {
    'AP_11_0TR_sync_freeze.csv', 'AP_12_0TR_sync_freeze.csv','AP_13_0TR_sync_freeze.csv',...
    'AP_14_0TR_sync_freeze.csv','AP_15_0TR_sync_freeze.csv' 
    };
FilenameNeuro = {
    'AP_11_0TR_sync_traces.csv','AP_12_0TR_sync_traces.csv','AP_13_0TR_sync_traces.csv',...
    'AP_14_0TR_sync_traces.csv','AP_15_0TR_sync_traces.csv'    
};

%%
Sum_Cell = [];
Sum_Cell_IC = [];
for file = 1:length(FilenameFreez)
    [n_cells, n_IC_cells] = IC_Freez(path,path,PathOut, FilenameFreez{file}, FilenameNeuro{file});
    Sum_Cell(file) = n_cells;
    Sum_Cell_IC(file) = n_IC_cells;    
end



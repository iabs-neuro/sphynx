path = 'g:\_Projects\_APTSD [2022]\APTSD\sync_traces\';
PathOut = 'g:\_Projects\_APTSD [2022]\APTSD\IC_freez\';

% 0TR
FilenameFreez = {
    'AP_11_0TR_sync_freeze.csv', 'AP_12_0TR_sync_freeze.csv','AP_13_0TR_sync_freeze.csv',...
    'AP_14_0TR_sync_freeze.csv','AP_15_0TR_sync_freeze.csv' 
    };
FilenameNeuro = {
    'AP_11_0TR_sync_traces.csv','AP_12_0TR_sync_traces.csv','AP_13_0TR_sync_traces.csv',...
    'AP_14_0TR_sync_traces.csv','AP_15_0TR_sync_traces.csv'    
};

% % 1CT
% FilenameFreez = {
%     'AP_11_1CT_sync_freeze.csv', 'AP_12_1CT_sync_freeze.csv','AP_13_1CT_sync_freeze.csv',...
%     'AP_14_1CT_sync_freeze.csv','AP_15_1CT_sync_freeze.csv' 
%     };
% FilenameNeuro = {
%     'AP_11_1CT_sync_traces.csv','AP_12_1CT_sync_traces.csv','AP_13_1CT_sync_traces.csv',...
%     'AP_14_1CT_sync_traces.csv','AP_15_1CT_sync_traces.csv'    
% };

% % 2ST
% FilenameFreez = {
%     'AP_11_2ST_sync_freeze.csv', 'AP_12_2ST_sync_freeze.csv','AP_13_2ST_sync_freeze.csv',...
%     'AP_14_2ST_sync_freeze.csv','AP_15_2ST_sync_freeze.csv' 
%     };
% FilenameNeuro = {
%     'AP_11_2ST_sync_traces.csv','AP_12_2ST_sync_traces.csv','AP_13_2ST_sync_traces.csv',...
%     'AP_14_2ST_sync_traces.csv','AP_15_2ST_sync_traces.csv'    
% };
% 
% % 3GT
% FilenameFreez = {
%     'AP_11_3GT_sync_freeze.csv', 'AP_12_3GT_sync_freeze.csv','AP_13_3GT_sync_freeze.csv',...
%     'AP_14_3GT_sync_freeze.csv','AP_15_3GT_sync_freeze.csv' 
%     };
% FilenameNeuro = {
%     'AP_11_3GT_sync_traces.csv','AP_12_3GT_sync_traces.csv','AP_13_3GT_sync_traces.csv',...
%     'AP_14_3GT_sync_traces.csv','AP_15_3GT_sync_traces.csv'    
% };
% % 
% % 4EM
% FilenameFreez = {
%     'AP_11_4EM_coord_Freezing_3_10_0.2.csv', 'AP_12_4EM_coord_Freezing_3_10_0.2.csv','AP_13_4EM_coord_Freezing_3_10_0.2.csv',...
%     'AP_14_4EM_coord_Freezing_3_10_0.2.csv','AP_15_4EM_coord_Freezing_3_10_0.2.csv' 
%     };
% 
% FilenameNeuro = {
%     'AP_11_4EM_sync_traces.csv','AP_12_4EM_sync_traces.csv','AP_13_4EM_sync_traces.csv',...
%     'AP_14_4EM_sync_traces.csv','AP_15_4EM_sync_traces.csv'    
% };

% % % 0TR shock
% FilenameFreez = {
%     'AP_11_0TR_sync_shock.csv', 'AP_12_0TR_sync_shock.csv','AP_13_0TR_sync_shock.csv',...
%     'AP_14_0TR_sync_shock.csv','AP_15_0TR_sync_shock.csv' 
%     };
% FilenameNeuro = {
%     'AP_11_0TR_sync_traces.csv','AP_12_0TR_sync_traces.csv','AP_13_0TR_sync_traces.csv',...
%     'AP_14_0TR_sync_traces.csv','AP_15_0TR_sync_traces.csv'    
% };

% % % 4EM entry
% FilenameFreez = {
%     'AP_11_0TR_sync_shock.csv', 'AP_12_0TR_sync_shock.csv','AP_13_0TR_sync_shock.csv',...
%     'AP_14_0TR_sync_shock.csv','AP_15_0TR_sync_shock.csv' 
%     };
% FilenameNeuro = {
%     'AP_11_0TR_sync_traces.csv','AP_12_0TR_sync_traces.csv','AP_13_0TR_sync_traces.csv',...
%     'AP_14_0TR_sync_traces.csv','AP_15_0TR_sync_traces.csv'    
% };

Sum_Cell = [];
Sum_Cell_IC = [];
for file = 1:length(FilenameFreez)
    [n_cells, n_IC_cells] = IC_Freez(path,path,PathOut, FilenameFreez{file}, FilenameNeuro{file});
    Sum_Cell(file) = n_cells;
    Sum_Cell_IC(file) = n_IC_cells;    
end



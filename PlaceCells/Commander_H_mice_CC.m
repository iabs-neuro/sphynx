%% paths and names
% filenames = {
%     'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
%     'CC_H04_1D','CC_H04_2D','CC_H05_1D','CC_H05_2D','CC_H06_1D','CC_H06_2D',...
%     'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
%     'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D','CC_H12_1D','CC_H12_2D',...
%     'CC_H13_1D','CC_H13_2D','CC_H14_1D','CC_H14_2D','CC_H15_1D','CC_H15_2D',...
%     'CC_H16_1D','CC_H16_2D','CC_H17_1D','CC_H17_2D',...
%     'CC_H19_1D','CC_H19_2D','CC_H22_1D','CC_H22_2D','CC_H23_1D','CC_H23_2D'
%     };

filenames = {
    'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
    'CC_H04_1D','CC_H04_2D','CC_H06_2D',...
    'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
    'CC_H11_2D','CC_H12_2D',...
    'CC_H13_2D','CC_H14_1D','CC_H14_2D',...
    'CC_H19_1D','CC_H19_2D','CC_H23_1D','CC_H23_2D'
    };

pathNV = 'd:\Projects\СС\Spikes_wvt_0.05amp_startenv\';
path = 'd:\Projects\СС\Features\';
pathPR = 'd:\Projects\СС\Presets\';

%% main
for file = 1:length(filenames)
    filename = sprintf('%s_Features.csv',filenames{file});
    filenameNV = sprintf('%s_spikes.csv',filenames{file});
    filenamePR = sprintf('%s_Preset.mat',filenames{file});
    
    if file == 1 ||file == 2 ||file == 3 || file == 4
        plot_opt = 1;
    else
        plot_opt = 2;
    end
    
    [FieldsIC] = PlaceFieldAnalyzerCC(path,filename,pathNV,filenameNV,pathPR,filenamePR, plot_opt);    
end
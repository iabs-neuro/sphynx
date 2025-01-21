%% paths and names
filenames = {
    'H01_1D','H02_1D','H03_1D','H06_1D','H07_1D','H08_1D','H09_1D','H14_1D','H23_1D',...
    'H26_1D','H27_1D','H31_1D','H32_1D','H33_1D','H36_1D','H39_1D',...
    'H01_2D','H02_2D','H03_2D','H06_2D','H07_2D','H08_2D','H09_2D','H14_2D','H23_2D'...
    'H26_2D','H27_2D','H31_2D','H32_2D','H33_2D','H36_2D','H39_2D',...
    'H01_3D','H02_3D','H03_3D','H06_3D','H07_3D','H08_3D','H09_3D','H14_3D','H23_3D',...
    'H26_3D','H27_3D','H31_3D','H32_3D','H33_3D','H36_3D','H39_3D',...
    'H01_4D','H02_4D','H03_4D','H06_4D','H07_4D','H08_4D','H09_4D','H14_4D','H23_4D',...
    'H26_4D','H27_4D','H31_4D','H32_4D','H33_4D','H36_4D','H39_4D',...
    };

pathMAT = 'w:\Projects\NOF\PlaceCellsData\10_PlaceCells\zscoreThr4_binsize4\';
pathOut = 'w:\Projects\NOF\PlaceCellsData\10_PlaceCells\zscoreThr4_binsize4\';

%% main

% Big_Cell_IC = [];
cells_info = struct();
for file = 1:length(filenames)
    
    FilenameMat = sprintf('%s\\WorkSpace_NOF_%s.mat',pathMAT, filenames{file});
    load(FilenameMat, 'Cell_IC');
    
%     Big_Cell_IC = [Big_Cell_IC Cell_IC(6,:)]

    table_name = sprintf('NOF_%s', filenames{file});
    cells_info.(table_name) = Cell_IC; 
end

save(sprintf('%s\\zscoreThr4_binsize4_center.mat', pathOut), 'cells_info');


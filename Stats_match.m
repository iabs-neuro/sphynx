
% change the name
FileName = 'NOF_H21_v2';

folder_path = 'd:\Projects\H_mice\NOF\Match\';
OutPath = 'd:\Projects\H_mice\NOF\Match\';

% loading mat-file
[FilenameMAT, PathMAT] = uigetfile('*.*','Select cellRegistered*.mat file',sprintf('%s%s',folder_path,FileName));
load(fullfile(PathMAT,FilenameMAT));
%%
Cell_table = cell_registered_struct.cell_to_index_map./cell_registered_struct.cell_to_index_map;
Cell_table(isnan(Cell_table)) = 0;
Cell_info = sum(Cell_table,2);

All_match(1) = length(Cell_info);
All_match(2) = length(find(Cell_info==4));
All_match(3) = length(find(Cell_info==3));
All_match(4) = length(find(Cell_info==2));
All_match(5) = length(find(Cell_info==1));

disp(All_match);
%%
csvwrite(sprintf('%s%s.csv', folder_path, FileName), cell_registered_struct.cell_to_index_map);
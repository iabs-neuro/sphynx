path = 'g:\_Projects\_RNF [2022]\_workspaces\';

% FilenamesCntrl1D = {
%     'BE_01_EXPO','BE_02_EXPO','FS_07_EXPO'};

FilenamesFAD1D = {
    'FA_01_EXPO','FA_03_EXPO','FA_04_EXPO','FA_05_EXPO','FA_07_EXPO','FA_09_EXPO'};

% Filenames = {
%     'FA_01_EXPO','FA_02_EXPO','FA_03_EXPO','FA_04_EXPO','FA_05_EXPO',...
%     'FA_07_EXPO','FA_08_EXPO','FA_09_EXPO',...
%     'FA_01_TEST','FA_02_TEST','FA_03_TEST','FA_04_TEST','FA_05_TEST',...
%     'FA_07_TEST','FA_09_TEST',...    
%     'BE_01_EXPO','BE_02_EXPO','FS_01_EXPO','FS_03_EXPO','FS_05_EXPO',...
%     'FS_07_EXPO','FS_08_EXPO','FS_09_EXPO','FS_10_EXPO',...
%     'BE_01_TEST','BE_02_TEST','FS_01_TEST','FS_03_TEST','FS_05_TEST',...
%     'FS_07_TEST','FS_08_TEST','FS_09_TEST','FS_10_TEST'
%     };

pathout = 'g:\_Projects\_RNF [2022]\Cell_IC';
% Filenames = FilenamesCntrl1D;
Filenames = FilenamesFAD1D;
% Filenames = FilenamesCntrl7D;
% Filenames = FilenamesFAD7D;

%% 
for file = 1:length(Filenames)
% for file = 1
    disp(Filenames{file});
    test_zone5 = [];
    N_time_sm = [];
    pathin = sprintf('%s\\Workspace_%s.mat',path,Filenames{file});
    load(pathin,'Cell_IC');
    writematrix(Cell_IC, sprintf('%s\\%s_IC.csv',pathout,Filenames{file}));
end

%% paths and filenames

ExpID = '3DM';

PathVideo = 'w:\Projects\3DM\Comparasion\3DMaze\2_Combined\';
PathDLC = 'w:\Projects\3DM\Comparasion\3DMaze\4_DLC\';
PathOut = 'w:\Projects\3DM\Comparasion\3DMaze\5_Behavior\';
PathPreset = 'w:\Projects\3DM\Comparasion\3DMaze\3_Presets\';

% for ALL DAYS
FileNames = {
    'AA04_1D_1T' 'AA04_2D_1T' 'AA04_3D_1T' 'AA05_1D_1T' 'AA05_2D_1T' 'AA05_3D_1T' ...
    'AA06_1D_1T' 'AA06_2D_1T' 'AA06_3D_1T' 'AA06_4D_1T' 'AA07_1D_1T' 'AA07_2D_1T' 'AA07_3D_1T' 'AA07_4D_1T' ...
    'AA08_1D_1T' 'AA08_2D_1T' 'AA08_3D_1T' 'AA08_4D_1T' 'AA09_1D_1T' 'AA09_2D_1T' 'AA09_3D_1T' 'AA09_4D_1T' ...
    'AA10_1D_1T' 'AA10_2D_1T' 'AA10_3D_1T' 'AA11_1D_1T' 'AA11_2D_1T' 'AA11_3D_1T' 'AA11_4D_1T' ...
    'AA12_1D_1T' 'AA12_2D_1T' 'AA12_3D_1T' 'AA13_1D_1T' 'AA13_2D_1T' 'AA13_3D_1T' 'AA13_4D_1T' ...
    'AA14_1D_1T' 'AA14_2D_1T' 'AA14_3D_1T' 'CG05_1D_1T' 'CG05_2D_1T' 'CG05_3D_1T' 'CG05_4D_1T' ...
    'CG06_1D_1T' 'CG06_2D_1T' 'CG06_3D_1T' 'CG08_1D_1T' 'CG08_2D_1T' 'CG08_3D_1T' ...
    'CG09_1D_1T' 'CG09_2D_1T' 'CG09_3D_1T' 'CG09_4D_1T' 'CG11_1D_1T' 'CG11_2D_1T' 'CG11_3D_1T' ...
    'CG14_1D_1T' 'CG14_2D_1T' 'CG14_3D_1T' 'CG14_4D_1T' 'CG15_2D_1T' 'CG15_3D_1T' ...
    'CG20_1D_1T' 'CG20_2D_1T' 'CG20_3D_1T' 'CG20_4D_1T' 'CG22_1D_1T' 'CG22_2D_1T' 'CG22_3D_1T' ...
    'LM01_1D_1T' 'LM01_2D_1T' 'LM01_3D_1T' 'LM01_4D_1T' 'LM02_1D_1T' 'LM02_2D_1T' 'LM02_3D_1T' ...
    'LM03_1D_1T' 'LM03_2D_1T' 'LM03_3D_1T' 'LM04_1D_1T' 'LM04_2D_1T' 'LM04_3D_1T' 'LM04_4D_1T' ...
    'LM05_1D_1T' 'LM05_2D_1T' 'LM05_3D_1T' 'LM05_4D_1T' 'LM06_1D_1T' 'LM06_2D_1T' 'LM06_3D_1T' ...
    'LM07_1D_1T' 'LM07_2D_1T' 'LM07_3D_1T' 'LM07_4D_1T' 'LM08_1D_1T' 'LM08_2D_1T' 'LM08_3D_1T' ...
    'LM09_1D_1T' 'LM09_2D_1T' 'LM09_3D_1T' 'LM09_4D_1T' 'LM10_1D_1T' 'LM10_2D_1T' 'LM10_3D_1T' ...
    'SU03_1D_1T' 'SU03_2D_1T' 'SU03_3D_1T' 'SU04_1D_1T' 'SU04_2D_1T' 'SU04_3D_1T' 'SU04_4D_1T' ...
    'SU06_1D_1T' 'SU06_2D_1T' 'SU06_3D_1T' 'SU13_1D_1T' 'SU13_2D_1T' 'SU13_3D_1T' 'SU13_4D_1T' ...
    'SU14_1D_1T' 'SU14_2D_1T' 'SU14_3D_1T' 'SU15_1D_1T' 'SU15_2D_1T' 'SU15_3D_1T' ...
    'SU16_1D_1T' 'SU16_2D_1T' 'SU16_3D_1T' 'SU16_4D_1T' 'SU19_1D_1T' 'SU19_2D_1T' 'SU19_3D_1T' 'SU19_4D_1T'
    };

FilesNumber = length(FileNames);

%% main part

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
Duration = zeros(1,FilesNumber); % no start box
Duration_total = zeros(1,FilesNumber); % all time (1200 seconds should be)
Height_up = zeros(1,FilesNumber);
Height_down = zeros(1,FilesNumber);
Height = zeros(1,FilesNumber);

AllActs = struct('SessionName', '',  'Acts', []);
filess  = [43 ];
%%
% for file = 1:length(FileNames)
   for file = filess 
    FilenameVideo = sprintf('3DM_%s.mp4', FileNames{file});
    FilenameDLC = sprintf('3DM_%sDLC_Resnet101_3DMMar25shuffle3_snapshot_370.csv',FileNames{file});
    FilenamePreset = '3DM_Tunnels_Preset2.mat';
    
    fprintf('Processing of 3DM_%s\n', FileNames{file})
    
    [Acts, ~, ~, ~, session] = BehaviorAnalyzer3DM(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    table_name = sprintf('%s_%s', ExpID, FileNames{file});
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    
    Duration(file) = session.duration;
    Duration_total(file) = session.duration_total;
    
    Distance(file) = session.total_distance;
    Velocity(file) = session.mean_velocity;
    
    Height_up(file) = session.total_height_up;
    Height_down(file) = session.total_height_down;
    Height(file) = session.total_height;
    
    clear 'Acts' 'session';
end

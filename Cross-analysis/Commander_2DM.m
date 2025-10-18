%% paths and filenames

ExpID = '2DM';

PathVideo = 'w:\Projects\3DM\Comparision\2DM\3_Combine\';
PathDLC = 'w:\Projects\3DM\Comparision\2DM\4_DLC\';
PathOut = 'w:\Projects\3DM\Comparision\2DM\5_Behavior_plot_full\';
PathPreset = 'w:\Projects\3DM\Comparision\2DM\3_Preset\';

% % for ALL DAYS
% FileNames = {
%     'AA04_1D',	'AA04_2D',	'AA04_3D',	'AA04_4D',	'AA05_1D',	'AA05_2D',  'AA05_3D',	'AA05_4D',	'AA06_1D',	'AA06_2D',	'AA06_3D',	'AA07_1D',	'AA07_2D',	'AA07_3D',	'AA08_1D',	'AA08_2D',	'AA08_3D',	'AA09_1D'	'AA09_2D',	'AA09_3D',	'AA10_1D',	'AA10_2D',	'AA10_3D',	'AA10_4D',	'AA11_1D',	'AA11_2D',	'AA11_3D',	'AA12_1D',	'AA12_2D',	'AA12_3D',	'AA12_4D',	'AA13_1D',	'AA13_2D',	'AA13_3D',	'AA14_1D',	'AA14_2D',	'AA14_3D',	'AA14_4D', ...
%     'CG05_1D',	'CG05_2D',	'CG05_3D',	'CG06_1D',	'CG06_2D',	'CG06_3D',	'CG06_4D',	'CG08_1D',	'CG08_2D',	'CG08_3D',	'CG08_4D',	'CG09_1D',	'CG09_2D',	'CG09_3D',	'CG11_1D',	'CG11_2D',	'CG11_3D',	'CG11_4D',	'CG14_1D',	'CG14_2D',	'CG14_3D',	'CG15_1D',	'CG15_2D',	'CG15_3D',	'CG15_4D',	'CG20_1D',	'CG20_2D',	'CG20_3D',	'CG22_1D',	'CG22_2D',	'CG22_3D',	'CG22_4D', ...
%     'LM01_1D',	'LM01_2D',	'LM01_3D',	'LM02_1D',	'LM02_2D',	'LM02_3D',	'LM02_4D',	'LM03_1D',	'LM03_2D',	'LM03_3D',	'LM03_4D',	'LM04_1D',	'LM04_2D',	'LM04_3D',	'LM05_1D',	'LM05_2D',	'LM05_3D',	'LM06_1D',	'LM06_2D',	'LM06_3D',	'LM06_4D',	'LM07_1D',	'LM07_2D',	'LM07_3D',	'LM08_1D',	'LM08_2D',	'LM08_3D',	'LM08_4D',	'LM09_1D',	'LM09_2D',	'LM09_3D',	'LM10_1D',	'LM10_2D',	'LM10_3D',	'LM10_4D', ...
%     'SU03_1D',	'SU03_2D',	'SU03_3D',	'SU03_4D',	'SU04_1D',	'SU04_2D',	'SU04_3D',	'SU06_1D',	'SU06_2D',	'SU06_3D',	'SU06_4D',	'SU13_1D',	'SU13_2D',	'SU13_3D',	'SU14_1D',	'SU14_2D',	'SU14_3D',	'SU14_4D',	'SU15_1D',	'SU15_2D',	'SU15_3D',	'SU15_4D',	'SU16_1D',	'SU16_2D',	'SU16_3D',	'SU19_1D',	'SU19_2D',  'SU19_3D'
%     };

% for full plot of 2 mice
% FileNames = {
%     'AA04_1D',	'AA04_2D',	'AA05_1D',	'AA05_2D', ...
%     'CG05_1D',	'CG05_2D',	'CG06_2D',	'CG06_3D', ...
%     'SU03_1D',	'SU03_2D',	'SU04_1D',	'SU04_2D'
%     };
FileNames = {
     'AA09_3D','SU03_1D', 'SU03_2D','SU03_4D','SU15_2D', 'SU19_1D','SU06_1D', 'SU06_3D', 'SU13_1D', 'SU14_1D','SU14_4D' 
           
    };
FilesNumber = length(FileNames);

%% main part

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);
Duration = zeros(1,FilesNumber);
AllActs = struct('SessionName', '',  'Acts', []);

%%
for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('2DM_%s_1T.avi', FileNames{file});
    
%     if file <= 39
%         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet50_Polevyki_AJun5shuffle2_1000000.csv',FileNames{file});
%     elseif file <= 71
%         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet50_PolevkiJun12shuffle2_1000000.csv',FileNames{file});
%     else 
%         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
%     end
    
% % for full plot
%     if file <= 4
%         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet50_Polevyki_AJun5shuffle2_1000000.csv',FileNames{file});
%     elseif file <= 8
%         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet50_PolevkiJun12shuffle2_1000000.csv',FileNames{file});
%     else 
%         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
%     end
%    
% for full plot of 2 mice
    if file <= 1
         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet50_Polevyki_AJun5shuffle2_1000000.csv',FileNames{file});
    else
         FilenameDLC = sprintf('2DM_%s_1TDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv',FileNames{file});
    end
    
    FilenamePreset = sprintf('2DM_%s_1T_Preset.mat', FileNames{file});
    fprintf('Processing of 2DM_%s\n', FileNames{file})
    
    [Acts, BodyPartsTraces, Point, Options] = BehaviorAnalyzer2DM(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
    table_name = sprintf('%s_%s_1T', ExpID, FileNames{file});
    AllActs(file).SessionName = table_name;
    AllActs(file).Acts = Acts;
    
    Distance(file) = BodyPartsTraces(Point.Center).AverageDistance;
    Velocity(file) = BodyPartsTraces(Point.Center).AverageSpeed;
    Duration(file) = Options.Duration;
    
    clear 'Acts' 'BodyPartsTraces';
end


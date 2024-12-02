%% paths and names

PathVideo = 'w:\Projects\RFC\BehaviorData\1_Raw\';
PathDLC = 'w:\Projects\RFC\BehaviorData\3_DLC\';
PathOut = 'w:\Projects\RFC\BehaviorData\4_RealTrack\';

PathPreset = 'w:\Projects\RFC\BehaviorData\';
FilenamePreset = 'RFC_Fxx_xD_Preset.mat';

FileNames = {
    'F01_1D', 'F06_1D','F08_1D', 'F12_1D', 'F05_1D', 'F19_1D', 'F11_1D',... % FAD-MK
    'F20_1D', 'F04_1D', 'F07_1D', 'F14_1D', 'F09_1D', 'F15_1D',... % FAD-SL
    'F26_1D', 'F29_1D', 'F34_1D', 'F36_1D', 'F38_1D', 'F42_1D', 'F31_1D', 'F41_1D', 'F53_1D', 'F54_1D',... % BL_MK
    'F28_1D', 'F30_1D', 'F40_1D', 'F32_1D', 'F37_1D', 'F48_1D', 'F43_1D', 'F35_1D', 'F52_1D',... % BL_SL
    'F01_3D', 'F06_3D','F08_3D', 'F12_3D', 'F05_3D', 'F19_3D', 'F11_3D',... % FAD-MK
    'F20_3D', 'F04_3D', 'F07_3D', 'F14_3D', 'F09_3D', 'F15_3D',... % FAD-SL
    'F26_3D', 'F29_3D', 'F34_3D', 'F36_3D', 'F38_3D', 'F31_3D', 'F41_3D', 'F53_3D', 'F54_3D',... % BL_MK
    'F28_3D', 'F30_3D', 'F40_3D', 'F32_3D', 'F37_3D', 'F48_3D', 'F43_3D', 'F35_3D', 'F52_3D' % BL_SL
    };


%% main part

for file = 31:length(FileNames)
    FilenameVideo = sprintf('RFC_%s.wmv', FileNames{file});
    FilenameDLC = sprintf('RFC_%sDLC_resnet50_RNF_2022Nov28shuffle1_300000.csv',FileNames{file});
    
    fprintf('Processing of RFC_%s\n', FileNames{file})
    
    [BodyPartsTraces] = BehaviorAnalyzerRFC(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
end
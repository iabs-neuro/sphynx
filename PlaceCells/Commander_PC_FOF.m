%% paths and names
FileNames = {
    'F26_1D' 'F28_1D' 'F01_1D' 'F06_1D' 'F29_1D' 'F30_1D',...
    'F20_1D' 'F08_1D' 'F34_1D' 'F36_1D' 'F38_1D' 'F40_1D',...
    'F04_1D' 'F07_1D' 'F37_1D' 'F12_1D' 'F14_1D' 'F09_1D',...
    'F48_1D' 'F05_1D' 'F43_1D' 'F10_1D' 'F35_1D' 'F31_1D',...
    'F15_1D' 'F41_1D' 'F52_1D' 'F11_1D' 'F53_1D' 'F54_1D',...
    'F26_2D' 'F28_2D' 'F01_2D' 'F06_2D' 'F29_2D' 'F30_2D',...
    'F20_2D' 'F08_2D' 'F34_2D' 'F36_2D' 'F38_2D' 'F40_2D',...
    'F04_2D' 'F07_2D' 'F37_2D' 'F12_2D' 'F14_2D' 'F09_2D',...
    'F48_2D' 'F05_2D' 'F43_2D' 'F10_2D' 'F35_2D' 'F31_2D',...
    'F15_2D' 'F41_2D' 'F52_2D' 'F11_2D' 'F53_2D' 'F54_2D',...
    'F26_3D' 'F28_3D' 'F01_3D' 'F06_3D' 'F29_3D' 'F30_3D',...
    'F20_3D' 'F08_3D' 'F34_3D' 'F36_3D' 'F38_3D' 'F40_3D',...
    'F04_3D' 'F07_3D' 'F37_3D' 'F12_3D' 'F14_3D' 'F09_3D',...
    'F48_3D' 'F05_3D' 'F43_3D' 'F10_3D' 'F35_3D' 'F31_3D',...
    'F15_3D' 'F41_3D' 'F52_3D' 'F11_3D' 'F53_3D' 'F54_3D'
    };

PathTraces = 'w:\Projects\FOF\ActivityData\Traces\';
PathSpikes = 'w:\Projects\FOF\ActivityData\Spikes\';
PathWorkSpaces = 'w:\Projects\FOF\ActivityData\Behav_mat\';
PathPresets = 'w:\Projects\FOF\ActivityData\Presets\';

PathOut = 'w:\Projects\RFC\ActivityData\PlaceCells\';

plot_opt = 1;

%% main

for file = 1:length(FileNames)
    
    fprintf('Processing of FOF_%s\n', FileNames{file})
    
    if file > 0 && file <= 17
        FileNamePreset = 'FOF_F26_1D_Preset.mat';
    elseif file > 17 && file <= 30
        FileNamePreset = 'FOF_F09_1D_Preset.mat';
    elseif file > 30 && file <= 47
        FileNamePreset = 'FOF_F26_2D_Preset.mat';
    elseif file > 47 && file <= 55
        FileNamePreset = 'FOF_F09_2D_Preset.mat';
    elseif file > 55 && file <= 60
        FileNamePreset = 'FOF_F41_2D_Preset.mat';
    elseif file > 60 && file <= 77
        FileNamePreset = 'FOF_F26_3D_Preset.mat';
    else
        FileNamePreset = 'FOF_F09_3D_Preset.mat';
    end
    
    FileNameWS = sprintf('FOF_%s_WorkSpace.mat',FileNames{file});
    FileNameTR = sprintf('FOF_%s_traces.csv',FileNames{file});
    FileNameSP = sprintf('FOF_%s_spikes.csv',FileNames{file});
    FileNamePR = sprintf('FOF_%s_Preset.mat',FileNames{file});
    
    if isfile(fullfile(PathTraces,FileNameTR))
        [FieldsIC] = PlaceFieldAnalyzerFOF(PathWorkSpaces,FileNameWS,PathTraces,FileNameTR,PathSpikes,FileNameSP,PathPresets,FileNamePreset,plot_opt,PathOut);
    end
    
end
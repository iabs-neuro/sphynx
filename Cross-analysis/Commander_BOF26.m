%% paths and filenames
ExpID = 'BOF';

PathVideo = sprintf('e:\\Projects\\%s\\BehaviorData\\2_Combined\\',ExpID);
PathDLC = sprintf('e:\\Projects\\%s\\BehaviorData\\3_DLC\\',ExpID);
PathPreset = sprintf('e:\\Projects\\%s\\BehaviorData\\4_Presets\\',ExpID);

PathOut = sprintf('e:\\Projects\\%s\\BehaviorData\\5_Behavior\\',ExpID);

FileNames = {
    'H02_1T','H03_1T','H04_1T','H06_1T','H07_1T','H10_1T','H11_1T','H12_1T','H13_1T','H14_1T','H15_1T','H16_1T','H17_1T','H22_1T','H26_1T','H27_1T','H31_1T','H32_1T','H39_1T', ...
    'H02_2T','H03_2T','H04_2T','H06_2T','H07_2T','H10_2T','H11_2T','H12_2T','H13_2T','H14_2T','H15_2T','H16_2T','H17_2T','H22_2T','H26_2T','H27_2T','H31_2T','H32_2T','H39_2T', ...
    'H02_3T','H03_3T','H04_3T','H06_3T','H07_3T','H10_3T','H11_3T','H12_3T','H13_3T','H14_3T','H15_3T','H16_3T','H17_3T','H22_3T','H26_3T','H27_3T','H31_3T','H32_3T','H39_3T', ...
    'H02_4T','H03_4T','H04_4T','H06_4T','H07_4T','H10_4T','H11_4T','H12_4T','H13_4T','H14_4T','H15_4T','H16_4T','H17_4T','H22_4T','H26_4T','H27_4T','H31_4T','H32_4T','H39_4T', ...
    'H02_5T','H03_5T','H04_5T','H06_5T','H07_5T','H10_5T','H11_5T','H12_5T','H13_5T','H14_5T','H15_5T','H16_5T','H17_5T','H22_5T','H26_5T','H27_5T','H31_5T','H32_5T','H39_5T' ...
    };

FilesNumber = length(FileNames);

%% main part

for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('BOF_%s.mp4', FileNames{file});
    FilenameDLC = sprintf('BOF_%sDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv', FileNames{file});
    FilenamePreset = sprintf('BOF_%s_Preset.mat', FileNames{file});
    
    fprintf('Processing of %s_%s\n', ExpID, FileNames{file});
    
    [~, ~, ~] = BehaviorAnalyzerBOF26(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, 1, 0, PathPreset, FilenamePreset);
    
end

%% ==========================
%  Batch Motion Activity Extraction
%  for all videos in folder
%  ==========================

clear; clc;

path = 'e:\Projects\CONS\BehaviorData\Cam2_side\2_Combined\';

% Search for common video formats
files_mp4 = dir(fullfile(path, '*.mp4'));
files_wmv = dir(fullfile(path, '*.wmv'));
files_avi = dir(fullfile(path, '*.avi'));
files_mkv = dir(fullfile(path, '*.mkv'));

files = [files_mp4; files_wmv; files_avi; files_mkv];

fprintf('Found %d video files.\n', numel(files));

for i = 1:numel(files)
    filename = files(i).name;
    fprintf('\n=== Processing %d / %d: %s ===\n', i, numel(files), filename);

    try
        ExtractMotionActivityAutoThreshold(path, filename, ...
            'PlotFigure', false, ...
            'SaveCsv', true, ...
            'SaveFigure', true, ...
            'ThresholdK', 6, ...
            'MaxSampleFrames', 300);
    catch ME
        fprintf('ERROR in file %s\n%s\n', filename, ME.message);
    end
end

disp('Batch processing finished.');
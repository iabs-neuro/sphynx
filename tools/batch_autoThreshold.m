%% Batch threshold estimation for multiple videos

%% -------- SELECT MULTIPLE VIDEOS --------
[files, folder] = uigetfile({'*.mp4;*.avi', 'Video files'}, ...
                            'Select videos for threshold estimation', ...
                            'MultiSelect', 'on');

if isequal(files, 0)
    error('No files selected.');
end

% If only one file selected → convert to cell
if ischar(files)
    files = {files};
end

N = numel(files);
thresholds = zeros(N, 1);    % array for thresholds
video_paths = cell(N, 1);    % store full paths

sample_seconds = 30;         % set default (change if needed)

fprintf('Selected %d videos.\n', N);

%% -------- PROCESS EACH VIDEO --------
for i = 1:N
    video_paths{i} = fullfile(folder, files{i});

    fprintf('\n=== Processing %s (%d/%d) ===\n', files{i}, i, N);

    thresholds(i) = autoThreshold(video_paths{i}, sample_seconds);

    fprintf('Threshold: %d\n', thresholds(i));
end

% -------- SHOW RESULTS --------
T = table(video_paths, thresholds, ...
          'VariableNames', {'Video', 'Threshold'});
disp(T);

%% OPTIONAL: save to CSV
output_csv = fullfile(folder, 'batch_thresholds.csv');
writetable(T, output_csv);
fprintf('\nSaved thresholds to: %s\n', output_csv);

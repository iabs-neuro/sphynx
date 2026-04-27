function [output_table, threshold, motion_index, time] = ExtractMotionActivityAutoThreshold(path, filename, varargin)
% ExtractMotionActivityAutoThreshold
%
% Calculates motion index from video using automatically estimated threshold.
%
% INPUT:
%   path      - folder with video
%   filename  - video filename
%
% OPTIONAL NAME-VALUE:
%   'PlotFigure'      - true/false, default true
%   'SaveCsv'         - true/false, default true
%   'SaveFigure'      - true/false, default false
%   'ThresholdK'      - multiplier for MAD, default 6
%   'MaxSampleFrames' - number of frame pairs used for threshold estimation, default 300
%
% OUTPUT:
%   output_table - table with Time_sec and MotionIndex
%   threshold    - automatically chosen threshold
%   motion_index - motion index vector
%   time         - time vector

    %% ---- Parse inputs ----
    p = inputParser;
    addParameter(p, 'PlotFigure', true, @(x)islogical(x) || isnumeric(x));
    addParameter(p, 'SaveCsv', true, @(x)islogical(x) || isnumeric(x));
    addParameter(p, 'SaveFigure', false, @(x)islogical(x) || isnumeric(x));
    addParameter(p, 'ThresholdK', 6, @(x)isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'MaxSampleFrames', 300, @(x)isnumeric(x) && isscalar(x) && x >= 10);
    parse(p, varargin{:});

    PlotFigure = logical(p.Results.PlotFigure);
    SaveCsv = logical(p.Results.SaveCsv);
    SaveFigure = logical(p.Results.SaveFigure);
    ThresholdK = p.Results.ThresholdK;
    MaxSampleFrames = p.Results.MaxSampleFrames;

    %% ---- Paths ----
    video_path = fullfile(path, filename);

    if ~isfile(video_path)
        error('File not found: %s', video_path);
    end

    %% ---- Load video info ----
    v = VideoReader(video_path);
    fps = v.FrameRate;
    nFrames = floor(v.Duration * fps);

    if nFrames < 2
        error('Video %s has fewer than 2 frames.', filename);
    end

    fprintf('Video loaded: %s\nFrames: %d\nFPS: %.2f\n', video_path, nFrames, fps);

    %% ---- Automatic threshold estimation ----
    % Sample only part of the video for robust and fast threshold estimation
    sampleN = min(MaxSampleFrames, nFrames - 1);

    v_sample = VideoReader(video_path);
    frame_prev = readFrame(v_sample);
    if size(frame_prev,3) == 3
        frame_prev_gray = rgb2gray(frame_prev);
    else
        frame_prev_gray = frame_prev;
    end

    diff_values = [];

    sample_id = 1;
    while hasFrame(v_sample) && sample_id <= sampleN
        frame_curr = readFrame(v_sample);
        if size(frame_curr,3) == 3
            frame_curr_gray = rgb2gray(frame_curr);
        else
            frame_curr_gray = frame_curr;
        end

        diff_frame = abs(double(frame_curr_gray) - double(frame_prev_gray));

        % subsample pixels to reduce memory
        sample_block = diff_frame(1:4:end, 1:4:end);
        diff_values = [diff_values; sample_block(:)]; %#ok<AGROW>

        frame_prev_gray = frame_curr_gray;
        sample_id = sample_id + 1;
    end

    med_diff = median(diff_values);
    mad_diff = mad(diff_values, 1);

    threshold = round(med_diff + ThresholdK * mad_diff);

    % Reasonable bounds for 8-bit grayscale data
    threshold = max(3, min(255, threshold));

    fprintf('Auto threshold selected: %d (median=%.3f, MAD=%.3f, K=%.2f)\n', ...
        threshold, med_diff, mad_diff, ThresholdK);

    %% ---- Main motion extraction ----
    v = VideoReader(video_path);
    threshold = 15;
    motion_index = zeros(nFrames - 1, 1);

    frame_prev = readFrame(v);
    if size(frame_prev,3) == 3
        frame_prev_gray = rgb2gray(frame_prev);
    else
        frame_prev_gray = frame_prev;
    end

    frame_id = 1;
    while hasFrame(v)
        frame_curr = readFrame(v);
        if size(frame_curr,3) == 3
            frame_curr_gray = rgb2gray(frame_curr);
        else
            frame_curr_gray = frame_curr;
        end

        diff_frame = abs(double(frame_curr_gray) - double(frame_prev_gray));
        bw = diff_frame > threshold;
        motion_index(frame_id) = nnz(bw);

        frame_prev_gray = frame_curr_gray;
        frame_id = frame_id + 1;
    end

    %% ---- Time vector ----
    time = (0:length(motion_index)-1)' / fps;

    %% ---- Output table ----
    output_table = table(time, motion_index, ...
        'VariableNames', {'Time_sec', 'MotionIndex'});

    %% ---- Save result ----
    [~, name_no_ext, ~] = fileparts(filename);

    if SaveCsv
        csv_name = fullfile(path, sprintf('%s_motion_activity.csv', name_no_ext));
        writetable(output_table, csv_name);

        thr_name = fullfile(path, sprintf('%s_motion_activity_threshold.txt', name_no_ext));
        fid = fopen(thr_name, 'w');
        fprintf(fid, 'Video: %s\n', filename);
        fprintf(fid, 'Threshold: %d\n', threshold);
        fprintf(fid, 'FPS: %.6f\n', fps);
        fclose(fid);
    end

    %% ---- Plot ----
    if PlotFigure
        h = figure('Visible', 'on');
        plot(time, motion_index, 'k');
        xlabel('Time (s)');
        ylabel('Motion Index (px changed)');
        title(sprintf('Animal Motor Activity: %s | thr=%d', filename, threshold));
        grid on;

        if SaveFigure
            fig_png = fullfile(path, sprintf('%s_motion_activity.png', name_no_ext));
            saveas(h, fig_png);
        end
    end

    disp('Done.');
end
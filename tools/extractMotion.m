function motion_index = extractMotion(video_path, threshold)
% extractMotion  – вычисляет уровень двигательной активности по видео
%
% Usage:
%   motion_index = extractMotion("video.mp4", 10);
%
% Inputs:
%   video_path  – путь к mp4
%   threshold   – порог детекции движения (рекомендуется 5–20)
%
% Output:
%   motion_index – временной ряд уровня активности (число изменённых пикселей)


%% ===== Load Video =====
v = VideoReader(video_path);
fps = v.FrameRate;
nFrames = floor(v.Duration * fps);

fprintf('Loaded video: %s\nFrames: %d\nFPS: %.2f\n', video_path, nFrames, fps);

%% ===== Initialization =====
motion_index = zeros(nFrames-1, 1);

frame_prev = readFrame(v);
frame_prev_gray = rgb2gray(frame_prev);

%% ===== Progress bar =====
h = waitbar(0, 'Processing video...');

%% ===== Main processing loop =====
frame_id = 1;

while hasFrame(v)
    frame_curr = readFrame(v);
    frame_curr_gray = rgb2gray(frame_curr);

    % Difference between frames
    diff_frame = abs(double(frame_curr_gray) - double(frame_prev_gray));

    % Threshold
    bw = diff_frame > threshold;

    % Motion index = number of changed pixels
    motion_index(frame_id) = sum(bw(:));

    % Update
    frame_prev_gray = frame_curr_gray;

    % Progress bar
    waitbar(frame_id/(nFrames-1), h);

    frame_id = frame_id + 1;
end

close(h);

%% ===== Time vector =====
time = (0:length(motion_index)-1)' / fps;

%% ===== Save Output =====
[folder, name, ~] = fileparts(video_path);
output_csv = fullfile(folder, name + "_motion_activity.csv");

T = table(time, motion_index, ...
          'VariableNames', {'Time_sec', 'MotionIndex'});
writetable(T, output_csv);

fprintf('Saved motion activity to: %s\n', output_csv);


%% ===== Plot Motion Index =====
figure('Name','Motion Activity');

subplot(2,1,1);
plot(time, motion_index, 'k');
title('Motion Index (raw)');
xlabel('Time (s)');
ylabel('Changed pixels');
grid on;

% Smoothed signal
smooth_index = movmean(motion_index, fps); % 1 second window

subplot(2,1,2);
plot(time, smooth_index, 'r');
title('Motion Index (smoothed, 1s)');
xlabel('Time (s)');
ylabel('Changed pixels');
grid on;

end

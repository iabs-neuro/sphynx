%% ==========================
%  Motion Activity Extraction
%  Author: ChatGPT (для твоих данных)
%  ==========================

clear; clc;

%% ====== INPUT ======
path = 'e:\Projects\CONS\BehaviorData\Cam2_side\2_Combined\';
filename = 'CONS_F28_1D_9T.mp4';
video_path = sprintf('%s%s', path, filename);   % укажи путь к видео
threshold = 17;                                 % порог бинаризации разницы кадров

%% ====== LOAD VIDEO ======
v = VideoReader(video_path);
fps = v.FrameRate;
nFrames = floor(v.Duration * fps);

fprintf('Video loaded: %s\nFrames: %d\nFPS: %.2f\n', video_path, nFrames, fps);

%% ====== INITIALIZE ======
motion_index = zeros(nFrames-1, 1);   % сюда будет записан уровень активности

%% ====== READ FIRST FRAME ======
frame_prev = readFrame(v);
frame_prev_gray = rgb2gray(frame_prev);

%% ====== PROCESS ALL FRAMES ======
frame_id = 1;

while hasFrame(v)
    frame_curr = readFrame(v);
    frame_curr_gray = rgb2gray(frame_curr);

    % --- DIFFERENCE BETWEEN FRAMES ---
    diff_frame = abs(double(frame_curr_gray) - double(frame_prev_gray));

    % --- THRESHOLD FOR MOTION ---
    bw = diff_frame > threshold;

    % Motion index — число изменённых пикселей
    motion_index(frame_id) = sum(bw(:));

    % Next iteration
    frame_prev_gray = frame_curr_gray;
    frame_id = frame_id + 1;
end

%% ====== TIME VECTOR ======
time = (0:length(motion_index)-1) / fps;

%% ====== PLOT RESULT ======
figure;
plot(time, motion_index, 'k');
xlabel('Time (s)');
ylabel('Motion Index (px changed)');
title('Animal Motor Activity');
grid on;

%% ====== SAVE RESULT ======
output_table = table(time', motion_index, ...
                     'VariableNames', {'Time_sec', 'MotionIndex'});
writetable(output_table, sprintf('%s//%s_motion_activity.csv', path, filename));

disp('Done! Saved motion_activity.csv');

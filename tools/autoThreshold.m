function threshold = autoThreshold(video_path, sample_seconds)
%% autoThreshold  – автоматически подбирает порог движения
%
% Usage:
%   threshold = autoThreshold("video.mp4", 10);
%   threshold = autoThreshold("video.mp4");        % sample_seconds = 10 по умолчанию
%   threshold = autoThreshold();                  % выбрать файл через диалог
%
% Inputs:
%   video_path      – путь к mp4 (string / char). Если не указан → uigetfile.
%   sample_seconds  – (опц.) сколько секунд анализировать.
%
% Output:
%   threshold – рекомендованный порог пиксельной разницы

% path = 'e:\Projects\CONS\BehaviorData\Cam2_side\2_Combined\'; 
% filename = 'CONS_F28_1D_9T.mp4'; 
% video_path = sprintf('%s%s', path, filename); % укажи путь к видео 
% sample_seconds = 5;

%% ===== Argument handling =====

if nargin == 0
    % No arguments → open file dialog
    [file, folder] = uigetfile({'*.mp4;*.avi', 'Video files'}, ...
                               'Select a video for threshold estimation');
    if isequal(file,0)
        error('No file selected.');
    end
    video_path = fullfile(folder, file);
    sample_seconds = 10; % default
    fprintf('Selected file: %s\n', video_path);

elseif nargin == 1
    % Only video_path given → use default duration
    sample_seconds = 10;
    fprintf('Using sample_seconds = 10 seconds\n');

elseif nargin == 2
    % Both provided → OK
    % nothing to do
else
    error('Too many input arguments.');
end

%% ===== Load video =====
v = VideoReader(video_path);
fps = v.FrameRate;

nFrames = min(round(sample_seconds * fps), floor(v.Duration * fps) - 1);

fprintf('Sampling first %d frames (%.1f sec)\n', nFrames, nFrames/fps);

%% ===== Read first frame =====
frame_prev = readFrame(v);
frame_prev_gray = rgb2gray(frame_prev);

all_diffs = [];

%% ===== Analyze frames =====

h = waitbar(0, 'Analyzing frames...');   % создать прогресс-бар

for i = 1:nFrames
    
    if ~hasFrame(v)
        break;
    end
    
    % обновить прогресс (от i/nFrames)
    waitbar(i / nFrames, h, sprintf('Processing frame %d of %d...', i, nFrames));
    
    frame_curr = readFrame(v);
    frame_curr_gray = rgb2gray(frame_curr);
    
    diff_frame = abs(double(frame_curr_gray) - double(frame_prev_gray));
    
    all_diffs = [all_diffs; diff_frame(:)];
    
    frame_prev_gray = frame_curr_gray;
end

close(h);   % закрыть прогресс-бар

%% ===== Estimate threshold from heavy-tailed distribution =====

all_diffs = double(all_diffs);   % ensure double

% --- 1. Classical Gaussian assumption (μ + kσ)
mu_val  = mean(all_diffs);
sigma_val = std(all_diffs);
thr_mu = mu_val + 3*sigma_val;      % soft

% --- 2. Percentiles (robust to heavy tails)
thr_p99 = prctile(all_diffs, 99);     % almost always pure motion

% --- 3. Median + MAD (robust estimator)
med_val = median(all_diffs);
mad_val = mad(all_diffs, 1);          % median absolute deviation
thr_mad = med_val + 6 * mad_val;      % robust heavy-tail rule

% --- 4. Gamma distribution match (shape k, scale θ)
mean_val = mu_val;
var_val  = var(all_diffs);

k_gamma = (mean_val^2) / var_val;
theta_gamma = var_val / mean_val;

% high quantile of gamma distribution (e.g., 99%)
thr_gamma = gaminv(0.99, k_gamma, theta_gamma);

%% ===== Combine thresholds =====

all_thresholds = [
    thr_mu
    thr_p99
    thr_mad
    thr_gamma
    ];

threshold = round(max(all_thresholds));   % take the most conservative

fprintf("\n======= Threshold Estimation =======\n");
fprintf("μ + 3σ:       %.2f\n", thr_mu);
fprintf("P99:          %.2f\n", thr_p99);
fprintf("Median + 6*MAD: %.2f\n", thr_mad);
fprintf("Gamma(0.99):    %.2f\n", thr_gamma);

fprintf("=== FINAL SELECTED THRESHOLD: %d ===\n\n", threshold);

%% ===== Visualization =====

figure('Name','Threshold Estimation', 'Position', [300 200 1000 650]);

thr_names = {'thr\_mu', 'thr\_p99', 'thr\_mad', 'thr\_gamma'};
thr_values = [thr_mu, thr_p99, thr_mad, thr_gamma];

colors = lines(length(thr_values));


% --------------------------------------------
% 1) ЛИНЕЙНЫЙ МАСШТАБ (Count)
% --------------------------------------------

subplot(2,1,1);
h = histogram(all_diffs, 'FaceColor',[0.75 0.75 0.95]);   % bins auto
hold on;

% рисуем пороги
for k = 1:length(thr_values)
    xline(thr_values(k), 'Color', colors(k,:), 'LineWidth', 1.5);
end

% итоговый порог
xline(threshold, 'r', 'LineWidth', 3);

xlabel('Pixel difference');
ylabel('Count');
title('Pixel Difference Distribution (Linear)');
grid on;

% легенда только для линий, не для гистограммы
legend_entries = [thr_names, {'FINAL'}];
legend_handles = gobjects(1, length(thr_values)+1);

for k = 1:length(thr_values)
    legend_handles(k) = xline(thr_values(k), 'Color', colors(k,:), 'LineWidth', 1.5);
end
legend_handles(end) = xline(threshold, 'r', 'LineWidth', 3);

legend(legend_handles, legend_entries, 'Location', 'northeast');


% --------------------------------------------
% 2) ЛОГАРИФМИЧЕСКИЙ МАСШТАБ (Count, not pdf)
% --------------------------------------------

subplot(2,1,2);
histogram(all_diffs, 'FaceColor',[0.75 0.75 0.95]);   % bins auto
hold on;

for k = 1:length(thr_values)
    xline(thr_values(k), 'Color', colors(k,:), 'LineWidth', 1.5);
end

xline(threshold, 'r', 'LineWidth', 3);

set(gca, 'YScale', 'log');   % log по Count

xlabel('Pixel difference');
ylabel('Count (log scale)');
title('Pixel Difference Distribution (Log scale)');
grid on;

hold off;

[folder, name, ~] = fileparts(video_path);
saveas(gcf, fullfile(folder, [name '_thresholds.png']));
close(gcf);
end

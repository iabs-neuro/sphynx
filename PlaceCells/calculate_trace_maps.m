function [N_freq, N_freq_sm, N_freq_sm_ref, N_freq_sm_ref_norm, max_bin] = ...
    calculate_trace_maps(trace, x_ind, y_ind, ...
    size_map, mask_t, occupancy_map, ...
    activity_map_opt, kernel_opt)

% CALCULATE_TRACE_MAPS Вычисляет карты активности по сырому сигналу
%
% Входные параметры:
%   trace - массив сырой кальциевой активности
%   y_ind, x_ind - скорректированные координаты животного
%   size_map - структура с полем size_map
%   mask_t - маска границ для свертки
%   occupancy_map - карта размещения животного
%   kernel_opt - параметры ядер для свертки, размер и сигма:
%   	trace.size, trace.sigma - для трейс карт
%   activity_map_opt.trace.smooth - флаг сглаживания трейс карт
%   activity_map_opt.trace.threshold - порог для трейс карт (доля от максимума)

% Выходные параметры:
%   N_freq - трейс карта
%   N_freq_sm - сглаженная трейс карта
%   N_freq_sm_ref - подрезанная трейс карта
%   N_freq_sm_ref_norm - нормированная трейс карта

%% 1. Original trace map (sum of calcium signals per position)

frames = length(trace);
N_freq = zeros(size_map);
for frame = 1:frames
    N_freq(y_ind(frame), x_ind(frame)) = ...
        N_freq(y_ind(frame), x_ind(frame)) + trace(frame);
end

N_freq = N_freq./occupancy_map;
N_freq(isnan(N_freq)) = 0;
N_freq(isinf(N_freq)) = 0;
max_bin.trace = max(N_freq(:));

%% 2. Smoothed trace map

if activity_map_opt.trace.smooth
    [N_freq_sm, ~] = convolution_with_holes(...
        N_freq, ...
        mask_t, ...
        kernel_opt.trace.size, ...
        kernel_opt.trace.sigma);
else
    N_freq_sm = N_freq;
end
max_bin.trace_refined = max(N_freq_sm(:));

%% 3. Thresholded trace map

N_freq_sm_ref = N_freq_sm;
if activity_map_opt.trace.threshold
    N_freq_sm_ref(N_freq_sm_ref < activity_map_opt.trace.threshold * max_bin.trace_refined) = 0;
end

%% 4 Нормализация карты спайков (объем нормирован на 1)
N_freq_sm_ref_norm = N_freq_sm_ref/sum(N_freq_sm_ref(:));

end
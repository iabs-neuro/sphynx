function [N, N_sm, N_sm_ref, N_sm_ref_norm, N_freq, N_freq_sm, N_freq_sm_ref, N_freq_sm_ref_norm, max_bin] = ...
    calculate_firing_rate_maps(spikes, x_ind, y_ind, ...
    size_map, mask_t, time_smoothed, ...
    activity_map_opt, kernel_opt)

% CALCULATE_FIRING_RATE_MAPS Вычисляет карты спайков и частоты спайков
%
% Входные параметры:
%   spikes - массив индексов спайков
%   y_ind, x_ind - скорректированные координаты животного
%   size_map - структура с полем size_map
%   mask_t - маска границ для свертки
%   kernel_opt - параметры ядер для свертки, размер и сигма:
%       small.size, small.sigma - для карт спайков
%       big.size, big.sigma - для карт активности
%   activity_map_opt.spike.smooth - флаг сглаживания карты спайков
%   activity_map_opt.spike.threshold  - порог для карты спайков (доля от максимума)
%   activity_map_opt.firing.smooth - флаг сглаживания карты частоты
%   activity_map_opt.firing.threshold - порог для карты частоты (доля от максимума)

% Выходные параметры:
%   N - исходная карта спайков
%   N_sm - сглаженная карта спайков
%   N_sm_ref - подрезанная карта спайков
%   N_sm_ref_norm - нормированная карта спайков
%   N_freq - карта частоты спайков
%   N_freq_sm - сглаженная карта частоты
%   N_freq_sm_ref - подрезанная карта частоты
%   N_freq_sm_ref_norm - нормированная карта частоты

%% 1. Расчет исходной карты спайков

N = zeros(size_map);
for k = 1:length(spikes)
    N(y_ind(spikes(k)),x_ind(spikes(k))) = N(y_ind(spikes(k)),x_ind(spikes(k))) + 1;
end
max_bin.spike = max(N(:));

%% 2. Сглаживание карты спайков

if activity_map_opt.spike.smooth
    [N_sm, ~] = convolution_with_holes(N, mask_t, kernel_opt.small.size, kernel_opt.small.sigma);
else
    N_sm = N;
end
max_bin.spike_refined = max(N_sm(:));

%% 3. Пороговая обработка карты спайков

N_sm_ref = N_sm;
if activity_map_opt.spike.threshold > 0
    max_val = max(N_sm(:));
    if max_val > 0
        N_sm_ref(N_sm_ref < activity_map_opt.spike.threshold * max_val) = 0;
    end
end

% 3.5 Нормализация карты спайков (объем нормирован на 1)
N_sm_ref_norm = N_sm_ref/sum(N_sm_ref(:));

%% 4. Расчет карты частоты спайков

N_freq = N_sm_ref ./ time_smoothed;
N_freq(isnan(N_freq)) = 0;
N_freq(isinf(N_freq)) = 0;
max_bin.firingrate = max(N_freq(:));

%% 5. Сглаживание карты частоты

if activity_map_opt.firing.smooth
    [N_freq_sm, ~] = convolution_with_holes(N_freq, mask_t, kernel_opt.big.size, kernel_opt.big.sigma);
else
    N_freq_sm = N_freq;
end
max_bin.firingrate_refined = max(N_freq_sm(:));

%% 6. Пороговая обработка карты частоты

N_freq_sm_ref = N_freq_sm;
if activity_map_opt.firing.threshold > 0
    max_val = max(N_freq_sm(:));
    if max_val > 0
        N_freq_sm_ref(N_freq_sm_ref < activity_map_opt.firing.threshold * max_val) = 0;
    end
end

% 6.5 Нормализация карты спайков
N_freq_sm_ref_norm = N_freq_sm_ref/sum(N_freq_sm_ref(:));

end
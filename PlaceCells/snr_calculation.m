function SNR = snr_calculation(ts, method, snr_params)

    % SNR_calculation - вычисляет SNR двумя методами: baseline и peak.
    %
    % Входные параметры:
    %   ts     - временной ряд (вектор).
    %   method - метод вычисления SNR ('baseline' или 'peak').
    %   snr_params - структура с дополнительными параметрами (только для 'baseline'):
    %       snr_params.percentile - процент значений для оценки базовой линии (по умолчанию 20).
    %
    % Выход:
    %   SNR - рассчитанное значение SNR в dB.
    
%     % for debugging
%     ts = CellInfo(cell).trace;
%     method = 'baseline';
%     method = 'peak';

    if nargin < 3
        snr_params = struct();
    end

    % Установка параметров по умолчанию
    if strcmpi(method, 'baseline')
        if ~isfield(snr_params, 'percentile')
            snr_params.percentile = 20; % Процент значений для базовой линии (по умолчанию 20)
        end
    end

    % Проверка метода
    switch lower(method)
        case 'baseline'
            % Метод baseline
            baseline = mean(ts(ts < prctile(ts, snr_params.percentile)));   % Нижние проценты как шум
            noise = ts(ts < baseline + std(ts(ts < baseline)));             % Участки шума
            signal_variance = var(ts);                                      % Общая дисперсия сигнала
            noise_variance = var(noise);                                    % Дисперсия шума
            SNR = 10 * log10(signal_variance / noise_variance);             % Отношение сигнал/шум

        case 'peak'
            % Метод peak
            peak_signal = max(ts);                                          % Пиковое значение сигнала
            baseline_noise = ts(ts < mean(ts) + std(ts));                   % Участки шума
            noise_variance = var(baseline_noise);                           % Дисперсия шума
            SNR = 10 * log10(peak_signal^2 / noise_variance);               % Отношение пиковый сигнал/шум

        otherwise
            error('Метод "%s" не поддерживается. Используйте "baseline" или "peak".', method);
    end
end

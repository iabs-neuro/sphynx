function amplitude_extraction(cells)

amplitude_range = 20; % колво кадров до и после кадра кальциевого события, для поиска амплитуды

%% Инициализация искусственных данных (для примера)
% if ~exist('file_NV_orig', 'var') || ~exist('file_TR', 'var')
%     rng(42); % Фиксируем случайные числа
%     num_frames = 1000;
%     num_cells = 5;
%     
%     % Создаём смешанные данные: некоторые колонки - строго 0/1, другие - произвольные числа
%     file_NV_orig = zeros(num_frames, num_cells);
%     for n = 1:num_cells
%         if n <= 3 % Первые 3 колонки - спайки (только 0 и 1)
%             file_NV_orig(:,n) = double(rand(num_frames,1) > 0.95); % Редкие спайки (5%)
%         else % Остальные - амплитуды
%             file_NV_orig(:,n) = 0.2 + 0.8*rand(num_frames,1); % Случайные значения 0.2-1.0
%         end
%     end
%     
%     file_TR = 5 + 3*randn(num_frames, num_cells); % Амплитуды спайков
%     mouse.duration_min = 10;
%     session.duration_frames = num_frames;
%     NV_start = 1;
% end

%% Основной код обработки

for ncell = 1:size(cells,2)
%     current_data = cells(ncell).trace;
    current_data = cells(ncell).spikes;
    
    % Проверка на строго бинарные данные (0 и 1)
    is_binary = all(ismember(unique(current_data), [0, 1]));
    
    if is_binary
        % Обработка спайков (только 0 и 1)
        spikes_frames = find(current_data == 1); % Явно ищем единицы
        % !!! добавить цикл
        spikes_amplitudes = max(file_TR(spikes_frames-amplitude_range:spikes_frames+amplitude_range, ncell)); % !!! либо искать в небольшом диапазоне
    else
        % Обработка амплитуд (любые значения)
        spikes_frames = find(current_data);
        spikes_amplitudes = current_data(spikes_frames);
    end
    
    % Сохраняем результаты

    if ~isempty(spikes_amplitudes)
        cells(ncell).spikes_all_peak_amplitude = max(spikes_amplitudes);
        cells(ncell).spikes_all_mean_amplitude = mean(spikes_amplitudes);
    else
        cells(ncell).spikes_all_peak_amplitude = NaN;
        cells(ncell).spikes_all_mean_amplitude = NaN;
    end
end

%% Визуализация (пример)
% figure;
% for n = 1:min(3, num_cells
%     subplot(3,1,n);
%     if cells(n).is_binary
%         stem(cells(n).spikes_frames, cells(n).amplitudes, 'filled', 'Color','b');
%         title(sprintf('Нейрон %d: спайки (0/1)', n));
%     else
%         stem(cells(n).spikes_frames, cells(n).amplitudes, 'filled', 'Color','r');
%         title(sprintf('Нейрон %d: амплитуды', n));
%     end
%     xlabel('Кадр'); ylabel('Амплитуда');
% end
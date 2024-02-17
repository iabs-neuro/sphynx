function [BinnedSignal] = BinarizationArrayMany(OriginalSignal, DownsamplingFactor)
% 16.02.24 vvp
%%
% OriginalSignal = TraceThis(:,1);
% DownsamplingFactor = 29.7867;

% Рассчитываем количество усредняемых интервалов
NumIntervals = floor(size(OriginalSignal, 1) / DownsamplingFactor);
fprintf('Binarization start\nDownsamplingFactor: %2.4f,  %d seconds\n',DownsamplingFactor, NumIntervals);

% Усреднение каждых N значений
BinnedSignal = zeros(NumIntervals, size(OriginalSignal, 2));

for col = 1:size(OriginalSignal, 2)
    for i = 1:NumIntervals
        StartIndex = round((i - 1) * DownsamplingFactor + 1);
        EndIndex = round(i * DownsamplingFactor);
        BinnedSignal(i, col) = mean(OriginalSignal(StartIndex:EndIndex, col));
    end
end

end

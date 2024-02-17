function [BinnedSignal] = BinarizationArray(OriginalSignal, DownsamplingFactor)
% 16.02.24 vvp
%%
% OriginalSignal = TraceThis(:,1);
% DownsamplingFactor = 29.7867;

% Рассчитываем количество усредняемых интервалов
NumIntervals = floor(length(OriginalSignal) / DownsamplingFactor);
fprintf('Binarization start\nDownsamplingFactor: %2.4f,  %d seconds\n ',DownsamplingFactor, NumIntervals);

% Усреднение каждых N значений
BinnedSignal = zeros(NumIntervals, 1);

for i = 1:NumIntervals
    StartIndex = round((i - 1) * DownsamplingFactor + 1);
    EndIndex = round(i * DownsamplingFactor);
    BinnedSignal(i) = mean(OriginalSignal(StartIndex:EndIndex));
end

end


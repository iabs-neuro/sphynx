function FPS = GetFPS(array)
% 16.02.24 vvp. Just searching fps when you exactly know time and no one
% dropped frames

Time = 1294; % Time for Trace exp in seconds

NumFrames = length(array);

FPS = NumFrames/Time;

end
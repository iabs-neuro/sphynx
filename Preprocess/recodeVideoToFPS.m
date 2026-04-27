function [new_video, new_csv] = recodeVideoToFPS(video_file, csv_file, wrongDir, targetFPS, codec)

[~, name, ext] = fileparts(video_file);

%% === Чтение timestamps ===
ts = readmatrix(csv_file);
N = numel(ts);
duration = (ts(end) - ts(1)) / 1e7;

newN = round(targetFPS * duration);
keep_idx = round(linspace(1, N, newN));

%% === Новый CSV ===
new_csv = fullfile(wrongDir, [name '_recoded.csv']);
writematrix(ts(keep_idx), new_csv);

%% === Новый видеофайл ===
new_video = fullfile(wrongDir, [name '_recoded' ext]);


%% === Приведение Codec к ffmpeg виду ===
codecMap = struct( ...
    'copy', 'copy', ...
    'H264', 'libx264', ...
    'h264', 'libx264', ...
    'MPEG4', 'mpeg4', ...
    'HEVC', 'libx265', ...
    'ProRes', 'prores_ks' ...
);

if isfield(codecMap, codec)
    ffcodec = codecMap.(codec);
else
    fprintf("Неизвестный кодек '%s', использую libx264.\n", codec);
    ffcodec = 'libx264';
end


%% === Создание списка кадров для ffmpeg select ===
% пример синтаксиса: select='eq(n\,0)+eq(n\,15)+eq(n\,30)'
expr = sprintf('eq(n\\,%d)', keep_idx(1)-1);  % ffmpeg считает кадры с нуля!

for k = 2:numel(keep_idx)
    expr = sprintf('%s+eq(n\\,%d)', expr, keep_idx(k)-1);
end


%% === Команда ffmpeg ===
cmd = sprintf( ...
    'ffmpeg -loglevel error -y -i "%s" -vf "select=%s" -vsync 0 -r %d -c:v %s "%s"', ...
    video_file, expr, targetFPS, ffcodec, new_video);

status = system(cmd);


%% === Проверка ошибок ===
if status ~= 0
    error("Ошибка ffmpeg при перекодировании %s", video_file);
end

end

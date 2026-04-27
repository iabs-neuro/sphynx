function M = getVideoMetadata(video_file)
vr = VideoReader(video_file);

M.filename = video_file;
M.fps = vr.FrameRate;
M.duration_s = round(vr.Duration, 2);
M.duration_min = round(M.duration_s/60,2);
M.width = vr.Width;
M.height = vr.Height;
M.numFrames = vr.NumFrames;

try
    info = ffprobe(video_file);
    M.codec = info.streams.codec_name;
catch
    M.codec = 'unknown';
end

% VideoReader не всегда даёт точное число кадров, вычисляем так:
M.numFrames_est = round(M.duration_s * M.fps);
end

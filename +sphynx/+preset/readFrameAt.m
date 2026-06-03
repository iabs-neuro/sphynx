function frame = readFrameAt(videoPath, frameIndex, frameRate)
% READFRAMEAT  Robust frame read by index for VFR-friendly h264.
%
%   frame = sphynx.preset.readFrameAt(videoPath, frameIndex, frameRate)
%
%   Seeks via CurrentTime = (frameIndex-1)/frameRate then readFrame.
%   Falls back to read(v, 1) if the time seek lands past the end of
%   the file (VFR clips often have effective duration < NumFrames/fps).
%
%   `frameRate` is passed in (rather than read from the VideoReader)
%   because the caller already has the corrected value via
%   sphynx.preset.correctedFrameCount.
    v = VideoReader(videoPath);
    fps = frameRate;
    if ~isfinite(fps) || fps <= 0
        fps = v.FrameRate;
    end
    t = max(0, (frameIndex - 1) / fps);
    if t < v.Duration
        v.CurrentTime = t;
        if hasFrame(v)
            frame = readFrame(v);
            return;
        end
    end
    % Seek landed past end -- fall back to first frame
    sphynx.util.log('warn', ...
        '[readFrameAt] frame %d (t=%.3fs) past end of %.3fs video; falling back to frame 1', ...
        frameIndex, t, v.Duration);
    frame = read(v, 1);
end

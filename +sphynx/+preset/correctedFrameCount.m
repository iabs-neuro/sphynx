function n = correctedFrameCount(numFrames, durationS, frameRate)
%CORRECTEDFRAMECOUNT  Robust frame count for VideoReader, working around
% R2020a's NumFrames bug on VFR h264 MP4.
%
%   n = sphynx.preset.correctedFrameCount(numFrames, durationS, frameRate)
%
%   If `numFrames` is NaN, <= 0, or differs from `durationS*frameRate`
%   by more than 5%, return the duration-based estimate (which is
%   accurate for any video where duration and frame rate are reliable).
%   Otherwise return `numFrames` unchanged.
%
%   The same logic also covers the symmetric case where `numFrames`
%   is much larger than `Duration*FrameRate` (e.g. a corrupt header).
%
%   If the fallback cannot be computed (durationS or frameRate <= 0,
%   or NaN), return the original `numFrames` unchanged -- caller decides
%   how to handle.
    canFallback = isfinite(durationS) && durationS > 0 && ...
                  isfinite(frameRate) && frameRate > 0;
    if ~canFallback
        n = numFrames;
        return;
    end
    fallback = round(durationS * frameRate);
    if ~isfinite(numFrames) || numFrames <= 0
        n = fallback;
        return;
    end
    relErr = abs(numFrames - fallback) / max(fallback, 1);
    % 5% threshold catches gross VideoReader bugs (NumFrames=2 for VFR
    % h264 is ~100% off) while tolerating frame-count rounding drift
    % between Duration*FrameRate and the true frame count.
    if relErr > 0.05
        n = fallback;
    else
        n = numFrames;
    end
end

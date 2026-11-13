function b = backing(headX, headY, centerX, centerY, frameRate, pixelsPerCm, varargin)
% BACKING  Frames where the animal moves backwards (tail first).
%
%   b = sphynx.acts.backing(headX, headY, centerX, centerY, frameRate, pixelsPerCm, ...)
%
%   The heading is the vector centre -> head. The centre velocity is
%   projected on it: the signed speed along the body axis. Backing is a
%   negative signed speed, i.e. the body centre moves away from where the
%   head points. On a linear track this is "speed sign opposite to the
%   facing direction"; the same rule works in any arena.
%
%   Inputs are 1xN (or Nx1) smoothed pixel coordinates.
%
%   Name-value:
%     'MinSpeedCmS'    backward speed along the body axis, cm/s (default 1)
%     'MaxCos'         cosine between velocity and heading must be at
%                      most this (default -0.7, i.e. within ~45 deg of
%                      straight backwards); rejects sideways motion
%     'MinHeadingCm'   centre-to-head distance, cm (default 1). Shorter
%                      means a curled or rearing animal whose heading
%                      is not reliable
%     'VelocityWindowSec'  half-width of the central difference (default 0.1)
%     'XKcorr'         x scale correction (default 1)
%
%   Output: 1xN logical. Run-length cleanup (minimum duration, gap
%   bridging) is left to the caller, as for every library act.

    p = inputParser;
    addParameter(p, 'MinSpeedCmS', 1, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'MaxCos', -0.7, @(v) isnumeric(v) && isscalar(v) && v >= -1 && v <= 1);
    addParameter(p, 'MinHeadingCm', 1, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'VelocityWindowSec', 0.1, @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'XKcorr', 1, @(v) isnumeric(v) && isscalar(v) && v > 0);
    parse(p, varargin{:});
    o = p.Results;

    headX = headX(:)'; headY = headY(:)'; centerX = centerX(:)'; centerY = centerY(:)';
    n = numel(centerX);

    % Heading in cm, x corrected so both axes share one scale.
    hx = (headX - centerX) * o.XKcorr / pixelsPerCm;
    hy = (headY - centerY) / pixelsPerCm;
    hLen = hypot(hx, hy);

    [vx, vy] = centralVelocity(centerX * o.XKcorr / pixelsPerCm, ...
        centerY / pixelsPerCm, frameRate, o.VelocityWindowSec);
    speed = hypot(vx, vy);

    vAlong = (vx .* hx + vy .* hy) ./ hLen;    % signed speed along the body axis
    cosVH = vAlong ./ speed;

    b = hLen >= o.MinHeadingCm & vAlong <= -o.MinSpeedCmS & cosVH <= o.MaxCos;
    b(~isfinite(vAlong) | ~isfinite(cosVH)) = false;
    b = reshape(b, 1, n);
end

function [vx, vy] = centralVelocity(x, y, frameRate, halfSec)
    % Central difference over +-k frames: a frame-to-frame difference is
    % dominated by tracking jitter at walking speeds of a few cm/s.
    n = numel(x);
    k = max(1, round(halfSec * frameRate));
    vx = nan(1, n); vy = nan(1, n);
    if n < 2 * k + 1; return; end
    idx = (k + 1):(n - k);
    dt = 2 * k / frameRate;
    vx(idx) = (x(idx + k) - x(idx - k)) / dt;
    vy(idx) = (y(idx + k) - y(idx - k)) / dt;
end

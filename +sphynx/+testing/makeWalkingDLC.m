function fixture = makeWalkingDLC(speedCmS, durationS, varargin)
% MAKEWALKINGDLC  Synthetic mouse walking in a straight line.
%
%   fixture = sphynx.testing.makeWalkingDLC(speedCmS, durationS)
%
%   Outputs:
%     x, y         - Nx1 traces (pixels)
%     frameRate    - Hz
%     pxlPerCm     - calibration
%     n_frames
%     expectedSpeedCmS

    p = inputParser;
    addParameter(p, 'FrameRate', 30, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'PixelsPerCm', 5, @(v) isnumeric(v) && v > 0);
    parse(p, varargin{:});
    fr = p.Results.FrameRate;
    ppc = p.Results.PixelsPerCm;

    n = round(durationS * fr);
    pxlPerFrame = speedCmS / fr * ppc;
    fixture.x = 100 + (0:n-1)' * pxlPerFrame;
    fixture.y = ones(n, 1) * 100;
    fixture.frameRate = fr;
    fixture.pxlPerCm = ppc;
    fixture.n_frames = n;
    fixture.expectedSpeedCmS = speedCmS;
end

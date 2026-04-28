function fixture = makeJumpyDLC(spikeFrame, spikeMagnitudePxl, varargin)
% MAKEJUMPYDLC  Walking trace with one DLC-style spike.
%
%   fixture = sphynx.testing.makeJumpyDLC(spikeFrame, spikePxl, ...)
%
%   Returns a 200-frame walking trace (10 cm/s by default) with
%   x(spikeFrame) shifted by spikeMagnitudePxl, simulating a DLC
%   tracking outlier.

    p = inputParser;
    addParameter(p, 'BaseSpeedCmS', 10);
    addParameter(p, 'NFrames', 200);
    addParameter(p, 'FrameRate', 30);
    addParameter(p, 'PixelsPerCm', 5);
    parse(p, varargin{:});

    f = sphynx.testing.makeWalkingDLC(p.Results.BaseSpeedCmS, ...
        p.Results.NFrames / p.Results.FrameRate, ...
        'FrameRate', p.Results.FrameRate, ...
        'PixelsPerCm', p.Results.PixelsPerCm);
    f.x(spikeFrame) = f.x(spikeFrame) + spikeMagnitudePxl;
    f.spikeFrame = spikeFrame;
    f.spikeMagnitudePxl = spikeMagnitudePxl;
    fixture = f;
end

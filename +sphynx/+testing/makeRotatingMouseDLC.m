function fixture = makeRotatingMouseDLC(totalRotationDeg, durationS, varargin)
% MAKEROTATINGMOUSEDLC  Synthetic mouse rotating uniformly in place.
%
%   fixture = sphynx.testing.makeRotatingMouseDLC(degrees, durationS)
%   returns a struct with simulated head-tip and head-center traces
%   for a mouse rotating uniformly through `degrees` over `durationS`.
%
%   Optional name-value:
%     'FrameRate'     - default 30
%     'NoseRadiusCm'  - default 1.5
%
%   Output struct:
%     headTipX, headTipY, headCenterX, headCenterY  - Nx1 traces (cm)
%     frameRate, n_frames
%     expectedTotalRotationRad

    p = inputParser;
    addParameter(p, 'FrameRate', 30, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'NoseRadiusCm', 1.5, @(v) isnumeric(v) && v > 0);
    parse(p, varargin{:});
    fr = p.Results.FrameRate;
    rNose = p.Results.NoseRadiusCm;

    n = round(durationS * fr);
    t = (0:n-1)' / fr;
    angRad = deg2rad(totalRotationDeg) * t / durationS;

    fixture.headCenterX = zeros(n,1);
    fixture.headCenterY = zeros(n,1);
    fixture.headTipX = rNose * cos(angRad);
    fixture.headTipY = rNose * sin(angRad);
    fixture.frameRate = fr;
    fixture.n_frames = n;
    fixture.expectedTotalRotationRad = deg2rad(totalRotationDeg);
end

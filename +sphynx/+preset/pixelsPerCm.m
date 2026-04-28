function [pxlPerCm, x_kcorr] = pixelsPerCm(frame, varargin)
% PIXELSPERCM  Calibrate pixels-per-cm by clicking 4 reference points.
%
%   [pxlPerCm, x_kcorr] = sphynx.preset.pixelsPerCm(frame)
%
%   Interactive: shows `frame`, asks the user to click 4 points
%   (2 vertical pair, 2 horizontal pair), then asks for the cm
%   distance between each pair. Returns the average pxl/cm and the
%   x-axis correction factor (in case x and y scales differ).
%
%   Optional name-value (for headless / testing — bypass ginput):
%     'Points'        4x2 matrix of pre-clicked points [x y]
%     'DistancesCm'   1x2 cm distances [d_vertical, d_horizontal]
%
%   Ported from legacy functions/CalculatePxlInCm.m. Behavior matches
%   when no override is supplied.
%
%   Bug-warning thresholds: if the two scales differ by > 3% the
%   function uses the y-axis value and reports an x correction factor;
%   otherwise it averages.

    p = inputParser;
    addRequired(p, 'frame');
    addParameter(p, 'Points', []);
    addParameter(p, 'DistancesCm', []);
    addParameter(p, 'PercentThreshold', 3);
    addParameter(p, 'Visible', true);
    parse(p, frame, varargin{:});

    if isempty(p.Results.Points)
        if p.Results.Visible
            imshow(frame);
            title('Click 4 points: 2 vertical pair, 2 horizontal pair (order matters)');
        end
        [xPts, yPts] = ginput(4);
    else
        xPts = p.Results.Points(:, 1);
        yPts = p.Results.Points(:, 2);
    end

    distancePixelsY = sqrt((yPts(2) - yPts(1))^2);
    distancePixelsX = sqrt((xPts(4) - xPts(3))^2);

    if isempty(p.Results.DistancesCm)
        distanceCmY = input('How many cm between point 1 and 2? ');
        distanceCmX = input('How many cm between point 3 and 4? ');
    else
        distanceCmY = p.Results.DistancesCm(1);
        distanceCmX = p.Results.DistancesCm(2);
    end

    pxlY = distancePixelsY / distanceCmY;
    pxlX = distancePixelsX / distanceCmX;

    diffPct = abs(pxlX - pxlY) / pxlX * 100;
    if diffPct > p.Results.PercentThreshold
        pxlPerCm = pxlY;
        x_kcorr = pxlY / pxlX;
        sphynx.util.log('warn', 'X/Y scales differ by %.1f%%; using Y, x_kcorr=%.3f', diffPct, x_kcorr);
    else
        pxlPerCm = (pxlY + pxlX) / 2;
        x_kcorr = 1;
    end
end

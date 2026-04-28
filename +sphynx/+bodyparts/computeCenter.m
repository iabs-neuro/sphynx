function [xc, yc] = computeCenter(BodyPartsX, BodyPartsY, Point)
% COMPUTECENTER  Get the body-center trace, falling back to (Left+Right)/2.
%
%   [xc, yc] = sphynx.bodyparts.computeCenter(BodyPartsX, BodyPartsY, Point)
%
%   Inputs:
%     BodyPartsX, BodyPartsY  - PartsxN matrices of cleaned body-part traces
%     Point                   - struct from sphynx.bodyparts.identifyParts
%
%   Output:
%     xc, yc - 1xN body-center trace
%
%   If Point.Center is non-empty, returns the corresponding row directly.
%   Otherwise falls back to the mean of LeftBodyCenter and RightBodyCenter
%   (legacy BehaviorAnalyzer.m:285-294 logic).
%   Errors if neither path is available.

    if ~isempty(Point.Center)
        xc = BodyPartsX(Point.Center, :);
        yc = BodyPartsY(Point.Center, :);
        return;
    end

    if ~isempty(Point.LeftBodyCenter) && ~isempty(Point.RightBodyCenter)
        xc = (BodyPartsX(Point.LeftBodyCenter, :) + BodyPartsX(Point.RightBodyCenter, :)) / 2;
        yc = (BodyPartsY(Point.LeftBodyCenter, :) + BodyPartsY(Point.RightBodyCenter, :)) / 2;
        return;
    end

    error('sphynx:computeCenter:noCenter', ...
        'No Center body part and no Left/RightBodyCenter to fall back to');
end

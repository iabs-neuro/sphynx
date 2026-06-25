function [xc, yc] = computeCenter(BodyPartsX, BodyPartsY, Point)
% COMPUTECENTER  Get the body-center trace.
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
%   Resolution order:
%     1. Point.Center is set        -> use that row directly
%     2. Point.LeftBodyCenter and Point.RightBodyCenter set
%                                   -> mean of the two
%     3. Neither set                -> synthetic center = mean of every
%                                      body part (with NaN ignored).
%                                      Logged as a warning, never an
%                                      error -- so a DLC schema with
%                                      unfamiliar names still goes
%                                      through Make-video and friends
%                                      while the user updates the
%                                      synonymMap in identifyParts.
%
%   Returns NaN rows if the input matrices are empty.

    if isempty(BodyPartsX) || isempty(BodyPartsY)
        xc = nan(1, 0);
        yc = nan(1, 0);
        return;
    end

    if isfield(Point, 'Center') && ~isempty(Point.Center)
        xc = BodyPartsX(Point.Center, :);
        yc = BodyPartsY(Point.Center, :);
        return;
    end

    if isfield(Point, 'LeftBodyCenter') && ~isempty(Point.LeftBodyCenter) ...
            && isfield(Point, 'RightBodyCenter') && ~isempty(Point.RightBodyCenter)
        xc = (BodyPartsX(Point.LeftBodyCenter, :) + BodyPartsX(Point.RightBodyCenter, :)) / 2;
        yc = (BodyPartsY(Point.LeftBodyCenter, :) + BodyPartsY(Point.RightBodyCenter, :)) / 2;
        return;
    end

    % Last resort: synthesise a center from the mean of every body part.
    % Better a noisy estimate than a hard failure that aborts Make-video,
    % rendering, or session analysis when an unknown DLC schema lands.
    sphynx.util.log('warn', ['computeCenter: no Center / Left+Right body parts ' ...
        'in this DLC -- using mean of all %d body parts as synthetic center. ' ...
        'Extend sphynx.bodyparts.identifyParts synonymMap to silence.'], ...
        size(BodyPartsX, 1));
    xc = mean(BodyPartsX, 1, 'omitnan');
    yc = mean(BodyPartsY, 1, 'omitnan');
end

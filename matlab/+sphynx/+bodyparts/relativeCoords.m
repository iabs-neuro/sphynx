function out = relativeCoords(BodyPartsX, BodyPartsY, Point)
% RELATIVECOORDS  Body-parts in tailbase-relative polar coordinates.
%
%   out = sphynx.bodyparts.relativeCoords(BodyPartsX, BodyPartsY, Point)
%
%   Builds polar (r, theta) for each body part relative to the
%   tailbase, with the body-axis (tailbase->center) rotated to a
%   canonical orientation. This is what legacy BehaviorAnalyzer.m
%   computes at lines 298-310.
%
%   Inputs:
%     BodyPartsX, BodyPartsY - PartsxN matrices (pixels)
%     Point                  - struct from identifyParts; must have
%                              non-empty Tailbase and Center (or
%                              fallback via computeCenter)
%
%   Output struct fields:
%     R           - PartsxN radial distance from tailbase (cm if input
%                   is in cm, pixels if input is in pixels)
%     Theta       - PartsxN angle in (-pi, pi], rotated so the body-axis
%                   points along theta=0
%     AngleRot    - 1xN body-axis angle relative to image-x-axis (raw,
%                   pre-rotation; useful for downstream rotation
%                   compensation)

    if isempty(Point.Tailbase)
        error('sphynx:relativeCoords:noTailbase', ...
            'Point.Tailbase is required');
    end

    [centerX, centerY] = sphynx.bodyparts.computeCenter(BodyPartsX, BodyPartsY, Point);

    relX = BodyPartsX - BodyPartsX(Point.Tailbase, :);
    relY = BodyPartsY - BodyPartsY(Point.Tailbase, :);
    [theta, r] = cart2pol(relX, relY);

    % AngleRot is the body-axis direction (tailbase->center) in the
    % image frame. The legacy convention uses center's polar theta.
    if ~isempty(Point.Center)
        angleRot = theta(Point.Center, :);
    else
        % If center came from fallback, recompute its theta
        cRelX = centerX - BodyPartsX(Point.Tailbase, :);
        cRelY = centerY - BodyPartsY(Point.Tailbase, :);
        [angleRot, ~] = cart2pol(cRelX, cRelY);
    end

    % Rotate so body-axis is along theta=0; result wrapped to (-pi, pi].
    thetaRotated = sphynx.angles.wrap(theta - angleRot);

    out.R = r;
    out.Theta = thetaRotated;
    out.AngleRot = angleRot;
end

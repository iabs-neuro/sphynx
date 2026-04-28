function arena = readArenaGeometry(frame, geometry, varargin)
% READARENAGEOMETRY  Interactively define arena boundary on `frame`.
%
%   arena = sphynx.preset.readArenaGeometry(frame, geometry, ...)
%
%   Inputs:
%     frame    - HxWxC display image
%     geometry - 'Polygon' | 'Circle' | 'Ellipse' | 'O-maze'
%
%   Optional name-value (testing override — skip ginput):
%     'Points' - Nx2 pre-clicked points [x y]
%
%   Output struct:
%     type        - 'Arena'
%     geometry    - same as input
%     border_x    - dense x outline
%     border_y    - dense y outline
%     border_separate_x, border_separate_y  - per-side cell arrays (Polygon only)
%     mask        - HxW logical filled-arena mask
%
%   Decomposition of legacy CreatePreset.m:262-348.

    p = inputParser;
    addRequired(p, 'frame');
    addRequired(p, 'geometry');
    addParameter(p, 'Points', []);
    addParameter(p, 'NumPointsPerSide', 1000);
    parse(p, frame, geometry, varargin{:});

    [H, W, ~] = size(frame);
    th = linspace(0, 2*pi, 20000)';

    if isempty(p.Results.Points)
        figure; imshow(frame); hold on;
        switch geometry
            case 'O-maze'
                uiwait(msgbox('Indicate at least 3 points of OUTER border', 'O-maze', 'modal'));
                [xOut, yOut] = ginput;
                uiwait(msgbox('Indicate at least 3 points of INNER border', 'O-maze', 'modal'));
                [xIn, yIn] = ginput;
                pts = [xOut(:) yOut(:); NaN NaN; xIn(:) yIn(:)];
            otherwise
                [px, py] = ginput;
                pts = [px(:), py(:)];
        end
    else
        pts = p.Results.Points;
    end

    arena.type = 'Arena';
    arena.geometry = geometry;
    arena.border_separate_x = {};
    arena.border_separate_y = {};

    switch geometry
        case 'Polygon'
            [arena.border_x, arena.border_y, sx, sy] = sphynx.util.polygonFit(pts(:,1), pts(:,2), ...
                'PointsPerSide', p.Results.NumPointsPerSide);
            arena.border_separate_x = sx;
            arena.border_separate_y = sy;
        case 'Circle'
            [xc, yc, R] = sphynx.util.circleFit(pts(:,1), pts(:,2));
            arena.border_x = xc + R * cos(th);
            arena.border_y = yc + R * sin(th);
        case 'Ellipse'
            e = sphynx.util.ellipseFit(pts(:,1), pts(:,2));
            arena.border_y = e.Y0_in + e.b*cos(th)*cos(e.phi) - e.a*sin(th)*sin(e.phi);
            arena.border_x = e.X0_in + e.b*cos(th)*sin(e.phi) + e.a*sin(th)*cos(e.phi);
        case 'O-maze'
            % Two concentric circles; we keep both as separate fields.
            split = find(any(isnan(pts), 2), 1);
            outer = pts(1:split-1, :);
            inner = pts(split+1:end, :);
            [xcO, ycO, RO] = sphynx.util.circleFit(outer(:,1), outer(:,2));
            [xcI, ycI, RI] = sphynx.util.circleFit(inner(:,1), inner(:,2));
            arena.border_x = [xcO + RO*cos(th), xcI + RI*cos(th)];
            arena.border_y = [ycO + RO*sin(th), ycI + RI*sin(th)];
        otherwise
            error('sphynx:readArenaGeometry:unknownGeometry', ...
                'geometry must be Polygon|Circle|Ellipse|O-maze; got "%s"', geometry);
    end

    if strcmp(geometry, 'O-maze')
        outerMask = imfill(sphynx.preset.maskFromBorder(H, W, arena.border_x(:,1), arena.border_y(:,1)));
        innerMask = imfill(sphynx.preset.maskFromBorder(H, W, arena.border_x(:,2), arena.border_y(:,2)));
        arena.mask = outerMask & ~innerMask;
    else
        arena.mask = imfill(sphynx.preset.maskFromBorder(H, W, arena.border_x, arena.border_y));
    end
end

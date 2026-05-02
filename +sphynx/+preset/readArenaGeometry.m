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
    addParameter(p, 'PickMode', 'shape', @(s) any(strcmpi(s, {'shape', 'points'})));
    parse(p, frame, geometry, varargin{:});

    [H, W, ~] = size(frame);
    th = linspace(0, 2*pi, 20000)';

    if isempty(p.Results.Points)
        fh = figure; ax = axes(fh); imshow(frame, 'Parent', ax); hold(ax, 'on');
        cleanup = onCleanup(@() closeIfValid(fh));
        if strcmpi(p.Results.PickMode, 'points')
            % Legacy point-by-point picker via ginput. User clicks vertices,
            % presses Enter to commit. No drag-and-drop refinement.
            switch geometry
                case 'O-maze'
                    uiwait(msgbox('Click outer border points, then press ENTER', 'O-maze', 'modal'));
                    [xOut, yOut] = ginput;
                    uiwait(msgbox('Click inner border points, then press ENTER', 'O-maze', 'modal'));
                    [xIn, yIn] = ginput;
                    pts = [xOut(:) yOut(:); NaN NaN; xIn(:) yIn(:)];
                otherwise
                    title(ax, 'Click points, then press ENTER. (point-by-point mode)', 'Interpreter', 'none');
                    [px, py] = ginput;
                    pts = [px(:), py(:)];
            end
            clear cleanup;
        else
        switch geometry
            case 'O-maze'
                uiwait(msgbox(['Draw the OUTER border polygon:' newline ...
                    'click vertices, double-click to finish.'], 'O-maze', 'modal'));
                hOut = drawpolygon(ax);
                wait(hOut);
                if ~isvalid(hOut); pts = zeros(0,2); clear cleanup; return; end
                outerPts = hOut.Position;
                uiwait(msgbox(['Draw the INNER border polygon:' newline ...
                    'click vertices, double-click to finish.'], 'O-maze', 'modal'));
                hIn = drawpolygon(ax);
                wait(hIn);
                if ~isvalid(hIn); innerPts = zeros(0,2); else; innerPts = hIn.Position; end
                pts = [outerPts; NaN NaN; innerPts];
            case 'Polygon'
                title(ax, 'Click polygon vertices, double-click to finish. Drag vertices to refine.', 'Interpreter', 'none');
                hP = drawpolygon(ax);
                wait(hP);
                if ~isvalid(hP); pts = zeros(0,2); clear cleanup; return; end
                pts = hP.Position;
            case 'Circle'
                title(ax, 'Click-and-drag to draw a circle, then refine.', 'Interpreter', 'none');
                hC = drawcircle(ax);
                wait(hC);
                if ~isvalid(hC); pts = zeros(0,2); clear cleanup; return; end
                % Sample N points around the drawn circle
                cx = hC.Center(1); cy = hC.Center(2); R = hC.Radius;
                ang = linspace(0, 2*pi, 60)';
                pts = [cx + R*cos(ang), cy + R*sin(ang)];
            case 'Ellipse'
                title(ax, 'Click-and-drag to draw an ellipse, then refine.', 'Interpreter', 'none');
                hE = drawellipse(ax);
                wait(hE);
                if ~isvalid(hE); pts = zeros(0,2); clear cleanup; return; end
                % Sample N points around the drawn ellipse
                cx = hE.Center(1); cy = hE.Center(2);
                a = hE.SemiAxes(1); b = hE.SemiAxes(2); rot = deg2rad(hE.RotationAngle);
                ang = linspace(0, 2*pi, 60)';
                xx = a*cos(ang); yy = b*sin(ang);
                pts = [cx + xx*cos(rot) - yy*sin(rot), ...
                       cy + xx*sin(rot) + yy*cos(rot)];
            otherwise
                hP = drawpolygon(ax);
                wait(hP);
                if ~isvalid(hP); pts = zeros(0,2); clear cleanup; return; end
                pts = hP.Position;
        end
        clear cleanup;  % closes figure now
        end   % end of shape-mode branch
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
        outerMask = imfill(sphynx.preset.maskFromBorder(H, W, arena.border_x(:,1), arena.border_y(:,1)), 'holes');
        innerMask = imfill(sphynx.preset.maskFromBorder(H, W, arena.border_x(:,2), arena.border_y(:,2)), 'holes');
        arena.mask = outerMask & ~innerMask;
    else
        arena.mask = imfill(sphynx.preset.maskFromBorder(H, W, arena.border_x, arena.border_y), 'holes');
    end
end

function closeIfValid(h)
    if ~isempty(h) && isvalid(h)
        close(h);
    end
end

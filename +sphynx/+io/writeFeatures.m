function outPath = writeFeatures(result, outDir, sessionName)
% WRITEFEATURES  Per-frame features table <outDir>/<sessionName>_Features.csv.
%
%   outPath = sphynx.io.writeFeatures(result, outDir, sessionName)
%
%   Same columns as the legacy BehaviorAnalyzer.m output, one row per
%   analysed frame (rows match the frame range of the analysis, so a
%   trimmed session has a trimmed table):
%     x, y                       body centre, smoothed, cm
%     x_locomotion, y_locomotion x, y during the act 'locomotion', NaN otherwise
%     speed                      body centre smoothed speed, cm/s
%     bodydirection              tailbase -> body centre angle, rad, (-pi, pi]
%     headdirection              head centre -> miniscope (or nose) angle,
%                                rad, smoothed over ~1 s
%     <act name> ...             0/1 per act, in result.Acts order
%
%   Frames of the act 'outside' (session edits) are not part of the
%   session: kinematic columns are NaN there, as in the saved plots.
%   A column that can not be computed (body part missing) is all NaN.

    if ~isfolder(outDir); mkdir(outDir); end
    n = result.n_frames;
    bps = result.BodyPartsTraces;
    P = result.Point;
    pxl = result.Options.pxl2sm;
    fps = result.Options.FrameRate;

    [X, Y] = smoothedXY(bps, n);
    c = P.Center;
    if isempty(c)
        x = nan(n, 1); y = x; speed = x;
    else
        x = X(c, :)' / pxl; y = Y(c, :)' / pxl;
        speed = bps(c).VelocitySmoothed(:);
    end

    xLoc = nan(n, 1); yLoc = xLoc;
    li = find(strcmp({result.Acts.ActName}, 'locomotion'), 1);
    if ~isempty(li)
        loc = logical(result.Acts(li).ActArrayRefine(:));
        xLoc(loc) = x(loc); yLoc(loc) = y(loc);
    end

    bodyDir = nan(n, 1);
    if ~isempty(P.Tailbase) && ~isempty(c)
        rc = sphynx.bodyparts.relativeCoords(X, Y, P);
        bodyDir = rc.AngleRot(:);
    end

    headDir = nan(n, 1);
    tip = P.MiniscopeUCLA;
    if isempty(tip); tip = P.Nose; end
    if ~isempty(tip) && ~isempty(P.HeadCenter)
        win = round(fps);
        if mod(win, 2) == 0; win = win + 1; end
        headDir = sphynx.angles.headDirection(X(tip, :), Y(tip, :), ...
            X(P.HeadCenter, :), Y(P.HeadCenter, :), win);
    end

    oi = find(strcmp({result.Acts.ActName}, 'outside'), 1);
    if ~isempty(oi)
        off = logical(result.Acts(oi).ActArrayRefine(:));
        x(off) = NaN; y(off) = NaN; xLoc(off) = NaN; yLoc(off) = NaN;
        speed(off) = NaN; bodyDir(off) = NaN; headDir(off) = NaN;
    end

    names = [{'x', 'y', 'x_locomotion', 'y_locomotion', 'speed', ...
        'bodydirection', 'headdirection'}, {result.Acts.ActName}];
    data = [x, y, xLoc, yLoc, speed, bodyDir, headDir, zeros(n, numel(result.Acts))];
    for k = 1:numel(result.Acts)
        data(:, 7 + k) = double(result.Acts(k).ActArrayRefine(:));
    end
    T = array2table(data, 'VariableNames', matlab.lang.makeValidName(names));
    outPath = fullfile(outDir, sprintf('%s_Features.csv', sessionName));
    writetable(T, outPath);
    sphynx.util.log('info', 'Saved features to %s', outPath);
end

function [X, Y] = smoothedXY(bps, n)
    X = nan(numel(bps), n); Y = X;
    for i = 1:numel(bps)
        if isfield(bps(i), 'TraceSmoothed') && numel(bps(i).TraceSmoothed.X) == n
            X(i, :) = bps(i).TraceSmoothed.X(:)';
            Y(i, :) = bps(i).TraceSmoothed.Y(:)';
        end
    end
end

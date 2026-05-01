function thr = autoThreshold(likelihood, method, param)
% AUTOTHRESHOLD  Suggest a likelihood threshold from the distribution.
%
%   thr = sphynx.preprocess.autoThreshold(likelihood, method, param)
%
%   Methods:
%     'otsu'     - Otsu's method on the likelihood histogram
%                  (multithresh, Image Processing Toolbox).
%                  param: ignored.
%     'knee'     - Maximum-curvature point on the sorted likelihood CDF.
%                  Heuristic: the likelihood at which the cumulative
%                  fraction inflects most sharply between the "low cluster"
%                  and the "high cluster". param: ignored.
%     'quantile' - Quantile of the likelihood distribution.
%                  param: quantile in (0, 1), default 0.05.
%     'preset'   - Fixed enum.
%                  param: 'aggressive' (0.99) | 'moderate' (0.95) | 'lax' (0.6).
%
%   Returns thr in [0, 1]. Safe fallback to 0.95 if the input degenerates
%   (all-equal, empty, or method-specific failure).

    if nargin < 3; param = []; end
    if nargin < 2 || isempty(method); method = 'otsu'; end
    likelihood = likelihood(:);
    likelihood = likelihood(~isnan(likelihood));

    if isempty(likelihood)
        thr = 0.95;
        return;
    end

    method = lower(method);
    switch method
        case 'otsu'
            thr = otsuThreshold(likelihood);
        case 'knee'
            thr = kneeThreshold(likelihood);
        case 'quantile'
            if isempty(param); param = 0.05; end
            thr = quantile(likelihood, param);
        case 'preset'
            if isempty(param); param = 'moderate'; end
            thr = presetThreshold(param);
        otherwise
            error('sphynx:autoThreshold:unknownMethod', ...
                'Unknown method: %s', method);
    end

    % Clamp into [0, 1] to be safe
    thr = max(0, min(1, thr));

    % Floor at 0.4 — anything below is dangerous for production tracking.
    % Manual override via the table is still allowed.
    floorThr = 0.4;
    if thr < floorThr
        sphynx.util.log('warn', 'autoThreshold[%s] suggested %.3f, clamped to floor %.2f', ...
            method, thr, floorThr);
        thr = floorThr;
    end
end

function thr = otsuThreshold(L)
    if numel(unique(L)) < 2
        thr = 0.95;
        return;
    end
    try
        thr = multithresh(L, 1);
    catch
        % multithresh requires Image Processing Toolbox; fall back to median
        thr = median(L);
    end
end

function thr = kneeThreshold(L)
    % Sort ascending; the CDF is the index/n vs L.
    % Find the point where the second derivative is maximum (= sharpest
    % bend). Robust for bimodal likelihood distributions where most
    % values cluster at 1.0 and a smaller cluster sits below.
    Ls = sort(L(:));
    n = numel(Ls);
    if n < 5
        thr = 0.95;
        return;
    end
    cdf = (1:n)' / n;
    % Smooth the CDF a bit so noise doesn't dominate the second diff
    win = max(5, round(n / 100));
    if mod(win, 2) == 0; win = win + 1; end
    if n >= win
        Lsm = smoothdata(Ls, 'movmean', win);
    else
        Lsm = Ls;
    end
    % Discrete second derivative of L wrt CDF index
    d1 = diff(Lsm);
    d2 = diff(d1);
    if isempty(d2)
        thr = median(Ls);
        return;
    end
    [~, idx] = max(abs(d2));
    thr = Lsm(idx + 1);  % +1 because diff shifts index
    % If the result is degenerate, fall back
    if ~isfinite(thr) || thr <= 0 || thr >= 1
        thr = median(Ls);
    end
end

function thr = presetThreshold(name)
    switch lower(string(name))
        case "aggressive"
            thr = 0.99;
        case "moderate"
            thr = 0.95;
        case "lax"
            thr = 0.60;
        otherwise
            error('sphynx:autoThreshold:unknownPreset', ...
                'Unknown preset: %s (use aggressive/moderate/lax)', name);
    end
end

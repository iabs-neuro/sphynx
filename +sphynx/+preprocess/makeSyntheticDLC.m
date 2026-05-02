function out = makeSyntheticDLC(varargin)
% MAKESYNTHETICDLC  Generate synthetic DLC tracking data for testing.
%
%   out = sphynx.preprocess.makeSyntheticDLC(...) returns a struct with
%   fields matching sphynx.io.readDLC: bodyPartsNames, X, Y, likelihood,
%   nFrames. Optionally writes a DLC-style csv when 'CsvPath' is given.
%
%   Optional name-value parameters:
%     'NFrames'        default 6000
%     'BodyParts'      default {'nose','leftear','rightear','headcenter',...
%                               'leftforelimb','rightforelimb','leftbody',...
%                               'rightbody','tailbase','bodycenter'}
%     'FrameWidth'     default 800
%     'FrameHeight'    default 600
%     'FrameRate'      default 30   (Hz, only used by callers)
%     'PixelsPerCm'    default 5    (only used by callers)
%     'MotionModel'    'random_walk' (default) | 'circular' | 'OU'
%     'OutlierMode'    'none' | 'spikes' (default) | 'long_gap' |
%                      'poor_likelihood' | 'mixed'
%     'Seed'           default 42
%     'CsvPath'        if non-empty, writes a DLC-style csv to this path
%
%   The csv format mimics DLC: header rows scorer / bodyparts / coords,
%   then one row per frame with frame index + (x, y, likelihood) per part.

    p = inputParser;
    p.addParameter('NFrames', 6000, @(v) isnumeric(v) && v > 10);
    p.addParameter('BodyParts', defaultParts(), @iscellstr);
    p.addParameter('FrameWidth', 800, @(v) isnumeric(v) && v > 0);
    p.addParameter('FrameHeight', 600, @(v) isnumeric(v) && v > 0);
    p.addParameter('FrameRate', 30, @(v) isnumeric(v) && v > 0);
    p.addParameter('PixelsPerCm', 5, @(v) isnumeric(v) && v > 0);
    p.addParameter('MotionModel', 'random_walk', @ischar);
    p.addParameter('OutlierMode', 'spikes', @ischar);
    p.addParameter('Seed', 42, @isnumeric);
    p.addParameter('CsvPath', '', @ischar);
    parse(p, varargin{:});

    rng(p.Results.Seed);
    n = p.Results.NFrames;
    parts = p.Results.BodyParts(:)';
    nP = numel(parts);
    W = p.Results.FrameWidth;
    H = p.Results.FrameHeight;

    % Generate a "center of mass" trajectory then offset each part around it
    [cmX, cmY] = generateMotion(n, W, H, p.Results.MotionModel);
    [X, Y] = scatterParts(cmX, cmY, parts, W, H);

    L = ones(nP, n) * 0.97 + randn(nP, n) * 0.02;
    L = max(0, min(1, L));

    % Inject outliers
    [X, Y, L] = injectOutliers(X, Y, L, p.Results.OutlierMode, W, H);

    out.bodyPartsNames = parts;
    out.X = X;
    out.Y = Y;
    out.likelihood = L;
    out.nFrames = n;
    out.frameWidth = W;
    out.frameHeight = H;
    out.frameRate = p.Results.FrameRate;
    out.pixelsPerCm = p.Results.PixelsPerCm;
    out.motionModel = p.Results.MotionModel;
    out.outlierMode = p.Results.OutlierMode;

    if ~isempty(p.Results.CsvPath)
        writeDLCcsv(p.Results.CsvPath, parts, X, Y, L);
    end
end

function parts = defaultParts()
    parts = {'nose', 'leftear', 'rightear', 'headcenter', ...
             'leftforelimb', 'rightforelimb', ...
             'leftbody', 'rightbody', ...
             'tailbase', 'bodycenter'};
end

function [X, Y] = generateMotion(n, W, H, model)
    % Returns 1xn vectors for the center-of-mass trajectory.
    switch lower(model)
        case 'random_walk'
            sigma = 2.0;
            X = zeros(1, n); Y = zeros(1, n);
            X(1) = W/2; Y(1) = H/2;
            for k = 2:n
                X(k) = max(20, min(W-20, X(k-1) + randn * sigma));
                Y(k) = max(20, min(H-20, Y(k-1) + randn * sigma));
            end
        case 'circular'
            cx = W/2; cy = H/2; r = 0.35 * min(W, H);
            t = (0:n-1) / n * 8 * pi;
            X = cx + r * cos(t);
            Y = cy + r * sin(t);
        case 'ou'
            tau = 50; sigma = 4;
            cx = W/2; cy = H/2;
            X = zeros(1, n); Y = zeros(1, n);
            X(1) = cx; Y(1) = cy;
            for k = 2:n
                X(k) = X(k-1) + (cx - X(k-1))/tau + randn * sigma;
                Y(k) = Y(k-1) + (cy - Y(k-1))/tau + randn * sigma;
                X(k) = max(20, min(W-20, X(k)));
                Y(k) = max(20, min(H-20, Y(k)));
            end
        otherwise
            error('sphynx:makeSyntheticDLC:unknownMotion', ...
                'Unknown motion model: %s', model);
    end
end

function [X, Y] = scatterParts(cmX, cmY, parts, W, H)
    n = numel(cmX); nP = numel(parts);
    X = zeros(nP, n); Y = zeros(nP, n);
    % Each part has a fixed offset relative to body center
    offsets = struct( ...
        'nose',           [ 0 -25], ...
        'leftear',        [-15 -15], ...
        'rightear',       [ 15 -15], ...
        'headcenter',     [ 0 -10], ...
        'leftforelimb',   [-20  10], ...
        'rightforelimb',  [ 20  10], ...
        'leftbody',       [-15  20], ...
        'rightbody',      [ 15  20], ...
        'lefthindlimb',   [-20  35], ...
        'righthindlimb',  [ 20  35], ...
        'tailbase',       [ 0  40], ...
        'bodycenter',     [ 0  15]);
    for i = 1:nP
        if isfield(offsets, parts{i})
            off = offsets.(parts{i});
        else
            off = [0 0];
        end
        X(i, :) = max(1, min(W, cmX + off(1) + randn(1, n) * 0.5));
        Y(i, :) = max(1, min(H, cmY + off(2) + randn(1, n) * 0.5));
    end
end

function [X, Y, L] = injectOutliers(X, Y, L, mode, W, H)
    [nP, n] = size(X);
    modes = lower(string(mode));
    apply = @(m) any(strcmp(modes, ["mixed", m]));
    if apply("spikes")
        % 0.5% of samples become a 1-frame spike to a random pixel
        nSpikes = round(0.005 * nP * n);
        for k = 1:nSpikes
            i = randi(nP); f = randi(n);
            X(i, f) = randi(W); Y(i, f) = randi(H);
            L(i, f) = max(0.01, L(i, f) - 0.6);
        end
    end
    if apply("long_gap")
        % 1-3 long gaps per part with low likelihood
        for i = 1:nP
            nGaps = randi([1 3]);
            for g = 1:nGaps
                len = randi([15 120]);
                start = randi(max(1, n - len));
                L(i, start:start+len-1) = 0.05 + rand * 0.1;
            end
        end
    end
    if apply("poor_likelihood")
        % Globally low likelihood (around 0.55)
        L = 0.55 + randn(size(L)) * 0.1;
        L = max(0, min(1, L));
    end
    % If mode == 'none', leave as-is.
end

function writeDLCcsv(path, parts, X, Y, L)
    [nP, n] = size(X);
    fid = fopen(path, 'w');
    if fid < 0
        error('sphynx:makeSyntheticDLC:csvOpen', ...
            'Cannot open csv for writing: %s', path);
    end
    cleaner = onCleanup(@() fclose(fid));
    % Header line 1: scorer
    scorerName = 'DLC_synthetic';
    headerScorer = ['scorer', repmat({scorerName}, 1, 3*nP)];
    fprintf(fid, '%s\n', strjoin(headerScorer, ','));
    % Header line 2: bodyparts
    headerParts = {'bodyparts'};
    for i = 1:nP
        headerParts = [headerParts, parts{i}, parts{i}, parts{i}]; %#ok<AGROW>
    end
    fprintf(fid, '%s\n', strjoin(headerParts, ','));
    % Header line 3: coords
    headerCoords = {'coords'};
    for i = 1:nP
        headerCoords = [headerCoords, 'x', 'y', 'likelihood']; %#ok<AGROW>
    end
    fprintf(fid, '%s\n', strjoin(headerCoords, ','));
    % Data
    for f = 1:n
        row = sprintf('%d', f - 1);
        for i = 1:nP
            row = sprintf('%s,%.6f,%.6f,%.6f', row, X(i, f), Y(i, f), L(i, f));
        end
        fprintf(fid, '%s\n', row);
    end
end

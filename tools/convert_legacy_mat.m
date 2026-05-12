function convert_legacy_mat(srcDir, dstDir, dryRun)
% CONVERT_LEGACY_MAT  Repackage legacy BehaviorAnalyzer _WorkSpace.mat
% files into the new sphynx format expected by Make-Output-Table.
%
%   convert_legacy_mat(srcDir, dstDir, dryRun)
%       srcDir  - folder containing legacy *_WorkSpace.mat (e.g.
%                 H:\Dataset\BehaviorData\CC\5_BehaviorMAT)
%       dstDir  - output folder (created if missing)
%       dryRun  - true (default): list what would happen, no writes.
%                 false: write converted files.
%
% Each output file keeps the same filename as the source and is placed
% flat in dstDir. MakeOutputTable will pick up SessionName by stripping
% _WorkSpace from the basename.
%
% Conversion details:
%   * Acts: copy as-is. For each entry, add FirstStartSec, FirstEndSec,
%           LastStartSec, LastEndSec (computed from ActArrayRefine +
%           FrameRate), and alias ActVelocity -> ActMeanVelocity. If
%           VelocitySmoothed of bodycenter (or tailbase) is available,
%           also compute ActMaxVelocity / ActMinVelocity for frames in
%           ActArrayRefine.
%   * BodyPartsTraces: copy as-is, but for any entry where
%           AverageDistance / AverageSpeed are empty, compute them from
%           TraceSmoothed (sum of consecutive (dx,dy) magnitudes
%           divided by pxl2sm; speed = distance / duration).
%   * Zones / ArenaAndObjects / Options / Point / n_frames / config /
%           bodyPartsNames: passed through if present (or synthesized
%           with sensible defaults).
%   * Acts may be missing entirely (RFC). Then an empty struct array
%           is written; MakeOutputTable still gets per-mouse Distance
%           and Velocity from BodyPartsTraces.

    if nargin < 3; dryRun = true; end
    if ~isfolder(srcDir)
        error('convert_legacy_mat:badSrc', 'srcDir not found: %s', srcDir);
    end
    if ~isfolder(dstDir)
        if dryRun
            fprintf('[dry] would mkdir %s\n', dstDir);
        else
            mkdir(dstDir);
        end
    end

    files = dir(fullfile(srcDir, '*_WorkSpace.mat'));
    if isempty(files)
        warning('No *_WorkSpace.mat in %s', srcDir);
        return;
    end

    fprintf('=== %s -> %s   (%d files, dryRun=%d) ===\n', srcDir, dstDir, numel(files), dryRun);

    nOK = 0; nFail = 0;
    for k = 1:numel(files)
        srcP = fullfile(files(k).folder, files(k).name);
        dstP = fullfile(dstDir, files(k).name);
        fprintf('[%3d/%3d] %s\n', k, numel(files), files(k).name);
        try
            converted = convertOne(srcP);
            if ~dryRun
                save(dstP, '-struct', 'converted', '-v7.3');
            end
            nOK = nOK + 1;
        catch ME
            fprintf('         ERROR: %s\n', ME.message);
            nFail = nFail + 1;
        end
    end
    fprintf('Done. ok=%d fail=%d (dryRun=%d)\n', nOK, nFail, dryRun);
end


function out = convertOne(srcP)
% Read one legacy mat and emit a struct ready for save.

    % Load only the variables we care about (faster + skips VideoReader warnings).
    wantedVars = {'Acts', 'BodyPartsTraces', 'Zones', 'ArenaAndObjects', ...
        'Options', 'Point', 'BodyPartsNames', 'BodyPartsCenterNames'};
    info = whos('-file', srcP);
    have = {info.name};
    toLoad = wantedVars(ismember(wantedVars, have));
    S = load(srcP, toLoad{:});

    % --- Frame-rate + pxl2sm for compute fallback ---
    fps = 30; pxl2sm = 1;
    if isfield(S, 'Options')
        if isfield(S.Options, 'FrameRate') && ~isempty(S.Options.FrameRate)
            fps = double(S.Options.FrameRate);
        end
        if isfield(S.Options, 'pxl2sm') && ~isempty(S.Options.pxl2sm) && S.Options.pxl2sm ~= 0
            pxl2sm = double(S.Options.pxl2sm);
        end
    end

    % --- BodyPartsTraces: fill missing AverageDistance/Speed ---
    BPT = struct([]);
    if isfield(S, 'BodyPartsTraces') && ~isempty(S.BodyPartsTraces)
        BPT = S.BodyPartsTraces;
        for i = 1:numel(BPT)
            [ad, asp] = computeBPTAverages(BPT(i), pxl2sm, fps);
            if ~isfield(BPT(i), 'AverageDistance') || isempty(BPT(i).AverageDistance)
                BPT(i).AverageDistance = ad;
            end
            if ~isfield(BPT(i), 'AverageSpeed') || isempty(BPT(i).AverageSpeed)
                BPT(i).AverageSpeed = asp;
            end
            if isfield(BPT(i), 'PercentLikeliHoodSubThreshold') && ...
                    (~isfield(BPT(i), 'PercentLowLikelihood') || isempty(BPT(i).PercentLowLikelihood))
                BPT(i).PercentLowLikelihood = BPT(i).PercentLikeliHoodSubThreshold;
            end
        end
    end

    % Pick a velocity trace for per-act min/max velocity (bodycenter -> tailbase).
    velTrace = pickVelocityTrace(BPT);

    % --- Acts: copy + add first/last + min/max velocity (mutate fields
    % individually so the struct array stays schema-consistent).
    Acts = struct([]);
    if isfield(S, 'Acts') && ~isempty(S.Acts)
        Acts = S.Acts;
        for i = 1:numel(Acts)
            [fs, fe, ls, le] = actFirstLastSec(Acts(i), fps);
            Acts(i).FirstStartSec = fs;
            Acts(i).FirstEndSec   = fe;
            Acts(i).LastStartSec  = ls;
            Acts(i).LastEndSec    = le;
            if ~isfield(Acts(i), 'ActMeanVelocity') || isempty(Acts(i).ActMeanVelocity)
                if isfield(Acts(i), 'ActVelocity') && ~isempty(Acts(i).ActVelocity)
                    Acts(i).ActMeanVelocity = Acts(i).ActVelocity;
                else
                    Acts(i).ActMeanVelocity = NaN;
                end
            end
            [vmax, vmin] = actMinMaxVel(Acts(i), velTrace);
            Acts(i).ActMaxVelocity = vmax;
            Acts(i).ActMinVelocity = vmin;
        end
    end

    % --- bodyPartsNames (new-format helper) ---
    if isfield(S, 'BodyPartsNames')
        bodyPartsNames = S.BodyPartsNames;
    elseif ~isempty(BPT) && isfield(BPT, 'BodyPartName')
        bodyPartsNames = {BPT.BodyPartName};
    else
        bodyPartsNames = {};
    end

    % --- n_frames ---
    if isfield(S, 'Options') && isfield(S.Options, 'NumFrames')
        n_frames = double(S.Options.NumFrames);
    elseif ~isempty(velTrace)
        n_frames = numel(velTrace);
    else
        n_frames = NaN;
    end

    % --- config (minimal stub) ---
    config = struct('source', 'legacy_convert');

    % --- Pass-throughs ---
    Zones = struct([]);
    if isfield(S, 'Zones'); Zones = S.Zones; end
    ArenaAndObjects = struct([]);
    if isfield(S, 'ArenaAndObjects'); ArenaAndObjects = S.ArenaAndObjects; end
    Options = struct();
    if isfield(S, 'Options'); Options = S.Options; end
    Point = struct();
    if isfield(S, 'Point'); Point = S.Point; end

    % Assemble output struct (top-level field set matches the new format).
    out = struct();
    out.Acts            = Acts;
    out.BodyPartsTraces = BPT;
    out.Zones           = Zones;
    out.ArenaAndObjects = ArenaAndObjects;
    out.Options         = Options;
    out.Point           = Point;
    out.bodyPartsNames  = bodyPartsNames;
    out.config          = config;
    out.n_frames        = n_frames;
end


function [distCm, speedCmS] = computeBPTAverages(bp, pxl2sm, fps)
    distCm = NaN; speedCmS = NaN;
    if ~isfield(bp, 'TraceSmoothed') || ~isstruct(bp.TraceSmoothed); return; end
    ts = bp.TraceSmoothed;
    if ~isfield(ts, 'X') || ~isfield(ts, 'Y'); return; end
    x = double(ts.X(:)); y = double(ts.Y(:));
    if numel(x) < 2; return; end
    dx = diff(x); dy = diff(y);
    distPx = sum(sqrt(dx.^2 + dy.^2), 'omitnan');
    distCm = distPx / pxl2sm;
    durS = (numel(x) - 1) / fps;
    if durS > 0; speedCmS = distCm / durS; end
end


function vel = pickVelocityTrace(BPT)
    vel = [];
    if isempty(BPT); return; end
    names = lower({BPT.BodyPartName});
    idx = find(strcmp(names, 'bodycenter'), 1);
    if isempty(idx); idx = find(strcmp(names, 'tailbase'), 1); end
    if isempty(idx); return; end
    bp = BPT(idx);
    if isfield(bp, 'VelocitySmoothed') && ~isempty(bp.VelocitySmoothed)
        vel = double(bp.VelocitySmoothed(:));
    elseif isfield(bp, 'Velocity') && ~isempty(bp.Velocity)
        vel = double(bp.Velocity(:));
    end
end


function [fs, fe, ls, le] = actFirstLastSec(a, fps)
    fs = NaN; fe = NaN; ls = NaN; le = NaN;
    if ~isfield(a, 'ActArrayRefine') || isempty(a.ActArrayRefine); return; end
    bool = logical(a.ActArrayRefine(:) > 0);
    d = diff([false; bool; false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;
    if isempty(starts); return; end
    fs = (starts(1) - 1) / fps;
    fe = ends(1)         / fps;
    ls = (starts(end) - 1) / fps;
    le = ends(end)         / fps;
end


function [vmax, vmin] = actMinMaxVel(a, velTrace)
    vmax = NaN; vmin = NaN;
    if isempty(velTrace) || ~isfield(a, 'ActArrayRefine') || isempty(a.ActArrayRefine); return; end
    bool = logical(a.ActArrayRefine(:) > 0);
    if isempty(bool); return; end
    n = min(numel(bool), numel(velTrace));
    vv = velTrace(1:n);
    vv = vv(bool(1:n));
    vv = vv(~isnan(vv) & isfinite(vv));
    if isempty(vv); return; end
    vmax = max(vv);
    vmin = min(vv);
end

function buildSnapshots(varargin)
% BUILDSNAPSHOTS  One-shot: read existing legacy WorkSpace.mat files
%   from Demo/Behavior/ and write golden snapshots for regression tests.
%
%   buildSnapshots()                       builds snapshot for NOF_H01_1D
%   buildSnapshots('sessions', {...})      builds for given list
%
%   Output: tests/golden/snapshots/<session>_Acts.mat
%
%   The snapshot stores ONLY numeric Acts fields and a few body-parts
%   aggregates - no per-frame time series. ~1-3 KB per session.
%
%   Run from MATLAB:
%     >> run(fullfile(sphynx.util.repoRoot(),'tests','golden','buildSnapshots.m'))

    p = inputParser;
    addParameter(p, 'sessions', {'NOF_H01_1D'}, @iscell);
    parse(p, varargin{:});

    repo = sphynx.util.repoRoot();
    snapDir = fullfile(repo, 'tests', 'golden', 'snapshots');
    if ~isfolder(snapDir)
        mkdir(snapDir);
    end

    for i = 1:numel(p.Results.sessions)
        session = p.Results.sessions{i};
        wsPath = locateLegacyWorkspace(repo, session);
        sphynx.util.log('info', 'Reading %s', wsPath);

        L = load(wsPath, 'Acts', 'BodyPartsTraces', 'Point', 'Options', 'n_frames');

        snap = struct();
        snap.Acts = stripActsForSnapshot(L.Acts);
        snap.BodyPartsAggregates = bodyPartsAggregates(L.BodyPartsTraces, L.Point);
        snap.meta.legacySource = strrep(wsPath, repo, '<repo>');
        snap.meta.snapshotDate = char(datetime('now'));
        snap.meta.n_frames = L.n_frames;
        snap.meta.FrameRate = L.Options.FrameRate;
        snap.meta.legacyGitSha = currentGitSha(repo);

        outPath = fullfile(snapDir, sprintf('%s_Acts.mat', session));
        save(outPath, '-struct', 'snap');
        sphynx.util.log('info', 'Wrote %s (%.1f KB)', outPath, dirSizeKB(outPath));
    end
end

function wsPath = locateLegacyWorkspace(repo, session)
    baseDir = fullfile(repo, 'Demo', 'Behavior', session);
    if ~isfolder(baseDir)
        error('buildSnapshots:noBehaviorDir', ...
            'No Demo/Behavior dir for session "%s" at %s', session, baseDir);
    end
    d = dir(baseDir);
    d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));
    if isempty(d)
        error('buildSnapshots:noLegacyRun', ...
            'No legacy run subfolder under %s', baseDir);
    end
    [~, idx] = max([d.datenum]); % most recent
    wsPath = fullfile(d(idx).folder, d(idx).name, sprintf('%s_WorkSpace.mat', session));
    if ~isfile(wsPath)
        error('buildSnapshots:noWorkspaceMat', ...
            'No %s_WorkSpace.mat at %s', session, wsPath);
    end
end

function out = stripActsForSnapshot(Acts)
    keepFields = {'ActName','ActPercent','ActNumber','ActMeanTime', ...
                  'ActMedianTime','Distance','ActDuration','ActVelocity'};
    out = struct();
    for k = 1:numel(keepFields)
        out.(keepFields{k}) = cell(1, numel(Acts));
    end
    for i = 1:numel(Acts)
        for k = 1:numel(keepFields)
            f = keepFields{k};
            if isfield(Acts, f) && ~isempty(Acts(i).(f))
                out.(f){i} = Acts(i).(f);
            else
                out.(f){i} = [];
            end
        end
    end
end

function agg = bodyPartsAggregates(BodyPartsTraces, Point)
    agg = struct();
    parts = struct('Tailbase', Point.Tailbase, 'Center', Point.Center);
    fns = fieldnames(parts);
    for i = 1:numel(fns)
        idx = parts.(fns{i});
        if ~isempty(idx) && idx >= 1 && idx <= numel(BodyPartsTraces)
            t = BodyPartsTraces(idx);
            agg.(fns{i}).AverageDistance = getOrEmpty(t, 'AverageDistance');
            agg.(fns{i}).AverageSpeed    = getOrEmpty(t, 'AverageSpeed');
        else
            agg.(fns{i}).AverageDistance = NaN;
            agg.(fns{i}).AverageSpeed    = NaN;
        end
    end
end

function v = getOrEmpty(s, f)
    if isfield(s, f) && ~isempty(s.(f))
        v = s.(f);
    else
        v = NaN;
    end
end

function sha = currentGitSha(repo)
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', repo));
    if status == 0
        sha = strtrim(out);
    else
        sha = '<unknown>';
    end
end

function kb = dirSizeKB(path)
    d = dir(path);
    if isempty(d)
        kb = NaN;
    else
        kb = d(1).bytes / 1024;
    end
end

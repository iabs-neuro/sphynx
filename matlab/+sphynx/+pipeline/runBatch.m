function out = runBatch(specs, varargin)
% RUNBATCH  Run analyzeSession over a list of sessions and aggregate results.
%
%   out = sphynx.pipeline.runBatch(specs, ...)
%
%   `specs` is a struct array; one element per session. Required fields:
%     sessionName  - unique identifier (e.g., 'J01_1D')
%     dlcPath      - path to DLC csv
%     presetPath   - path to preset .mat
%   Optional fields (carried through to the output table):
%     mouse, group, line, trial, video (any string)
%
%   Optional name-value (apply to every analyzeSession call):
%     'Config' - base config struct (default: defaultConfig with
%                viz.headless=true, io.saveWorkspace=false)
%     'OutDir' - if non-empty, sets config.paths.outDir for each session
%                so analyzeSession saves a workspace per session
%     'PreLoaded' - struct array of pre-computed results, parallel to
%                   specs. If supplied, analyzeSession is NOT called and
%                   these results are used instead. Useful for tests
%                   and when sessions have already been processed.
%
%   Output struct:
%     results - 1xN cell array of analyzeSession result structs (or
%               whatever was passed via PreLoaded)
%     tidy    - long-format table (one row per session/act/metric)
%               columns: sessionName, mouse, group, line, trial,
%                        actName, metric, value
%     wide    - wide-format table (one row per mouse, one column per
%               (act, metric, trial) combination), legacy-compatible
%
%   Replaces the SuperTable construction in Commander_behavior.m
%   (lines 92-176) with a tidy-first approach that uses MATLAB's
%   built-in unstack() for the wide pivot.

    p = inputParser;
    addRequired(p, 'specs');
    addParameter(p, 'Config', sphynx.pipeline.defaultConfig());
    addParameter(p, 'OutDir', '');
    addParameter(p, 'PreLoaded', []);
    parse(p, specs, varargin{:});

    nSessions = numel(specs);
    results = cell(1, nSessions);

    if ~isempty(p.Results.PreLoaded)
        if numel(p.Results.PreLoaded) ~= nSessions
            error('sphynx:runBatch:preloadedMismatch', ...
                'PreLoaded length %d != specs length %d', ...
                numel(p.Results.PreLoaded), nSessions);
        end
        for k = 1:nSessions
            results{k} = p.Results.PreLoaded(k);
        end
    else
        for k = 1:nSessions
            cfg = p.Results.Config;
            cfg.paths.dlc = specs(k).dlcPath;
            cfg.paths.preset = specs(k).presetPath;
            if ~isempty(p.Results.OutDir)
                cfg.paths.outDir = p.Results.OutDir;
                cfg.io.saveWorkspace = true;
                cfg.io.sessionName = specs(k).sessionName;
            else
                cfg.io.saveWorkspace = false;
            end
            sphynx.util.log('info', 'Batch %d/%d: %s', k, nSessions, specs(k).sessionName);
            results{k} = sphynx.pipeline.analyzeSession(cfg);
        end
    end

    out.results = results;
    out.tidy = buildTidyTable(specs, results);
    out.wide = tidyToWide(out.tidy);
end

function T = buildTidyTable(specs, results)
    rows = struct('sessionName', {}, 'mouse', {}, 'group', {}, 'line', {}, ...
                   'trial', {}, 'actName', {}, 'metric', {}, 'value', {});
    metricFields = {'ActPercent', 'ActNumber', 'ActMeanTime', 'ActMedianTime', ...
                     'ActDuration', 'ActVelocity', 'Distance', 'ActMeanDistance'};

    for k = 1:numel(specs)
        spec = specs(k);
        result = results{k};
        for actI = 1:numel(result.Acts)
            actName = char(result.Acts(actI).ActName);
            for mi = 1:numel(metricFields)
                m = metricFields{mi};
                if ~isfield(result.Acts, m); continue; end
                value = result.Acts(actI).(m);
                if isempty(value); value = NaN; end
                rows(end+1) = makeRow(spec, actName, m, value); %#ok<AGROW>
            end
        end
    end

    T = struct2table(rows, 'AsArray', true);
end

function r = makeRow(spec, actName, metric, value)
    r.sessionName = string(spec.sessionName);
    r.mouse = string(getOpt(spec, 'mouse', ''));
    r.group = string(getOpt(spec, 'group', ''));
    r.line  = string(getOpt(spec, 'line',  ''));
    r.trial = string(getOpt(spec, 'trial', ''));
    r.actName = string(actName);
    r.metric = string(metric);
    r.value = value;
end

function v = getOpt(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end

function W = tidyToWide(T)
    if isempty(T)
        W = table();
        return;
    end

    % Construct a column key per row: actName_metric_trial
    keys = strcat(T.actName, '_', T.metric);
    if any(T.trial ~= "")
        keys = strcat(keys, '_', T.trial);
    end
    T.colKey = keys;

    % Aggregate one row per mouse, columns are unique colKeys
    mice = unique(T.mouse);
    cols = unique(T.colKey);

    data = nan(numel(mice), numel(cols));
    for r = 1:height(T)
        rIdx = find(mice == T.mouse(r), 1);
        cIdx = find(cols == T.colKey(r), 1);
        data(rIdx, cIdx) = T.value(r);
    end

    W = array2table(data, 'VariableNames', matlab.lang.makeValidName(cols));
    W.mouse = mice;
    W = movevars(W, 'mouse', 'Before', 1);
end

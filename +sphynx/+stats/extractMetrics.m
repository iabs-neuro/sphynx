function [metrics, factorCols, idCol] = extractMetrics(T)
% EXTRACTMETRICS  Parse a wide super-table into per-metric long blocks.
%
%   [metrics, factorCols, idCol] = sphynx.stats.extractMetrics(T)
%
%   Input:
%     T - table from readtable on the wide CSV produced by Make Output
%         Table. Columns look like:
%           mouse, [exp], [group], [line], [...other ID_* cols],
%           <act>_<metric>_<session>,
%           distance_<unit>_<session>,
%           velocity_cm_per_s_<session>
%
%   Output:
%     metrics    - struct array, one per metric label, with fields
%                   .label    char e.g. 'rear_count'
%                   .kind     'per_act' | 'general_distance' | 'general_velocity'
%                   .columns  cell of column names in T contributing to this metric
%                   .sessions cell of session suffix strings
%     factorCols - cellstr of columns that look like grouping factors
%                  (non-numeric, NOT mouse, NOT session_name).
%     idCol      - 'mouse' if present, else 'subject' fallback, else ''.

    if ~istable(T) || isempty(T.Properties.VariableNames)
        metrics = struct('label', {}, 'kind', {}, 'columns', {}, 'sessions', {});
        factorCols = {}; idCol = ''; return;
    end

    names = T.Properties.VariableNames;
    isNum = varfun(@isnumeric, T, 'OutputFormat', 'uniform');

    % --- ID column ---
    idCol = '';
    if any(strcmpi(names, 'mouse'));   idCol = names{find(strcmpi(names,'mouse'),1)}; end
    if isempty(idCol) && any(strcmpi(names, 'subject'))
        idCol = names{find(strcmpi(names,'subject'),1)};
    end

    % --- Factor columns: non-numeric, not id, not session_name ---
    factorCols = {};
    skip = lower({idCol, 'session_name', 'session'});
    for k = 1:numel(names)
        if isNum(k); continue; end
        if any(strcmp(skip, lower(names{k}))); continue; end
        factorCols{end+1} = names{k}; %#ok<AGROW>
    end

    % --- Numeric metric columns ---
    metricMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    % Order of suffix probes matters: longer first to avoid partial matches.
    metricSuffixes = { ...
        'distance_cm', 'distance_m', ...
        'mean_v_cm_s', 'max_v_cm_s', 'min_v_cm_s', ...
        'first_start_s', 'first_end_s', 'last_start_s', 'last_end_s', ...
        'mean_dist_cm', 'mean_dur_s', 'median_dur_s', ...
        'duration_s', 'percent', 'count'};

    for k = 1:numel(names)
        if ~isNum(k); continue; end
        nm = names{k};
        % Try general distance first: 'distance_(cm|m)_<session>'
        tok = regexp(nm, '^distance_(cm|m)_(.+)$', 'tokens', 'once');
        if ~isempty(tok)
            label = sprintf('distance_%s', tok{1});
            kind = 'general_distance';
            session = tok{2};
            registerMetric(metricMap, label, kind, nm, session);
            continue;
        end
        % General velocity: 'velocity_cm_per_s_<session>'
        tok = regexp(nm, '^velocity_(cm_per_s)_(.+)$', 'tokens', 'once');
        if ~isempty(tok)
            label = 'velocity_cm_per_s';
            kind = 'general_velocity';
            session = tok{2};
            registerMetric(metricMap, label, kind, nm, session);
            continue;
        end
        % Per-act: '<act>_<metricSuffix>_<session>'
        matched = false;
        for s = 1:numel(metricSuffixes)
            suf = metricSuffixes{s};
            pat = sprintf('^(.+)_%s_(.+)$', suf);
            tok = regexp(nm, pat, 'tokens', 'once');
            if ~isempty(tok)
                act = tok{1};
                session = tok{2};
                label = sprintf('%s_%s', act, suf);
                registerMetric(metricMap, label, 'per_act', nm, session);
                matched = true; break;
            end
        end
        if matched; continue; end
        % Unrecognised numeric column — treat as its own single-session metric.
        registerMetric(metricMap, nm, 'unknown', nm, '');
    end

    labels = keys(metricMap);
    metrics = struct('label', {}, 'kind', {}, 'columns', {}, 'sessions', {});
    for k = 1:numel(labels)
        rec = metricMap(labels{k});
        metrics(end+1) = rec; %#ok<AGROW>
    end
    % Stable sort: per_act first, then general, then unknown; alpha within.
    if ~isempty(metrics)
        kindOrder = containers.Map({'per_act','general_distance','general_velocity','unknown'}, ...
                                   {1, 2, 3, 4});
        keys2 = arrayfun(@(m) sprintf('%d_%s', kindOrder(m.kind), m.label), metrics, 'uni', 0);
        [~, ix] = sort(keys2);
        metrics = metrics(ix);
    end
end

function registerMetric(map, label, kind, col, session)
    if map.isKey(label)
        rec = map(label);
    else
        rec = struct('label', label, 'kind', kind, 'columns', {{}}, 'sessions', {{}});
    end
    rec.columns{end+1} = col;
    if ~isempty(session)
        if ~any(strcmp(rec.sessions, session))
            rec.sessions{end+1} = session;
        end
    end
    map(label) = rec;
end

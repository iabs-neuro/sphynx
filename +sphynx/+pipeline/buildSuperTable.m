function ST = buildSuperTable(batchResults, varargin)
% BUILDSUPERTABLE  Reshape a batch of analyzeSession results into a wide
% Prism-friendly table.
%
%   ST = sphynx.pipeline.buildSuperTable(batchResults, ...)
%
%   batchResults is a struct array with fields:
%     SessionName  - char, e.g. 'WNOF_J01_1D'
%     Acts         - struct array (ActName, ActPercent, ActDuration,
%                    ActNumber, ActMeanTime, ...)
%     Distance     - scalar, total distance (cm)
%     Velocity     - scalar, mean speed (cm/s)
%
%   Optional name-value:
%     'Metadata'    - table with columns mouse / group / line / session.
%                     If omitted, mouse / session are parsed from
%                     SessionName via splitNamePattern.
%     'NamePattern' - regexp with named tokens for parsing
%                     SessionName when Metadata is empty.
%                     Default: '^(?<exp>[^_]+)_(?<mouse>[^_]+)_(?<session>\d+D)$'
%     'Metrics'     - cell of metric field names to include per act
%                     {default: 'ActPercent','ActDuration','ActNumber','ActMeanTime'}
%     'NaNPolicy'   - 'keep' (default) | 'zero' — what to do with
%                     missing cells.
%     'SortBy'      - cell of metadata column names to sort rows by
%                     {default: {'group', 'line', 'mouse'}}
%
%   Output ST struct:
%     .Wide  - table with rows = mice × all sessions, cols = mouse / group /
%              line / <act>_<metric>_<session>.
%     .Tidy  - long-format table (mouse, session, act, metric, value).
%     .Meta  - the resolved metadata table.
%     .Acts  - cell of unique act names found across the batch.

    p = inputParser;
    p.addRequired('batchResults');
    p.addParameter('Metadata', table.empty);
    p.addParameter('NamePattern', '^(?<exp>[^_]+)_(?<mouse>[^_]+)_(?<session>.+)$', @ischar);
    p.addParameter('Metrics', {'ActPercent', 'ActDuration', 'ActNumber', 'ActMeanTime'}, @iscell);
    p.addParameter('MetricsByAct', struct(), @isstruct);
    p.addParameter('NaNPolicy', 'keep', @(s) any(strcmp(s, {'keep', 'zero'})));
    p.addParameter('SortBy', {'line', 'group', 'mouse'}, @iscell);
    p.addParameter('GeneralDistanceUnit', 'cm', @(s) any(strcmpi(s, {'cm','m'})));
    p.addParameter('PerActDistanceUnit',  'cm', @(s) any(strcmpi(s, {'cm','m'})));
    parse(p, batchResults, varargin{:});

    metadata = p.Results.Metadata;
    if isempty(metadata)
        metadata = parseMetadataFromNames({batchResults.SessionName}, p.Results.NamePattern);
    else
        metadata = normalizeMetadata(metadata, {batchResults.SessionName}, p.Results.NamePattern);
    end

    metrics = p.Results.Metrics;
    metricsByAct = p.Results.MetricsByAct;
    actNames = collectActNames(batchResults);
    sessions = unique(metadata.session, 'stable');
    mice = unique(metadata.mouse, 'stable');

    % Resolve per-act metric list. If MetricsByAct is non-empty, use it
    % for any act it covers; fall back to the flat Metrics list for
    % acts it doesn't mention. With empty MetricsByAct every act uses
    % the flat list (backward-compat).
    perAct = resolvePerActMetrics(actNames, metricsByAct, metrics);

    % Tidy long-format table first
    tidy = buildTidy(batchResults, metadata, actNames, perAct);

    % Wide pivot
    wide = pivotWide(tidy, mice, sessions, actNames, perAct);

    % Add distance / velocity columns (one per session). Distance unit
    % is settable via GeneralDistanceUnit.
    wide = addPerSessionScalar(wide, batchResults, metadata, mice, sessions, ...
        'Distance', 'distance', p.Results.GeneralDistanceUnit);
    wide = addPerSessionScalar(wide, batchResults, metadata, mice, sessions, ...
        'Velocity', 'velocity', 'cm_per_s');

    % Attach mouse / group / line columns at the front
    miceMeta = uniqueMiceMetadata(metadata);
    wide = outerjoin(miceMeta, wide, 'Keys', 'mouse', 'MergeKeys', true);

    % Sort
    sortBy = p.Results.SortBy;
    sortBy = sortBy(ismember(sortBy, wide.Properties.VariableNames));
    if ~isempty(sortBy)
        wide = sortrows(wide, sortBy);
    end

    % Unit conversion + rounding for distance/velocity. Done last so it
    % applies to any join/sort done above.
    [wide, tidy] = applyUnitsAndRounding(wide, tidy, ...
        p.Results.GeneralDistanceUnit, p.Results.PerActDistanceUnit);

    % NaN policy
    if strcmp(p.Results.NaNPolicy, 'zero')
        for k = 1:width(wide)
            v = wide.(k);
            if isnumeric(v); v(isnan(v)) = 0; wide.(k) = v; end
        end
    end

    ST.Wide = wide;
    ST.Tidy = tidy;
    ST.Meta = metadata;
    ST.Acts = actNames;
    ST.Sessions = sessions;
end

% --- Helpers ---------------------------------------------------------------

function meta = normalizeMetadata(user, sessionNames, pattern)
    % Accept any of:
    %   (a) full form: session_name / mouse / session / group / line / ...
    %   (b) short form: mouse + arbitrary ID_* columns
    %                   -> cross-joined with parsed sessions from
    %                      batchResults SessionNames.
    % Column names are matched case-insensitively, ID_ prefix is
    % stripped, common aliases are resolved (ID_mouse -> mouse,
    % Subject -> mouse, etc.). Any extra columns (ID_sex, ID_drug, ...)
    % are passed through as additional grouping factors.

    user = renameUserColumns(user);
    have = user.Properties.VariableNames;

    if any(strcmpi(have, 'session_name'))
        meta = ensureColumns(user, sessionNames, pattern);
        return;
    end

    if ~any(strcmpi(have, 'mouse'))
        error('buildSuperTable:badMetadata', ...
            'Metadata must contain a "mouse" or "session_name" column. Got: %s', ...
            strjoin(have, ', '));
    end

    parsed = parseMetadataFromNames(sessionNames, pattern);

    % Bring user.mouse and parsed.mouse to the same form before join.
    % If user provided mouse like "WNOF_A01" (with exp prefix), we need
    % parsed.mouse to match. parsed.mouse from the regex is the bare
    % token (e.g. "A01"). Detect prefix usage on the user side and
    % upgrade parsed.mouse accordingly.
    user.mouse = cellstr(string(user.mouse));
    parsed.mouse = cellstr(string(parsed.mouse));
    if userMouseHasExpPrefix(user.mouse, parsed)
        parsed.mouse = strcat(parsed.exp, '_', parsed.mouse);
    end

    meta = outerjoin(parsed(:, {'session_name', 'mouse', 'session'}), ...
        user, 'Keys', 'mouse', 'MergeKeys', true, 'Type', 'left');

    % Fill missing cells for any string-typed grouping column the user
    % provided. Do NOT auto-add group/line if the user didn't supply
    % them — keep Wide compact.
    skip = {'mouse', 'session', 'session_name'};
    for k = 1:width(meta)
        nm = meta.Properties.VariableNames{k};
        if any(strcmp(skip, nm)); continue; end
        v = meta.(nm);
        if iscell(v) || isstring(v) || ischar(v)
            meta.(nm) = fillMissingCellStr(v, 'unknown');
        end
    end
end

function tf = userMouseHasExpPrefix(userMouseList, parsed)
    % Returns true if user's mouse values include at least one entry
    % whose first underscore-separated token matches any parsed exp.
    if isempty(userMouseList); tf = false; return; end
    sample = userMouseList{find(~cellfun('isempty', userMouseList), 1)};
    if isempty(sample) || ~contains(sample, '_'); tf = false; return; end
    tokens = strsplit(sample, '_');
    if isempty(tokens); tf = false; return; end
    tf = any(strcmp(parsed.exp, tokens{1}));
end

function T = renameUserColumns(T)
    aliases = struct( ...
        'id_mouse',   'mouse',   'mouse_id',  'mouse', ...
        'subject',    'mouse',   'animal',    'mouse', ...
        'id_group',   'group',   'group_id',  'group', ...
        'id_line',    'line',    'line_id',   'line', ...
        'sessionname','session_name', 'session_id', 'session_name');
    aliasKeys = fieldnames(aliases);
    names = T.Properties.VariableNames;
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for k = 1:numel(names)
        lower_name = lower(names{k});
        if any(strcmp(aliasKeys, lower_name))
            newName = aliases.(lower_name);
        elseif startsWith(lower_name, 'id_')
            % Strip ID_ prefix for any user column (ID_sex -> sex, ...).
            newName = lower_name(4:end);
        else
            newName = lower_name;
        end
        % Guard against duplicate-after-rename collisions (e.g. two
        % columns reducing to the same name) — keep the first, suffix
        % the rest.
        if seen.isKey(newName)
            i = 2;
            while seen.isKey(sprintf('%s_%d', newName, i)); i = i + 1; end
            newName = sprintf('%s_%d', newName, i);
        end
        seen(newName) = true;
        T.Properties.VariableNames{k} = newName;
    end
end

function T = ensureColumns(T, sessionNames, pattern)
    have = T.Properties.VariableNames;
    if ~any(strcmpi(have, 'mouse')) || ~any(strcmpi(have, 'session'))
        parsed = parseMetadataFromNames(sessionNames, pattern);
        if ~any(strcmpi(have, 'mouse'));   T.mouse   = parsed.mouse;   end
        if ~any(strcmpi(have, 'session')); T.session = parsed.session; end
    end
end

function c = fillMissingCellStr(c, fillVal)
    if ~iscell(c); c = cellstr(string(c)); end
    for k = 1:numel(c)
        if isempty(c{k}) || (isnumeric(c{k}) && all(isnan(c{k})))
            c{k} = fillVal;
        end
    end
end

function meta = parseMetadataFromNames(sessionNames, pattern)
    n = numel(sessionNames);
    exp = repmat({''}, n, 1);
    mouse = repmat({''}, n, 1);
    session = repmat({''}, n, 1);
    for k = 1:n
        m = regexp(sessionNames{k}, pattern, 'names');
        if ~isempty(m)
            if isfield(m, 'exp');   exp{k}   = m.exp;     end
            mouse{k}   = m.mouse;
            session{k} = m.session;
        else
            mouse{k} = sessionNames{k};
            session{k} = '1D';
        end
    end
    meta = table(sessionNames(:), exp, mouse, session, ...
        'VariableNames', {'session_name', 'exp', 'mouse', 'session'});
end

function names = collectActNames(batchResults)
    names = {};
    for k = 1:numel(batchResults)
        if isfield(batchResults(k), 'Acts') && ~isempty(batchResults(k).Acts)
            names = union(names, {batchResults(k).Acts.ActName});
        end
    end
    names = names(:)';
end

function perAct = resolvePerActMetrics(actNames, metricsByAct, flatMetrics)
    % Map each act -> cellstr of metric names. metricsByAct may have
    % name fields whose values are cellstr or string array. Acts not
    % covered fall back to flatMetrics.
    perAct = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:numel(actNames)
        nm = actNames{k};
        if isfield(metricsByAct, nm)
            v = metricsByAct.(nm);
            if isstring(v); v = cellstr(v); end
            if ischar(v); v = {v}; end
            perAct(nm) = v;
        else
            % Try a case-insensitive fallback (legacy acts spelled
            % with different casing — Object1 vs object1).
            keys = fieldnames(metricsByAct);
            hit = find(strcmpi(keys, nm), 1);
            if ~isempty(hit)
                v = metricsByAct.(keys{hit});
                if isstring(v); v = cellstr(v); end
                if ischar(v); v = {v}; end
                perAct(nm) = v;
            else
                perAct(nm) = flatMetrics;
            end
        end
    end
end

function tidy = buildTidy(batchResults, metadata, actNames, perAct)
    rows = {};
    for f = 1:numel(batchResults)
        sname = batchResults(f).SessionName;
        midx = find(strcmp(metadata.session_name, sname), 1);
        if isempty(midx); continue; end
        mouse = metadata.mouse{midx};
        sess  = metadata.session{midx};
        for a = 1:numel(actNames)
            actIdx = find(strcmp({batchResults(f).Acts.ActName}, actNames{a}), 1);
            metrics = perAct(actNames{a});
            for m = 1:numel(metrics)
                v = NaN;
                if ~isempty(actIdx) && isfield(batchResults(f).Acts(actIdx), metrics{m})
                    val = batchResults(f).Acts(actIdx).(metrics{m});
                    if ~isempty(val); v = double(val(1)); end
                end
                rows(end+1, :) = {mouse, sess, actNames{a}, metrics{m}, v}; %#ok<AGROW>
            end
        end
    end
    if isempty(rows)
        tidy = table('Size', [0 5], ...
            'VariableTypes', {'cell','cell','cell','cell','double'}, ...
            'VariableNames', {'mouse', 'session', 'act', 'metric', 'value'});
        return;
    end
    tidy = cell2table(rows, 'VariableNames', ...
        {'mouse', 'session', 'act', 'metric', 'value'});
end

function wide = pivotWide(tidy, mice, sessions, actNames, perAct)
    wide = table();
    wide.mouse = mice(:);
    for a = 1:numel(actNames)
        metrics = perAct(actNames{a});
        for m = 1:numel(metrics)
            for s = 1:numel(sessions)
                col = nan(numel(mice), 1);
                for k = 1:numel(mice)
                    mask = strcmp(tidy.mouse, mice{k}) & ...
                           strcmp(tidy.session, sessions{s}) & ...
                           strcmp(tidy.act, actNames{a}) & ...
                           strcmp(tidy.metric, metrics{m});
                    rec = tidy(mask, :);
                    if ~isempty(rec); col(k) = rec.value(1); end
                end
                colName = matlab.lang.makeValidName(sprintf('%s_%s_%s', ...
                    actNames{a}, prettyMetric(metrics{m}), sessions{s}));
                wide.(colName) = col;
            end
        end
    end
end

function wide = addPerSessionScalar(wide, batchResults, metadata, mice, sessions, srcField, prefix, unit)
    for s = 1:numel(sessions)
        col = nan(numel(mice), 1);
        for k = 1:numel(mice)
            sessName = metadata.session_name(strcmp(metadata.mouse, mice{k}) & ...
                                              strcmp(metadata.session, sessions{s}));
            if isempty(sessName); continue; end
            idx = find(strcmp({batchResults.SessionName}, sessName{1}), 1);
            if isempty(idx); continue; end
            if isfield(batchResults(idx), srcField) && ~isempty(batchResults(idx).(srcField))
                col(k) = double(batchResults(idx).(srcField)(1));
            end
        end
        wide.(matlab.lang.makeValidName(sprintf('%s_%s_%s', prefix, unit, sessions{s}))) = col;
    end
end

function s = prettyMetric(m)
    switch m
        case 'ActPercent';      s = 'percent';
        case 'ActDuration';     s = 'duration_s';
        case 'ActNumber';       s = 'count';
        case 'ActMeanTime';     s = 'mean_dur_s';
        case 'ActMedianTime';   s = 'median_dur_s';
        case 'ActMeanVelocity'; s = 'mean_v_cm_s';
        case 'ActMaxVelocity';  s = 'max_v_cm_s';
        case 'ActMinVelocity';  s = 'min_v_cm_s';
        case 'ActVelocity';     s = 'mean_v_cm_s';
        case 'Distance';        s = 'distance_cm';
        case 'ActMeanDistance'; s = 'mean_dist_cm';
        case 'FirstStartSec';   s = 'first_start_s';
        case 'FirstEndSec';     s = 'first_end_s';
        case 'LastStartSec';    s = 'last_start_s';
        case 'LastEndSec';      s = 'last_end_s';
        otherwise; s = m;
    end
end

function T = uniqueMiceMetadata(meta)
    [~, ia] = unique(meta.mouse, 'stable');
    % Carry every per-mouse column except the per-session ones.
    skip = {'session', 'session_name'};
    cols = meta.Properties.VariableNames;
    cols = cols(~ismember(cols, skip));
    % Keep 'mouse' first for cleaner output.
    cols = ['mouse', cols(~strcmp(cols, 'mouse'))];
    T = meta(ia, cols);
end

function [wide, tidy] = applyUnitsAndRounding(wide, tidy, generalUnit, perActUnit)
    % Distance values are stored in cm everywhere upstream.
    %   General distance column name was already created with the chosen
    %   unit suffix (distance_<unit>_<session>), but the value is still
    %   in cm and needs conversion when unit='m'.
    %   Per-act distance column is always `<act>_distance_cm_<session>`;
    %   we rename to _distance_m_ when perActUnit='m'.
    %
    % Rounding rules:
    %   cm  -> nearest integer
    %   m   -> 2 decimals
    %   velocity (always cm/s) -> 1 decimal

    % ----- Wide -----
    cols = wide.Properties.VariableNames;
    for k = 1:numel(cols)
        nm = cols{k};
        v = wide.(nm);
        if ~isnumeric(v); continue; end

        % General distance: 'distance_<unit>_<session>' (no leading act).
        tok = regexp(nm, '^distance_(cm|m)_(.+)$', 'tokens', 'once');
        if ~isempty(tok)
            sess = tok{2};
            [vNew, newName] = convertDistance(v, 'distance', '', sess, generalUnit);
            wide.(nm) = vNew;
            wide = renameVar(wide, nm, newName);
            continue;
        end

        % Per-act distance: '<act>_distance_cm_<session>'.
        tok = regexp(nm, '^(.+)_distance_cm_(.+)$', 'tokens', 'once');
        if ~isempty(tok)
            [vNew, newName] = convertDistance(v, 'distance', tok{1}, tok{2}, perActUnit);
            wide.(nm) = vNew;
            wide = renameVar(wide, nm, newName);
            continue;
        end

        % Velocity (general): 'velocity_cm_per_s_<session>'.
        % Per-act velocity:   '<act>_(mean|max|min)_v_cm_s_<session>'.
        if startsWith(nm, 'velocity_cm_per_s_') ...
                || ~isempty(regexp(nm, '_(mean|max|min)_v_cm_s_', 'once'))
            wide.(nm) = roundTo(v, 1);
            continue;
        end
    end

    % ----- Tidy -----
    if isempty(tidy) || height(tidy) == 0; return; end
    velMetrics = {'ActMeanVelocity','ActMaxVelocity','ActMinVelocity','ActVelocity'};
    for k = 1:height(tidy)
        metric = tidy.metric{k};
        val = tidy.value(k);
        if isnan(val); continue; end
        if strcmp(metric, 'Distance')
            if strcmpi(perActUnit, 'm')
                tidy.value(k) = roundTo(val / 100, 2);
            else
                tidy.value(k) = roundTo(val, 0);
            end
        elseif any(strcmp(velMetrics, metric))
            tidy.value(k) = roundTo(val, 1);
        end
    end
end

function [v, newName] = convertDistance(v, baseName, actPrefix, sess, unit)
    if strcmpi(unit, 'm')
        v = v / 100;
        v = roundTo(v, 2);
        suffix = 'm';
    else
        v = roundTo(v, 0);
        suffix = 'cm';
    end
    if isempty(actPrefix)
        newName = sprintf('%s_%s_%s', baseName, suffix, sess);
    else
        newName = sprintf('%s_%s_%s_%s', actPrefix, baseName, suffix, sess);
    end
end

function v = roundTo(v, n)
    f = 10^n;
    v = round(v * f) / f;
end

function T = renameVar(T, oldName, newName)
    if strcmp(oldName, newName); return; end
    idx = find(strcmp(T.Properties.VariableNames, oldName), 1);
    if isempty(idx); return; end
    % If a column with the new name already exists, leave the old one
    % alone — caller should not produce duplicate targets.
    if any(strcmp(T.Properties.VariableNames, newName)); return; end
    T.Properties.VariableNames{idx} = newName;
end

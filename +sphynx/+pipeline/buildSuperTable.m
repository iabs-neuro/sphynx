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
    p.addParameter('NamePattern', '^(?<exp>[^_]+)_(?<mouse>[^_]+)_(?<session>\d+D)$', @ischar);
    p.addParameter('Metrics', {'ActPercent', 'ActDuration', 'ActNumber', 'ActMeanTime'}, @iscell);
    p.addParameter('NaNPolicy', 'keep', @(s) any(strcmp(s, {'keep', 'zero'})));
    p.addParameter('SortBy', {'group', 'line', 'mouse'}, @iscell);
    parse(p, batchResults, varargin{:});

    metadata = p.Results.Metadata;
    if isempty(metadata)
        metadata = parseMetadataFromNames({batchResults.SessionName}, p.Results.NamePattern);
    end

    metrics = p.Results.Metrics;
    actNames = collectActNames(batchResults);
    sessions = unique(metadata.session, 'stable');
    mice = unique(metadata.mouse, 'stable');

    % Tidy long-format table first
    tidy = buildTidy(batchResults, metadata, actNames, metrics);

    % Wide pivot
    wide = pivotWide(tidy, mice, sessions, actNames, metrics);

    % Add distance / velocity columns (one per session)
    wide = addPerSessionScalar(wide, batchResults, metadata, mice, sessions, ...
        'Distance', 'distance', 'cm');
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

function meta = parseMetadataFromNames(sessionNames, pattern)
    n = numel(sessionNames);
    mouse = repmat({''}, n, 1);
    session = repmat({''}, n, 1);
    for k = 1:n
        m = regexp(sessionNames{k}, pattern, 'names');
        if ~isempty(m)
            mouse{k}   = m.mouse;
            session{k} = m.session;
        else
            mouse{k} = sessionNames{k};
            session{k} = '1D';
        end
    end
    meta = table(sessionNames(:), mouse, session, ...
        repmat({'unknown'}, n, 1), repmat({'unknown'}, n, 1), ...
        'VariableNames', {'session_name', 'mouse', 'session', 'group', 'line'});
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

function tidy = buildTidy(batchResults, metadata, actNames, metrics)
    rows = {};
    for f = 1:numel(batchResults)
        sname = batchResults(f).SessionName;
        midx = find(strcmp(metadata.session_name, sname), 1);
        if isempty(midx); continue; end
        mouse = metadata.mouse{midx};
        sess  = metadata.session{midx};
        for a = 1:numel(actNames)
            actIdx = find(strcmp({batchResults(f).Acts.ActName}, actNames{a}), 1);
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
    tidy = cell2table(rows, 'VariableNames', ...
        {'mouse', 'session', 'act', 'metric', 'value'});
end

function wide = pivotWide(tidy, mice, sessions, actNames, metrics)
    wide = table();
    wide.mouse = mice(:);
    for a = 1:numel(actNames)
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
        case 'ActPercent';   s = 'percent';
        case 'ActDuration';  s = 'duration_s';
        case 'ActNumber';    s = 'count';
        case 'ActMeanTime';  s = 'mean_dur_s';
        otherwise; s = m;
    end
end

function T = uniqueMiceMetadata(meta)
    [~, ia] = unique(meta.mouse, 'stable');
    cols = {'mouse', 'group', 'line'};
    cols = cols(ismember(cols, meta.Properties.VariableNames));
    T = meta(ia, cols);
end

function L = metricToLong(T, metric, idCol, factorCols)
% METRICTOLONG  Reshape a wide table into long form for one metric.
%
%   L = sphynx.stats.metricToLong(T, metric, idCol, factorCols)
%
%   Input:
%     T          - wide table from MakeOutputTable.
%     metric     - one element of the struct returned by extractMetrics
%                  (fields: label, kind, columns, sessions).
%     idCol      - name of the subject/mouse column.
%     factorCols - cellstr of factor columns to carry along.
%
%   Output:
%     L - long table with columns
%           subject  (from idCol)
%           session  (parsed from each column name; '' if metric has no session)
%           <each factor>
%           value
%         One row per (subject, session). Sessions that are NaN for a
%         given mouse are emitted with value=NaN (so callers see the
%         missing cell).

    subj = T.(idCol);
    if ~iscell(subj); subj = cellstr(string(subj)); end

    rows = {};
    cols = metric.columns;
    for c = 1:numel(cols)
        nm = cols{c};
        sess = parseSession(nm, metric.kind);
        vals = T.(nm);
        for r = 1:height(T)
            v = NaN;
            if isnumeric(vals); v = double(vals(r)); end
            rowFactors = cell(1, numel(factorCols));
            for fi = 1:numel(factorCols)
                fv = T.(factorCols{fi})(r);
                if iscell(fv); fv = fv{1}; end
                if isstring(fv); fv = char(fv); end
                rowFactors{fi} = fv;
            end
            rows(end+1, :) = [{subj{r}, sess}, rowFactors, {v}]; %#ok<AGROW>
        end
    end

    if isempty(rows)
        L = table('Size', [0, 2 + numel(factorCols) + 1], ...
            'VariableTypes', [{'cell','cell'}, repmat({'cell'}, 1, numel(factorCols)), {'double'}], ...
            'VariableNames', [{'subject','session'}, factorCols, {'value'}]);
        return;
    end
    L = cell2table(rows, 'VariableNames', ...
        [{'subject','session'}, factorCols, {'value'}]);
end

function sess = parseSession(colName, kind)
    sess = '';
    switch kind
        case 'per_act'
            % Strip leading '<act>_<metricSuf>_' to get session.
            % Try common suffixes from longest first.
            sufs = {'mean_v_cm_s','max_v_cm_s','min_v_cm_s', ...
                    'first_start_s','first_end_s','last_start_s','last_end_s', ...
                    'mean_dist_cm','mean_dur_s','median_dur_s', ...
                    'duration_s','percent','count','distance_cm','distance_m'};
            for s = 1:numel(sufs)
                tok = regexp(colName, sprintf('_%s_(.+)$', sufs{s}), 'tokens', 'once');
                if ~isempty(tok); sess = tok{1}; return; end
            end
        case 'general_distance'
            tok = regexp(colName, '^distance_(?:cm|m)_(.+)$', 'tokens', 'once');
            if ~isempty(tok); sess = tok{1}; end
        case 'general_velocity'
            tok = regexp(colName, '^velocity_cm_per_s_(.+)$', 'tokens', 'once');
            if ~isempty(tok); sess = tok{1}; end
        otherwise
            sess = '';
    end
end

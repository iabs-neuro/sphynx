function info = detectFactors(L, factorNames)
% DETECTFACTORS  Determine within-subject vs between-subject status of
% each factor in a long-form table.
%
%   info = sphynx.stats.detectFactors(L, factorNames)
%
%   A factor is within-subject if at least one subject appears at >1
%   distinct level of that factor. Otherwise it's between-subject.
%   The implicit 'session' column is checked the same way.
%
%   Output: struct array with fields .name, .within, .levels (cellstr).

    info = struct('name', {}, 'within', {}, 'levels', {});
    if isempty(L) || height(L) == 0; return; end

    % Always check 'session' if present and non-empty.
    fields = factorNames;
    if any(strcmp(L.Properties.VariableNames, 'session')) && ...
            ~all(cellfun('isempty', L.session))
        fields = [{'session'}, fields(:)'];
    end

    subj = L.subject;
    if ~iscell(subj); subj = cellstr(string(subj)); end

    for k = 1:numel(fields)
        nm = fields{k};
        if ~any(strcmp(L.Properties.VariableNames, nm)); continue; end
        v = L.(nm);
        if ~iscell(v); v = cellstr(string(v)); end
        levels = unique(v(~cellfun('isempty', v)), 'stable');
        if numel(levels) < 2
            info(end+1) = struct('name', nm, 'within', false, 'levels', {levels(:)'}); %#ok<AGROW>
            continue;
        end
        % within iff any subject appears at >1 level
        within = false;
        usub = unique(subj);
        for s = 1:numel(usub)
            mask = strcmp(subj, usub{s});
            sLevels = unique(v(mask));
            if numel(sLevels) > 1; within = true; break; end
        end
        info(end+1) = struct('name', nm, 'within', within, 'levels', {levels(:)'}); %#ok<AGROW>
    end
end

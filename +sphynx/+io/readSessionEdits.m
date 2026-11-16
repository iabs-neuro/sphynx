function [edits, path] = readSessionEdits(config, sessionName)
% READSESSIONEDITS  Per-session corrections of a recording: trimmed ends
% and periods when the animal was outside the arena.
%
%   [edits, path] = sphynx.io.readSessionEdits(config, sessionName)
%
% The edits file is a csv with columns
%   session  - session name, e.g. LT1_J06_2D
%   kind     - 'trim'    : drop [start_s, end_s) from the analysis.
%                          Only a leading (start_s = 0) or trailing
%                          (end_s empty) piece can be dropped.
%              'outside' : the animal is off the arena in
%                          [start_s, end_s); analyzeSession marks these
%                          frames with the act 'outside' and excludes
%                          them from every other act and from the
%                          denominator of act percentages.
%   start_s, end_s - seconds from the first video frame (frame 1 = 0 s).
%                    Empty end_s means "to the end of the recording".
%   Any other columns (source, note) are kept but not used.
%
% Explicit config.paths.sessionEdits wins; otherwise the first
% *_SessionEdits.csv found walking up to 4 levels from the DLC folder is
% used, the same discovery as for *_PreprocessSettings.mat.
%
% Returns:
%   edits - table of the rows for sessionName (possibly 0 rows), or []
%           when no edits file exists for this experiment.
%   path  - the file used ('' when none).

    edits = [];
    path = '';
    if isfield(config.paths, 'sessionEdits') && ~isempty(config.paths.sessionEdits)
        path = char(config.paths.sessionEdits);
        if ~isfile(path)
            error('sphynx:sessionEdits', 'Session edits file not found: %s', path);
        end
    elseif ~isempty(config.paths.dlc)
        d = fileparts(config.paths.dlc);
        for hop = 1:4
            if isempty(d) || ~isfolder(d); break; end
            hits = dir(fullfile(d, '*_SessionEdits.csv'));
            if ~isempty(hits)
                path = fullfile(hits(1).folder, hits(1).name);
                break;
            end
            parent = fileparts(d);
            if strcmp(parent, d); break; end
            d = parent;
        end
    end
    if isempty(path); return; end

    opts = detectImportOptions(path, 'Delimiter', ',');
    opts = setvartype(opts, intersect({'session', 'kind', 'source', 'note'}, ...
        opts.VariableNames), 'char');
    opts = setvartype(opts, {'start_s', 'end_s'}, 'double');
    t = readtable(path, opts);
    missing = setdiff({'session', 'kind', 'start_s', 'end_s'}, t.Properties.VariableNames);
    if ~isempty(missing)
        error('sphynx:sessionEdits', '%s lacks columns: %s', path, strjoin(missing, ', '));
    end
    t.kind = lower(strtrim(t.kind));
    bad = ~ismember(t.kind, {'trim', 'outside'});
    if any(bad)
        error('sphynx:sessionEdits', '%s: unknown kind "%s"', path, t.kind{find(bad, 1)});
    end
    edits = t(strcmp(strtrim(t.session), sessionName), :);
end

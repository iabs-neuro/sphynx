function out = readDefaultsJsonc(path)
% READDEFAULTSJSONC  Read the repo-root sphynx_defaults.jsonc file.
%
%   out = sphynx.io.readDefaultsJsonc()       % auto-locate
%   out = sphynx.io.readDefaultsJsonc(path)   % explicit path
%
%   Returns a struct with the parsed values, or [] if the file isn't
%   found. Strips // line and /* */ block comments before handing
%   the text to MATLAB's jsondecode, so the source file can carry
%   the same enum-options comments humans use.
%
%   Auto-location: walks up to 5 directories from the caller's
%   working directory looking for sphynx_defaults.jsonc, then
%   tries sphynx.util.repoRoot() as a last fallback.

    if nargin < 1 || isempty(path)
        path = locate();
    end
    out = [];
    if isempty(path) || ~isfile(path); return; end

    txt = fileread(path);
    txt = stripComments(txt);

    try
        out = jsondecode(txt);
    catch ME
        warning('sphynx:readDefaultsJsonc:parseFailed', ...
            'Failed to parse %s: %s', path, ME.message);
        out = [];
    end
end

function path = locate()
    path = '';
    cur = pwd;
    for hop = 1:5
        cand = fullfile(cur, 'sphynx_defaults.jsonc');
        if isfile(cand); path = cand; return; end
        parent = fileparts(cur);
        if isempty(parent) || strcmp(parent, cur); break; end
        cur = parent;
    end
    try
        root = sphynx.util.repoRoot();
        cand = fullfile(root, 'sphynx_defaults.jsonc');
        if isfile(cand); path = cand; end
    catch
    end
end

function txt = stripComments(txt)
    % Drop /* ... */ blocks first (multi-line ok), then // ... EOL.
    % Naive but works on a hand-edited config file -- we're not trying
    % to handle pathological cases (// inside strings, etc.).
    txt = regexprep(txt, '/\*.*?\*/', '', 'dotall');
    txt = regexprep(txt, '//[^\n\r]*', '');
end

function a = buildComplexAct(varargin)
% BUILDCOMPLEXACT  Combine N existing acts with a logical operation.

    p = inputParser;
    p.addParameter('Name', '', @(s) ischar(s) || isstring(s));
    p.addParameter('Components', {}, @iscell);
    p.addParameter('Operation', 'intersect', ...
        @(s) any(strcmpi(s, {'intersect', 'union', 'exclude', 'sequence'})));
    p.addParameter('SeqDelaySec', 0, @isnumeric);
    p.addParameter('MinDurationSec', 0.25, @(v) isnumeric(v) && v >= 0);
    p.addParameter('MinGapSec', 0, @(v) isnumeric(v) && v >= 0);
    parse(p, varargin{:});

    a = sphynx.acts.emptyAct();
    a.name = char(p.Results.Name);
    a.type = 'complex';
    a.components = p.Results.Components;
    a.operation = lower(p.Results.Operation);
    a.seqDelaySec = p.Results.SeqDelaySec;
    a.minDurationSec = p.Results.MinDurationSec;
    a.minGapSec      = p.Results.MinGapSec;
end

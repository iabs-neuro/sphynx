function a = buildComplexAct(varargin)
% BUILDCOMPLEXACT  Combine N existing acts with a logical operation.

    p = inputParser;
    p.addParameter('Name', '', @(s) ischar(s) || isstring(s));
    p.addParameter('Components', {}, @iscell);
    p.addParameter('Operation', 'intersect', ...
        @(s) any(strcmpi(s, {'intersect', 'union', 'exclude', 'sequence'})));
    p.addParameter('SeqDelaySec', 0, @isnumeric);
    parse(p, varargin{:});

    a = sphynx.acts.emptyAct();
    a.name = char(p.Results.Name);
    a.type = 'complex';
    a.components = p.Results.Components;
    a.operation = lower(p.Results.Operation);
    a.seqDelaySec = p.Results.SeqDelaySec;
end

function a = buildSimpleAct(varargin)
% BUILDSIMPLEACT  name + zone(s) + body part + speed range -> act struct.

    p = inputParser;
    p.addParameter('Name', '', @(s) ischar(s) || isstring(s));
    p.addParameter('Zones', {}, @(c) iscell(c) || ischar(c) || isstring(c));
    p.addParameter('ZoneOp', 'OR', @(s) any(strcmpi(s, {'AND', 'OR', 'EXCLUDE'})));
    p.addParameter('BodyPart', '', @(s) ischar(s) || isstring(s));
    p.addParameter('SpeedMin', 0, @isnumeric);
    p.addParameter('SpeedMax', Inf, @isnumeric);
    p.addParameter('MinDurationSec', 0.25, @(v) isnumeric(v) && v >= 0);
    p.addParameter('MaxGapSec', 0.25, @(v) isnumeric(v) && v >= 0);
    parse(p, varargin{:});

    a = sphynx.acts.emptyAct();
    a.name = char(p.Results.Name);
    a.type = 'simple';
    z = p.Results.Zones;
    if ischar(z) || isstring(z); z = {char(z)}; end
    a.zones = z;
    a.zoneOp = upper(p.Results.ZoneOp);
    a.bodyPart = char(p.Results.BodyPart);
    a.speedMin = p.Results.SpeedMin;
    a.speedMax = p.Results.SpeedMax;
    a.minDurationSec = p.Results.MinDurationSec;
    a.maxGapSec      = p.Results.MaxGapSec;
end

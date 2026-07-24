function Zones = buildZonesCircle(arenaMask, varargin)
% BUILDZONESCIRCLE  Construct legacy-shape Zones struct for round arenas.
%
%   Thin adapter around sphynx.zones.classifyCircle. Forward all
%   name-value parameters: PixelsPerCm, WallWidthCm, MiddleWidthCm,
%   MinCenterCm.

    raw = sphynx.zones.classifyCircle(arenaMask, varargin{:});
    Zones = struct('name', {raw.name}, 'type', {raw.type}, 'maskfilled', {raw.maskfilled});
end

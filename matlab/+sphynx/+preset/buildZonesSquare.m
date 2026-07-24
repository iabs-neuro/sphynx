function Zones = buildZonesSquare(arenaMask, varargin)
% BUILDZONESSQUARE  Construct legacy-shape Zones struct array for square arenas.
%
%   Zones = sphynx.preset.buildZonesSquare(arenaMask, ...) is a thin
%   adapter around sphynx.zones.classifySquare that produces the
%   legacy-style Zones output format expected by analyzeSession and
%   downstream code.
%
%   Forward all name-value parameters to classifySquare:
%     'Strategy'        'corners-walls-center' | 'strips' | 'none'
%     'PixelsPerCm'     scale factor
%     'WallWidthCm'     default 3
%     'CornerPoints'    Nx2 [x y]
%     'NumStrips', 'StripDirection'  for strips strategy
%
%   Output struct array fields: name, type, maskfilled.

    raw = sphynx.zones.classifySquare(arenaMask, varargin{:});
    Zones = struct('name', {raw.name}, 'type', {raw.type}, 'maskfilled', {raw.maskfilled});
end

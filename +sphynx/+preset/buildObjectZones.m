function Zones = buildObjectZones(objects, frameH, frameW, varargin)
% BUILDOBJECTZONES  Construct per-object zone masks for analyzeSession.
%
%   Zones = sphynx.preset.buildObjectZones(objects, H, W, ...) returns
%   a Zones struct array (legacy shape: name, type, maskfilled) with
%   per-object and combined-objects zones.
%
%   Inputs:
%     objects - 1xK struct array as built by readObjects (each has
%               .mask : HxW logical for the object polygon)
%     H, W    - frame size in pixels
%
%   Optional name-value:
%     'PixelsPerCm'        required when ZoneWidthCm > 0
%     'ZoneWidthCm'        default 2.5 — inflation radius for the
%                          interaction zone around each object
%
%   For each object i, three zones are built (matching legacy):
%     ObjectiReal     - the object polygon itself
%     ObjectiRealOut  - object inflated by ZoneWidthCm (includes
%                       the object area)
%     ObjectiOut      - inflated zone MINUS the object itself
%                       (the surrounding ring only)
%
%   When K >= 2, three combined zones are also added:
%     ObjectAllReal, ObjectAllRealOut, ObjectAllOut
%
%   Decomposition of legacy CreatePreset.m:436-485.

    p = inputParser;
    addRequired(p, 'objects');
    addRequired(p, 'frameH');
    addRequired(p, 'frameW');
    addParameter(p, 'PixelsPerCm', [], @(v) isempty(v) || (isnumeric(v) && v > 0));
    addParameter(p, 'ZoneWidthCm', 2.5, @(v) isnumeric(v) && v >= 0);
    parse(p, objects, frameH, frameW, varargin{:});

    Zones = struct('name', {}, 'type', {}, 'maskfilled', {});
    if isempty(objects); return; end

    if isempty(p.Results.PixelsPerCm) && p.Results.ZoneWidthCm > 0
        error('sphynx:buildObjectZones:missingPixelsPerCm', ...
            'PixelsPerCm is required when ZoneWidthCm > 0');
    end
    widthPxl = p.Results.ZoneWidthCm * ifEmpty(p.Results.PixelsPerCm, 1);

    nObj = numel(objects);

    % Per-object zones
    for i = 1:nObj
        objMask = logical(objects(i).mask);
        objName = objects(i).type;
        if isempty(objName); objName = sprintf('Object%d', i); end

        Zones(end+1) = mkZone([objName 'Real'], objMask); %#ok<AGROW>
        if widthPxl > 0
            d = bwdist(objMask);
            inflated = d <= widthPxl;
            Zones(end+1) = mkZone([objName 'RealOut'], inflated); %#ok<AGROW>
            Zones(end+1) = mkZone([objName 'Out'], inflated & ~objMask); %#ok<AGROW>
        end
    end

    % Combined zones
    if nObj >= 2
        allReal = false(frameH, frameW);
        allRealOut = false(frameH, frameW);
        for i = 1:nObj
            allReal = allReal | logical(objects(i).mask);
            if widthPxl > 0
                d = bwdist(logical(objects(i).mask));
                allRealOut = allRealOut | (d <= widthPxl);
            end
        end
        Zones(end+1) = mkZone('ObjectAllReal', allReal);
        if widthPxl > 0
            Zones(end+1) = mkZone('ObjectAllRealOut', allRealOut);
            Zones(end+1) = mkZone('ObjectAllOut', allRealOut & ~allReal);
        end
    end
end

function z = mkZone(name, mask)
    z.name = name;
    z.type = 'area';
    z.maskfilled = mask;
end

function v = ifEmpty(x, fallback)
    if isempty(x); v = fallback; else; v = x; end
end

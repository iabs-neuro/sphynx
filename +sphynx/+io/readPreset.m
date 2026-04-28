function out = readPreset(matPath)
% READPRESET  Load a sphynx preset .mat file.
%
%   out = sphynx.io.readPreset(matPath)
%
%   Loads the legacy preset .mat shape (fields Options, Zones,
%   ArenaAndObjects) and returns them as a struct.
%
%   Preset structure (legacy):
%     Options          - struct with frame rate, calibration, thresholds
%     Zones            - 1xZ struct array of named masks
%     ArenaAndObjects  - 1x(K) struct array (1 = arena, then objects)

    if ~isfile(matPath)
        error('sphynx:readPreset:notFound', 'Preset .mat not found: %s', matPath);
    end
    s = load(matPath);
    out.Options = pickField(s, 'Options');
    out.Zones = pickField(s, 'Zones');
    out.ArenaAndObjects = pickField(s, 'ArenaAndObjects');
end

function v = pickField(s, name)
    if isfield(s, name)
        v = s.(name);
    else
        v = [];
    end
end

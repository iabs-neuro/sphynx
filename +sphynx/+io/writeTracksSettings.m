function writeTracksSettings(path, perPartArray, outlier, experimentName)
% WRITETRACKSSETTINGS  Persist per-experiment preprocess settings.
%
%   sphynx.io.writeTracksSettings(path, perPartArray, outlier, experimentName)
%
%   Writes a struct named `Settings` to a .mat file. Layout matches
%   `docs/superpowers/specs/2026-04-30-sphynx-preprocess-tab-design.md`.

    if nargin < 4; experimentName = ''; end

    Settings = struct();
    Settings.bodyparts = perPartArray;
    Settings.outlier = outlier;
    Settings.metadata.experimentName = experimentName;
    Settings.metadata.savedAt = datetime('now');
    Settings.metadata.dlcSchemaHash = schemaHash(perPartArray);

    save(path, 'Settings');
end

function h = schemaHash(arr)
    if isempty(arr); h = ''; return; end
    names = strjoin({arr.name}, '|');
    % Simple deterministic identifier — not crypto, but enough to detect
    % schema drift between sessions of the same experiment.
    h = sprintf('len%d:%s', numel(arr), names);
end

function writeTracksSettings(path, perPartArray, outlier, experimentName, individual)
% WRITETRACKSSETTINGS  Persist per-experiment preprocess settings.
%
%   sphynx.io.writeTracksSettings(path, perPartArray, outlier, ...
%       experimentName, individual)
%
%   Writes a struct named `Settings` to a .mat file. Layout matches
%   `docs/superpowers/specs/2026-04-30-sphynx-preprocess-tab-design.md`.
%
%   `individual` (optional, default '') records which multi-animal DLC
%   individual was used to derive these settings. analyzeSession reads
%   it back and forwards it to readDLC so every downstream session
%   processes the same animal consistently.

    if nargin < 4; experimentName = ''; end
    if nargin < 5; individual = ''; end

    Settings = struct();
    Settings.bodyparts = perPartArray;
    Settings.outlier = outlier;
    Settings.metadata.experimentName = experimentName;
    Settings.metadata.savedAt = datetime('now');
    Settings.metadata.dlcSchemaHash = schemaHash(perPartArray);
    Settings.metadata.individual = individual;

    save(path, 'Settings');
end

function h = schemaHash(arr)
    if isempty(arr); h = ''; return; end
    names = strjoin({arr.name}, '|');
    % Simple deterministic identifier — not crypto, but enough to detect
    % schema drift between sessions of the same experiment.
    h = sprintf('len%d:%s', numel(arr), names);
end

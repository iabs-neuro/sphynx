function Settings = readTracksSettings(path)
% READTRACKSSETTINGS  Load per-experiment preprocess settings.
%
%   Settings = sphynx.io.readTracksSettings(path)

    if ~isfile(path)
        error('sphynx:readTracksSettings:notFound', ...
            'Settings file not found: %s', path);
    end
    s = load(path, 'Settings');
    if ~isfield(s, 'Settings')
        error('sphynx:readTracksSettings:malformed', ...
            'File does not contain a Settings struct: %s', path);
    end
    Settings = s.Settings;
end

function acts = loadActsSet(path)
% LOADACTSSET  Read an acts library from a .mat file.

    if ~isfile(path)
        error('sphynx:loadActsSet:notFound', 'Not found: %s', path);
    end
    s = load(path, 'Settings');
    if ~isfield(s, 'Settings') || ~isfield(s.Settings, 'acts')
        error('sphynx:loadActsSet:malformed', ...
            'File does not contain Settings.acts: %s', path);
    end
    acts = s.Settings.acts;
end

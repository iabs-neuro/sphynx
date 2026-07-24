function saveActsSet(path, acts, expType)
% SAVEACTSSET  Persist an acts library to a .mat file.

    if nargin < 3; expType = ''; end
    Settings = struct();
    Settings.acts = acts;
    Settings.experimentType = expType;
    Settings.savedAt = datetime('now');
    save(path, 'Settings');
end

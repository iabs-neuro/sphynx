function add_session_prefix(rootDir, dryRun)
% ADD_SESSION_PREFIX  Prepend the session identifier (folder name) to
% every file inside 5_Behavior/<session>/** that does not already
% start with it.
%
%   add_session_prefix(rootDir, dryRun)
%       rootDir  - path that contains the 5_Behavior subfolder
%                  (default: c:\Users\User\YandexDisk\_Projects\WNOF\BehaviorData)
%       dryRun   - true (default): print the plan only
%                  false: perform the renames
%
% Files that already start with the session stem are skipped (e.g.
%   WNOF_A01_1D_main.mp4, WNOF_A01_1DDLC_..._WorkSpace.mat).
% Files in subfolders (Acts_video/, bodyparts_trajectory/) are also
% renamed.

    if nargin < 1 || isempty(rootDir)
        rootDir = 'c:\Users\User\YandexDisk\_Projects\WNOF\BehaviorData';
    end
    if nargin < 2; dryRun = true; end

    behaviorDir = fullfile(rootDir, '5_Behavior');
    if ~isfolder(behaviorDir)
        error('5_Behavior not found at: %s', behaviorDir);
    end

    if dryRun
        fprintf('=== DRY RUN ===   (use add_session_prefix(rootDir, false) to apply)\n\n');
    else
        fprintf('=== APPLY ===\n\n');
    end

    % Find session folders. Anything that is a directory directly under
    % 5_Behavior counts as a session. We skip files at the top level.
    listing = dir(behaviorDir);
    listing = listing([listing.isdir] & ~ismember({listing.name}, {'.', '..'}));
    fprintf('Found %d session folders in %s\n\n', numel(listing), behaviorDir);

    nFile = 0;
    nSkipped = 0;
    for k = 1:numel(listing)
        stem = listing(k).name;
        sessionDir = fullfile(behaviorDir, stem);
        files = dir(fullfile(sessionDir, '**', '*'));
        for j = 1:numel(files)
            if files(j).isdir; continue; end
            nm = files(j).name;
            if startsWith(nm, stem)
                nSkipped = nSkipped + 1;
                continue;
            end
            oldP = fullfile(files(j).folder, nm);
            newName = sprintf('%s_%s', stem, nm);
            newP = fullfile(files(j).folder, newName);
            fprintf('  %s\n        -> %s\n', oldP, newP);
            nFile = nFile + 1;
            if dryRun; continue; end
            [ok, msg] = movefile(oldP, newP);
            if ~ok
                warning('movefile FAILED: %s -> %s : %s', oldP, newP, msg);
            end
        end
    end

    fprintf('\nSummary: %d files to rename, %d already prefixed (skipped). dryRun=%d\n', ...
        nFile, nSkipped, dryRun);
end

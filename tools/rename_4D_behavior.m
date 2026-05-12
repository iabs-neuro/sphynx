function rename_4D_behavior(rootDir, dryRun)
% RENAME_4D_BEHAVIOR  Fix mis-labelled WNOF *_4D sessions inside 5_Behavior.
%
%   rename_4D_behavior(rootDir, dryRun)
%       rootDir  - path that contains the 5_Behavior subfolder
%                  (default: c:\Users\User\YandexDisk\_Projects\WNOF\BehaviorData)
%       dryRun   - true (default): only print what would be renamed
%                  false: actually perform the renames
%
% Renaming strategy when applying:
%   The wrong->correct map is a permutation (e.g. A02->A16 AND A16->A08),
%   so a naive single-pass rename would clobber. We rename via a temporary
%   prefix WNOF_TMP_A##_4D in two passes.
%
% Identity pairs (e.g. A01->A01) are skipped.
% After folder rename, the SessionName field inside *_WorkSpace.mat (if
% present) is updated to the new prefix.

    if nargin < 1 || isempty(rootDir)
        rootDir = 'c:\Users\User\YandexDisk\_Projects\WNOF\BehaviorData';
    end
    if nargin < 2; dryRun = true; end

    behaviorDir = fullfile(rootDir, '5_Behavior');
    if ~isfolder(behaviorDir)
        error('5_Behavior not found at: %s', behaviorDir);
    end

    map = wrongToCorrectMap();

    if dryRun
        fprintf('=== DRY RUN ===   (use rename_4D_behavior(rootDir, false) to apply)\n\n');
    else
        fprintf('=== APPLY ===\n\n');
    end

    % Collect folders present.
    wrongKeys = map.keys;
    sessions = struct('wrong', {}, 'correct', {}, 'srcPath', {});
    for k = 1:numel(wrongKeys)
        w = wrongKeys{k};
        c = map(w);
        p = fullfile(behaviorDir, sprintf('WNOF_%s_4D', w));
        if isfolder(p)
            sessions(end+1).wrong = w; %#ok<AGROW>
            sessions(end).correct = c;
            sessions(end).srcPath = p;
        end
    end
    fprintf('Found %d/30 wrong-named 4D folders in %s\n\n', ...
        numel(sessions), behaviorDir);
    if isempty(sessions); return; end

    % Build the unified plan: per-file moves AND per-folder moves AND per-mat updates.
    % Display this plan as the dry-run output.
    plan = buildPlan(sessions, behaviorDir);
    printPlan(plan);

    if dryRun; fprintf('\nDone. dryRun=1\n'); return; end

    % --- Apply: two-pass via WNOF_TMP_A##_4D ---
    applyPlan(sessions, behaviorDir);
    fprintf('\nDone. dryRun=0\n');
end

% =========================================================================

function plan = buildPlan(sessions, behaviorDir)
    plan = struct('src', {}, 'dst', {}, 'kind', {});
    for k = 1:numel(sessions)
        s = sessions(k);
        if strcmp(s.wrong, s.correct); continue; end  % skip identity
        srcPrefix = sprintf('WNOF_%s_4D', s.wrong);
        dstPrefix = sprintf('WNOF_%s_4D', s.correct);
        srcFolder = s.srcPath;
        dstFolder = fullfile(behaviorDir, dstPrefix);

        % Files inside (recursive)
        listing = dir(fullfile(srcFolder, '**', '*'));
        for j = 1:numel(listing)
            if listing(j).isdir; continue; end
            nm = listing(j).name;
            if ~startsWith(nm, srcPrefix); continue; end
            subPath = strrep(listing(j).folder, srcFolder, '');
            if ~isempty(subPath) && subPath(1) == filesep
                subPath = subPath(2:end);
            end
            srcFile = fullfile(listing(j).folder, nm);
            newNm   = [dstPrefix, nm(numel(srcPrefix)+1:end)];
            dstFile = fullfile(dstFolder, subPath, newNm);
            plan(end+1).src = srcFile; %#ok<AGROW>
            plan(end).dst   = dstFile;
            plan(end).kind  = '[file]  ';
        end

        % Folder itself
        plan(end+1).src = srcFolder; %#ok<AGROW>
        plan(end).dst   = dstFolder;
        plan(end).kind  = '[folder]';

        % SessionName update inside *_WorkSpace.mat (if it exists)
        matFiles = dir(fullfile(srcFolder, '*_WorkSpace.mat'));
        for j = 1:numel(matFiles)
            try
                info = whos('-file', fullfile(matFiles(j).folder, matFiles(j).name));
                if any(strcmp({info.name}, 'SessionName'))
                    plan(end+1).src = sprintf('SessionName field in %s', dstPrefix); %#ok<AGROW>
                    plan(end).dst   = dstPrefix;
                    plan(end).kind  = '[mat]   ';
                end
            catch
            end
        end
    end
end

function printPlan(plan)
    for k = 1:numel(plan)
        fprintf('  %s %s\n            -> %s\n', plan(k).kind, plan(k).src, plan(k).dst);
    end
    nFile = sum(strcmp({plan.kind}, '[file]  '));
    nFold = sum(strcmp({plan.kind}, '[folder]'));
    nMat  = sum(strcmp({plan.kind}, '[mat]   '));
    fprintf('\nSummary: %d files, %d folders, %d *.mat SessionName updates\n', ...
        nFile, nFold, nMat);
end

function applyPlan(sessions, behaviorDir)
    % Two-pass:
    %   Pass 1: WNOF_A##_4D     -> WNOF_TMP_A##_4D   (files + folder)
    %   Pass 2: WNOF_TMP_A##_4D -> WNOF_<correct>_4D (files + folder)
    %   Then : update SessionName inside *_WorkSpace.mat.

    todo = sessions(~strcmp({sessions.wrong}, {sessions.correct}));

    fprintf('--- Pass 1 ---\n');
    for k = 1:numel(todo)
        s = todo(k);
        srcPrefix = sprintf('WNOF_%s_4D',     s.wrong);
        tmpPrefix = sprintf('WNOF_TMP_%s_4D', s.wrong);
        renameSessionFiles(s.srcPath, srcPrefix, tmpPrefix);
        tmpFolder = fullfile(behaviorDir, tmpPrefix);
        renameOne(s.srcPath, tmpFolder, '[folder]');
        todo(k).tmpPath = tmpFolder;
    end

    fprintf('--- Pass 2 ---\n');
    for k = 1:numel(todo)
        s = todo(k);
        tmpPrefix = sprintf('WNOF_TMP_%s_4D', s.wrong);
        dstPrefix = sprintf('WNOF_%s_4D',     s.correct);
        renameSessionFiles(s.tmpPath, tmpPrefix, dstPrefix);
        dstFolder = fullfile(behaviorDir, dstPrefix);
        renameOne(s.tmpPath, dstFolder, '[folder]');
        updateSessionNameInMat(dstFolder, dstPrefix);
    end
end

function renameSessionFiles(folderPath, srcPrefix, dstPrefix)
    if ~isfolder(folderPath); return; end
    listing = dir(fullfile(folderPath, '**', '*'));
    for k = 1:numel(listing)
        if listing(k).isdir; continue; end
        nm = listing(k).name;
        if ~startsWith(nm, srcPrefix); continue; end
        oldP = fullfile(listing(k).folder, nm);
        newName = [dstPrefix, nm(numel(srcPrefix)+1:end)];
        newP = fullfile(listing(k).folder, newName);
        renameOne(oldP, newP, '[file]  ');
    end
end

function renameOne(src, dst, tag)
    fprintf('  %s %s\n            -> %s\n', tag, src, dst);
    if strcmpi(src, dst); return; end
    [ok, msg] = movefile(src, dst);
    if ~ok
        warning('movefile FAILED: %s -> %s : %s', src, dst, msg);
    end
end

function updateSessionNameInMat(folderPath, correctPrefix)
    matFiles = dir(fullfile(folderPath, '*_WorkSpace.mat'));
    for k = 1:numel(matFiles)
        p = fullfile(matFiles(k).folder, matFiles(k).name);
        try
            info = whos('-file', p);
        catch
            continue;
        end
        if ~any(strcmp({info.name}, 'SessionName')); continue; end
        try
            S = load(p);
            S.SessionName = correctPrefix; %#ok<STRNU>
            save(p, '-struct', 'S');
            fprintf('  [mat]    %s : set SessionName=%s\n', p, correctPrefix);
        catch ME
            warning('Failed to update SessionName in %s: %s', p, ME.message);
        end
    end
end

function m = wrongToCorrectMap()
    pairs = { ...
        'A01', 'A01'; ...
        'A02', 'A16'; ...
        'A03', 'A02'; ...
        'A04', 'A30'; ...
        'A05', 'A03'; ...
        'A06', 'A17'; ...
        'A07', 'A19'; ...
        'A08', 'A04'; ...
        'A09', 'A18'; ...
        'A10', 'A05'; ...
        'A11', 'A22'; ...
        'A12', 'A06'; ...
        'A13', 'A21'; ...
        'A14', 'A07'; ...
        'A15', 'A23'; ...
        'A16', 'A08'; ...
        'A17', 'A09'; ...
        'A18', 'A20'; ...
        'A19', 'A10'; ...
        'A20', 'A24'; ...
        'A21', 'A11'; ...
        'A22', 'A12'; ...
        'A23', 'A25'; ...
        'A24', 'A27'; ...
        'A25', 'A26'; ...
        'A26', 'A28'; ...
        'A27', 'A29'; ...
        'A28', 'A13'; ...
        'A29', 'A14'; ...
        'A30', 'A15'};
    wrongs   = pairs(:, 1);
    corrects = pairs(:, 2);
    if numel(unique(wrongs)) ~= 30 || numel(unique(corrects)) ~= 30
        error('rename_4D_behavior:badMap', ...
            'Map must contain 30 unique wrong and 30 unique correct names');
    end
    m = containers.Map(wrongs, corrects);
end

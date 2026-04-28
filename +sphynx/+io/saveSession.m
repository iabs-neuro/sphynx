function saveSession(result, outDir, sessionName)
% SAVESESSION  Save analyzeSession result to <outDir>/<sessionName>_WorkSpace.mat.
%
%   sphynx.io.saveSession(result, outDir, sessionName) writes a single
%   .mat file containing the result struct from analyzeSession. Replaces
%   the legacy 9-place save() pattern in BehaviorAnalyzer.m.
%
%   Creates outDir if missing.

    if ~isfolder(outDir)
        mkdir(outDir);
    end
    outPath = fullfile(outDir, sprintf('%s_WorkSpace.mat', sessionName));
    save(outPath, '-struct', 'result');
    sphynx.util.log('info', 'Saved session to %s', outPath);
end

function diagnose_ts_error(csvPath)
% DIAGNOSE_TS_ERROR  Diagnose "real-valued vector of type double" -
% style failures in sgolay/Hampel preprocessing.
%
%   diagnose_ts_error()              -- prompts for a DLC csv
%   diagnose_ts_error('path.csv')    -- uses the given csv
%
% Designed to be safe for non-MATLAB users: prints PASS/FAIL lines
% for every check + a single VERDICT line at the end. Copy the
% whole output into a chat / email to share.
%
% Place the file in the repo root or anywhere on path, then in
% the MATLAB Command Window:
%
%     >> startup
%     >> diagnose_ts_error('C:/path/to/your.csv')

    fprintf('================================================\n');
    fprintf('  sphynx -- TS error diagnostic\n');
    fprintf('================================================\n');

    % --- 1. MATLAB + toolbox audit -------------------------------------
    fprintf('\n[1] MATLAB build\n');
    fprintf('    version  : %s\n', version);
    fprintf('    arch     : %s\n', computer);
    fprintf('    locale   : %s\n', getenv('LANG'));
    decSep = sprintf('%g', 0.5);
    fprintf('    sprintf %%g 0.5 -> "%s"   (expect "0.5"; "0,5" = RU locale active)\n', decSep);
    haveSP = license('test', 'signal_toolbox');
    haveCV = license('test', 'computer_vision');
    fprintf('    Signal Processing Toolbox : %d (need 1 for sgolayfilt/hampel)\n', haveSP);
    fprintf('    Computer Vision Toolbox   : %d (optional)\n', haveCV);

    % --- 2. Verify the readDLC fix is present --------------------------
    fprintf('\n[2] readDLC has DecimalSeparator fix\n');
    [reFix, reFixWhy] = checkReadDLCFix();
    if reFix
        fprintf('    PASS -- "DecimalSeparator" found in readDLC.m\n');
    else
        fprintf('    FAIL -- %s\n', reFixWhy);
        fprintf('    FIX  -- pull the latest sphynx-GUI branch; commit c4edd31\n');
        fprintf('            added this. If the line is missing, the locale\n');
        fprintf('            fix never landed on this machine.\n');
    end

    % --- 3. Read the user's csv ----------------------------------------
    if nargin < 1 || isempty(csvPath)
        [f, p] = uigetfile({'*.csv'}, 'Pick the DLC csv that crashes');
        if isequal(f, 0); fprintf('\nNo csv picked, aborting.\n'); return; end
        csvPath = fullfile(p, f);
    end
    fprintf('\n[3] Read DLC: %s\n', csvPath);
    if ~isfile(csvPath)
        fprintf('    FAIL -- file does not exist\n'); return;
    end
    try
        d = sphynx.io.readDLC(csvPath);
    catch ME
        fprintf('    FAIL during readDLC: %s\n', ME.message);
        return;
    end
    fprintf('    nFrames = %d, nParts = %d\n', d.nFrames, numel(d.bodyPartsNames));
    fprintf('    class(X)    = %s   (expect "double")\n', class(d.X));
    fprintf('    class(Y)    = %s\n', class(d.Y));
    fprintf('    class(L)    = %s\n', class(d.likelihood));
    fprintf('    NaN-only X  = %d   (1 = bad: parsing produced NaN-only)\n', all(isnan(d.X(:))));
    fprintf('    NaN-only L  = %d\n', all(isnan(d.likelihood(:))));
    if isfield(d, 'selectedIndividual')
        fprintf('    multianimal -> selected "%s" (of %d)\n', ...
            d.selectedIndividual, numel(d.individuals));
    end

    % --- 4. Sample finite values from the first body part --------------
    fprintf('\n[4] First body part sample\n');
    rawX = d.X(1, :)'; rawY = d.Y(1, :)'; rawL = d.likelihood(1, :)';
    finiteN = sum(isfinite(rawX));
    fprintf('    part = %s\n', d.bodyPartsNames{1});
    fprintf('    finite frames = %d / %d\n', finiteN, d.nFrames);
    if finiteN < 30
        fprintf('    FAIL -- too few finite points (need >=30 to test smoothing)\n');
        return;
    end
    sampleX = rawX(isfinite(rawX));
    fprintf('    X sample first 3 = %g %g %g\n', sampleX(1), sampleX(2), sampleX(3));
    fprintf('    class(sample)    = %s\n', class(sampleX));

    % --- 5. Try sgolayfilt on the sample -------------------------------
    fprintf('\n[5] sgolayfilt sanity\n');
    try
        sg = sgolayfilt(double(sampleX), 3, 11);   % cast to double explicitly
        fprintf('    PASS -- sgolayfilt(double(x), 3, 11) returned %d samples\n', numel(sg));
    catch ME
        fprintf('    FAIL -- sgolayfilt: %s\n', ME.message);
    end
    try
        sg = sgolayfilt(single(sampleX), 3, 11);
        fprintf('    PASS -- sgolayfilt(single(x), 3, 11) accepted single\n');
    catch ME
        fprintf('    INFO -- sgolayfilt(single(x), ...) rejected: %s\n', ME.message);
        fprintf('            (this is the most common cause -- the code now\n');
        fprintf('             casts to double up front; this confirms why.)\n');
    end

    % --- 6. Try hampel on the sample -----------------------------------
    fprintf('\n[6] hampel sanity\n');
    try
        [~, oi] = hampel(double(sampleX), 7, 3);
        fprintf('    PASS -- hampel(double(x), 7, 3) flagged %d outliers\n', sum(oi));
    catch ME
        fprintf('    FAIL -- hampel: %s\n', ME.message);
    end

    % --- 7. Full sphynx smoothing pipeline -----------------------------
    fprintf('\n[7] sphynx.preprocess.smoothTrace + computeVelocity\n');
    try
        smX = sphynx.preprocess.smoothTrace(rawX, 11);
        fprintf('    PASS -- smoothTrace returned %d samples (class %s)\n', ...
            numel(smX), class(smX));
    catch ME
        fprintf('    FAIL -- smoothTrace: %s\n', ME.message);
        fprintf('    NOTE -- the latest sphynx-GUI hardens smoothTrace to\n');
        fprintf('            cast input to double and fill interior NaNs.\n');
        fprintf('            If you still see a sgolay error here, this\n');
        fprintf('            machine is on an older sphynx-GUI checkout.\n');
    end

    % --- 8. Code commit on this machine --------------------------------
    fprintf('\n[8] sphynx code version\n');
    try
        repoRoot = fileparts(which('sphynx.io.readDLC'));
        repoRoot = strrep(repoRoot, fullfile('+sphynx', '+io'), '');
        [~, sha] = system(sprintf('git -C "%s" rev-parse --short HEAD', repoRoot));
        sha = strtrim(sha);
        fprintf('    repo: %s\n', repoRoot);
        fprintf('    HEAD: %s\n', sha);
        [~, hist] = system(sprintf('git -C "%s" log --oneline -5 -- +sphynx/+io/readDLC.m +sphynx/+preprocess/smoothTrace.m +sphynx/+preprocess/hampelFilter.m', repoRoot));
        fprintf('    recent commits touching readDLC/smoothTrace/hampelFilter:\n%s', hist);
    catch ME
        fprintf('    INFO -- git probe failed: %s\n', ME.message);
    end

    fprintf('\n================================================\n');
    fprintf('  Diagnostic done. Send the full output above.\n');
    fprintf('================================================\n');
end

function [ok, why] = checkReadDLCFix()
    ok = false; why = 'readDLC.m not on the path';
    p = which('sphynx.io.readDLC');
    if isempty(p); return; end
    txt = fileread(p);
    if contains(txt, 'DecimalSeparator')
        ok = true; why = '';
    else
        why = sprintf('readDLC.m at %s does NOT contain "DecimalSeparator"', p);
    end
end

function results = runAllTests(varargin)
% RUNALLTESTS  Run the sphynx test suite.
%
%   results = runAllTests()                runs everything (== 'all')
%   results = runAllTests('tag','fast')    runs unit + synthetic + smoke
%   results = runAllTests('tag','full')    runs unit + synthetic + smoke + golden
%   results = runAllTests('tag','golden')  runs golden only
%
%   Sets SPHYNX_HEADLESS=1 for the duration so tests don't open windows.
%
%   Run from MATLAB Command Window with the repo root as cwd:
%     >> startup
%     >> cd tests
%     >> runAllTests('tag','fast')

    p = inputParser;
    addParameter(p, 'tag', 'all', @ischar);
    parse(p, varargin{:});
    tag = p.Results.tag;

    here = fileparts(mfilename('fullpath')); % /<repo>/tests

    switch tag
        case 'fast'
            buckets = {'unit', 'synthetic', 'smoke'};
        case 'full'
            buckets = {'unit', 'synthetic', 'smoke', 'golden'};
        case 'golden'
            buckets = {'golden'};
        case 'all'
            buckets = {'unit', 'synthetic', 'smoke', 'golden'};
        otherwise
            error('runAllTests:unknownTag', ...
                'Unknown tag "%s"; valid: fast|full|golden|all', tag);
    end

    % Force headless so no windows pop up
    prevHeadless = getenv('SPHYNX_HEADLESS');
    setenv('SPHYNX_HEADLESS', '1');
    cleaner = onCleanup(@() setenv('SPHYNX_HEADLESS', prevHeadless));

    import matlab.unittest.TestSuite;
    % matlab.unittest.TestSuite is abstract; concrete tests are
    % matlab.unittest.Test arrays returned by fromFolder/fromClass/etc.
    suite = matlab.unittest.Test.empty;
    for i = 1:numel(buckets)
        bucketDir = fullfile(here, buckets{i});
        if isfolder(bucketDir)
            sub = TestSuite.fromFolder(bucketDir, 'IncludingSubfolders', true);
            suite = [suite, sub]; %#ok<AGROW>
        end
    end

    if isempty(suite)
        warning('runAllTests:emptySuite', ...
            'No tests found for tag "%s" in %s', tag, here);
        results = matlab.unittest.TestResult.empty;
        return;
    end

    fprintf('Running %d tests (tag=%s)\n', numel(suite), tag);
    results = run(suite);

    % Print summary
    nFailed = sum([results.Failed]);
    nIncomplete = sum([results.Incomplete]);
    fprintf('\n=== Summary ===\nTotal:   %d\nPassed:  %d\nFailed:  %d\nSkipped: %d\n', ...
        numel(results), sum([results.Passed]), nFailed, nIncomplete);

    if nFailed > 0 || nIncomplete > 0
        warning('runAllTests:someFailed', '%d failed, %d incomplete', nFailed, nIncomplete);
    end
end

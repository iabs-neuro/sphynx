function tests = makeSyntheticDLCOutlierParamsTest
% MAKESYNTHETICDLCOUTLIERPARAMSTEST  R31 audit #7 and #8.
%   #7: 'mixed' outlier mode must NOT globally overwrite likelihood --
%       the spike/gap low-likelihood signatures have to survive.
%   #8: GapCountPerPart=0 must inject ZERO gaps (no max(1,...) floor).
    tests = functiontests(localfunctions);
end

function testMixedModePreservesGapSignatures(testCase)
    % In 'mixed' mode the long_gap stage writes runs of low likelihood
    % (~0.05-0.15). Pre-fix, the poor_likelihood stage reassigned the
    % whole matrix to ~0.55, wiping those. So a healthy fraction of cells
    % must remain clearly below the 0.55 poor-likelihood floor.
    out = sphynx.preprocess.makeSyntheticDLC( ...
        'OutlierMode', 'mixed', 'NFrames', 1000, 'Seed', 1);
    L = out.likelihood;
    verifyGreaterThan(testCase, mean(L(:) < 0.2), 0.01);
end

function testGapCountZeroInjectsNoGaps(testCase)
    % unimodal_high base likelihood is ~0.99 everywhere. With
    % GapCountPerPart=0 and long_gap mode, no gap must be injected, so
    % the minimum likelihood stays high. Pre-fix, max(1,0)=1 forced one
    % gap per part, dropping the min into the ~0.05-0.15 gap band.
    out = sphynx.preprocess.makeSyntheticDLC( ...
        'OutlierMode', 'long_gap', 'GapCountPerPart', 0, ...
        'LikelihoodModel', 'unimodal_high', 'NFrames', 500, 'Seed', 1);
    verifyGreaterThan(testCase, min(out.likelihood(:)), 0.5);
end

function tests = marqueeSelectTest
    tests = functiontests(localfunctions);
end

function testEmptyRectReturnsEmpty(testCase)
    cents = [10 10; 20 20; 30 30];
    idx = sphynx.preset.marqueeSelect(cents, []);
    verifyEqual(testCase, idx, []);
end

function testInsideRectSelected(testCase)
    cents = [10 10; 50 50; 20 80];
    rect = [0 0 40 40];   % [x y w h]
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, 1);  % only (10,10) is in [0..40,0..40]
end

function testEdgeIsInclusive(testCase)
    cents = [40 40];
    rect = [0 0 40 40];
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, 1);
end

function testMultipleInside(testCase)
    cents = [5 5; 10 10; 15 15; 100 100];
    rect = [0 0 20 20];
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, [1; 2; 3]);
end

function testNoMatchReturnsEmpty(testCase)
    % I5: All centroids strictly outside the rect -> empty result (col vector).
    cents = [100 100; 200 200; 300 300];
    rect = [0 0 10 10];
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, zeros(0, 1));
end

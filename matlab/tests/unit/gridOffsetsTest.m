function tests = gridOffsetsTest
    tests = functiontests(localfunctions);
end

function testRowLayoutForSmallN(testCase)
    % N=3 -> 3 copies in a row, step 30 -> offsets (30,0),(60,0),(90,0)
    offsets = sphynx.preset.gridOffsets(3, 30);
    verifyEqual(testCase, offsets, [30 0; 60 0; 90 0]);
end

function testGridLayoutForLargeN(testCase)
    % N=7, step 30 -> 5 cols, 2 rows
    % row 1: (30,0),(60,0),(90,0),(120,0),(150,0)
    % row 2: (30,30),(60,30)
    offsets = sphynx.preset.gridOffsets(7, 30);
    verifyEqual(testCase, offsets, ...
        [30 0; 60 0; 90 0; 120 0; 150 0; 30 30; 60 30]);
end

function testZeroN(testCase)
    offsets = sphynx.preset.gridOffsets(0, 30);
    verifyEqual(testCase, size(offsets, 1), 0);
end

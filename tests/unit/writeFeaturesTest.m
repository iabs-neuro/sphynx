function tests = writeFeaturesTest
% WRITEFEATURESTEST  Per-frame features table: legacy columns, cm units,
% locomotion masking and NaN kinematics during the act 'outside'.
    tests = functiontests(localfunctions);
end

function setup(testCase)
    testCase.TestData.dir = tempname;
    mkdir(testCase.TestData.dir);
end

function teardown(testCase)
    rmdir(testCase.TestData.dir, 's');
end

function r = fakeResult()
    n = 10;
    names = {'nose', 'headcenter', 'tailbase', 'bodycenter'};
    xs = {(1:n) + 20, (1:n) + 10, (1:n), (1:n) + 5};
    for i = 1:numel(names)
        bp(i).BodyPartName = names{i}; %#ok<AGROW>
        bp(i).TraceSmoothed.X = xs{i};
        bp(i).TraceSmoothed.Y = 100 * ones(1, n);
        bp(i).VelocitySmoothed = 3 * ones(1, n);
    end
    r.BodyPartsTraces = bp;
    r.Point = sphynx.bodyparts.identifyParts(names);
    r.Options.pxl2sm = 2;
    r.Options.FrameRate = 5;
    r.n_frames = n;
    loc = zeros(1, n); loc(3:5) = 1;
    out = zeros(1, n); out(8:9) = 1;
    r.Acts = struct('ActName', {'locomotion', 'outside'}, 'ActArrayRefine', {loc, out});
end

function testColumnsAndValues(testCase)
    p = sphynx.io.writeFeatures(fakeResult(), testCase.TestData.dir, 'EXP_M01_1D');
    verifyTrue(testCase, endsWith(p, 'EXP_M01_1D_Features.csv'));
    T = readtable(p);
    verifyEqual(testCase, T.Properties.VariableNames, {'x', 'y', 'x_locomotion', ...
        'y_locomotion', 'speed', 'bodydirection', 'headdirection', 'locomotion', 'outside'});
    verifyEqual(testCase, height(T), 10);
    verifyEqual(testCase, T.x(1), 3, 'AbsTol', 1e-12);      % (1 + 5) px / 2 px per cm
    verifyEqual(testCase, T.y(1), 50, 'AbsTol', 1e-12);
    verifyEqual(testCase, T.x_locomotion(4), T.x(4));
    verifyTrue(testCase, isnan(T.x_locomotion(1)));
    verifyEqual(testCase, T.bodydirection(1), 0, 'AbsTol', 1e-12);   % tail -> centre along +x
    verifyEqual(testCase, T.headdirection(1), 0, 'AbsTol', 1e-9);
end

function testOutsideFramesHaveNoKinematics(testCase)
    T = readtable(sphynx.io.writeFeatures(fakeResult(), testCase.TestData.dir, 'S'));
    verifyTrue(testCase, all(isnan(T.x(8:9))) && all(isnan(T.speed(8:9))));
    verifyTrue(testCase, all(isnan(T.headdirection(8:9))));
    verifyEqual(testCase, T.outside(8:9), [1; 1]);
    verifyFalse(testCase, any(isnan(T.x([1:7 10]))));
end

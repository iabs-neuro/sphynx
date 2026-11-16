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

function r = withEars(r, headAngle)
    % Ears 1 px either side of the head, perpendicular to headAngle (image coords, y down):
    % the left ear of a mouse facing angle a sits at a - 90 deg.
    n = r.n_frames;
    a = headAngle(:)';
    r.BodyPartsTraces(end+1).BodyPartName = 'leftear';
    r.BodyPartsTraces(end).TraceSmoothed.X = 50 + cos(a - pi/2);
    r.BodyPartsTraces(end).TraceSmoothed.Y = 50 + sin(a - pi/2);
    r.BodyPartsTraces(end).VelocitySmoothed = zeros(1, n);
    r.BodyPartsTraces(end+1).BodyPartName = 'rightear';
    r.BodyPartsTraces(end).TraceSmoothed.X = 50 + cos(a + pi/2);
    r.BodyPartsTraces(end).TraceSmoothed.Y = 50 + sin(a + pi/2);
    r.BodyPartsTraces(end).VelocitySmoothed = zeros(1, n);
    r.Point = sphynx.bodyparts.identifyParts({r.BodyPartsTraces.BodyPartName});
end

function testHeadDirectionFromEarLine(testCase)
    r = fakeResult();
    r.Acts(2).ActArrayRefine(:) = 0;     % no 'outside' frames
    r = withEars(r, repmat(pi/2, 1, r.n_frames));   % facing +y (down on screen)
    T = readtable(sphynx.io.writeFeatures(r, testCase.TestData.dir, 'E'));
    verifyEqual(testCase, T.headdirection, repmat(pi/2, 10, 1), 'AbsTol', 1e-9);
end

function testHeadDirectionCrossesPiWithoutArtifacts(testCase)
    % A head turning steadily through +-pi: after smoothing, the angle must
    % stay on the true trajectory (no excursion towards 0 at the wrap).
    r = fakeResult();
    n = 61;
    for i = 1:numel(r.BodyPartsTraces)
        r.BodyPartsTraces(i).TraceSmoothed.X = 1:n;
        r.BodyPartsTraces(i).TraceSmoothed.Y = ones(1, n);
        r.BodyPartsTraces(i).VelocitySmoothed = ones(1, n);
    end
    r.n_frames = n;
    r.Acts = struct('ActName', {'locomotion'}, 'ActArrayRefine', {zeros(1, n)});
    truth = linspace(pi - 1, pi + 1, n);
    r = withEars(r, truth);
    T = readtable(sphynx.io.writeFeatures(r, testCase.TestData.dir, 'W'));
    err = angle(exp(1i * (T.headdirection - truth(:))));
    verifyLessThan(testCase, max(abs(err)), 1e-6);
    verifyTrue(testCase, all(T.headdirection > -pi & T.headdirection <= pi));
end

function testOutsideFramesHaveNoKinematics(testCase)
    T = readtable(sphynx.io.writeFeatures(fakeResult(), testCase.TestData.dir, 'S'));
    verifyTrue(testCase, all(isnan(T.x(8:9))) && all(isnan(T.speed(8:9))));
    verifyTrue(testCase, all(isnan(T.headdirection(8:9))));
    verifyEqual(testCase, T.outside(8:9), [1; 1]);
    verifyFalse(testCase, any(isnan(T.x([1:7 10]))));
end

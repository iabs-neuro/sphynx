function tests = smoothTraceTest
    tests = functiontests(localfunctions);
end

function testConstantSignalStaysConstantIncludingEdges(testCase)
    in = ones(100, 1) * 5.7;
    out = sphynx.preprocess.smoothTrace(in, 11);
    verifyEqual(testCase, out, in, 'AbsTol', 1e-9, ...
        'Bug-3: edges of constant signal must remain constant');
end

function testLinearTrendPreserved(testCase)
    in = (1:100)' * 0.1;
    out = sphynx.preprocess.smoothTrace(in, 11);
    verifyEqual(testCase, out, in, 'AbsTol', 0.05);
end

function testReducesGaussianNoise(testCase)
    rng(42);
    in = randn(200, 1);
    out = sphynx.preprocess.smoothTrace(in, 21);
    verifyLessThan(testCase, std(out), 0.5 * std(in));
end

function testWindowLengthValidation(testCase)
    in = ones(50, 1);
    verifyError(testCase, @() sphynx.preprocess.smoothTrace(in, 4), ...
        'sphynx:smoothTrace:windowEven');
    verifyError(testCase, @() sphynx.preprocess.smoothTrace(in, 1), ...
        'sphynx:smoothTrace:windowTooSmall');
end

function testTraceShorterThanWindowReturnsInput(testCase)
    in = (1:5)';
    out = sphynx.preprocess.smoothTrace(in, 11);
    verifyEqual(testCase, out, in);
end

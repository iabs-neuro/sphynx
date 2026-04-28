function tests = speedActsTest
    tests = functiontests(localfunctions);
end

function testStationaryAllRest(testCase)
    v = zeros(100, 1);
    out = sphynx.acts.speedActs(v, 1, 5, 5);
    verifyTrue(testCase, all(out.rest));
    verifyFalse(testCase, any(out.walk));
    verifyFalse(testCase, any(out.locomotion));
end

function testFastAllLocomotion(testCase)
    v = ones(100, 1) * 20;
    out = sphynx.acts.speedActs(v, 1, 5, 5);
    verifyTrue(testCase, all(out.locomotion));
end

function testMidSpeedAllWalk(testCase)
    v = ones(100, 1) * 3;
    out = sphynx.acts.speedActs(v, 1, 5, 5);
    verifyTrue(testCase, all(out.walk));
end

function testPartitionInvariant(testCase)
    rng(0);
    v = abs(randn(200, 1)) * 5;
    out = sphynx.acts.speedActs(v, 1, 5, 5);
    verifyEqual(testCase, sum(out.rest) + sum(out.walk) + sum(out.locomotion), 200);
end

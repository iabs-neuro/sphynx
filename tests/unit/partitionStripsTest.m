function tests = partitionStripsTest
    tests = functiontests(localfunctions);
end

function testThreeHorizontalStrips(testCase)
    arenaMask = false(30, 60);
    arenaMask(:, :) = true;
    zones = sphynx.zones.partitionStrips(arenaMask, 3, 'horizontal');
    verifyEqual(testCase, numel(zones), 3);
    verifyEqual(testCase, zones(1).name, 'strip1');
    for i = 1:3
        verifyGreaterThan(testCase, sum(zones(i).maskfilled(:)), 30*60/3 - 60);
        verifyLessThan(testCase, sum(zones(i).maskfilled(:)), 30*60/3 + 60);
    end
end

function testTwoVerticalStrips(testCase)
    arenaMask = false(20, 40);
    arenaMask(:, :) = true;
    zones = sphynx.zones.partitionStrips(arenaMask, 2, 'vertical');
    verifyEqual(testCase, numel(zones), 2);
    verifyTrue(testCase, zones(1).maskfilled(10, 5));
    verifyFalse(testCase, zones(1).maskfilled(10, 35));
    verifyTrue(testCase, zones(2).maskfilled(10, 35));
    verifyFalse(testCase, zones(2).maskfilled(10, 5));
end

function testRejectsZeroStrips(testCase)
    arenaMask = true(10, 10);
    verifyError(testCase, @() sphynx.zones.partitionStrips(arenaMask, 0, 'horizontal'), ...
        'sphynx:partitionStrips:invalidN');
end

function testRejectsUnknownDirection(testCase)
    arenaMask = true(10, 10);
    verifyError(testCase, @() sphynx.zones.partitionStrips(arenaMask, 3, 'diagonal'), ...
        'sphynx:partitionStrips:unknownDirection');
end

function testStripsArePartitionOfArena(testCase)
    arenaMask = false(20, 30);
    arenaMask(5:15, 5:25) = true;
    zones = sphynx.zones.partitionStrips(arenaMask, 4, 'horizontal');
    summed = false(20, 30);
    for i = 1:4
        verifyFalse(testCase, any(summed(:) & zones(i).maskfilled(:)));
        summed = summed | zones(i).maskfilled;
    end
    verifyEqual(testCase, summed, arenaMask);
end

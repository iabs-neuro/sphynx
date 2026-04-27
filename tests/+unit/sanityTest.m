function tests = sanityTest
    tests = functiontests(localfunctions);
end

function testFrameworkLoaded(testCase)
    verifyTrue(testCase, true, 'matlab.unittest is working');
end

function testRepoRootResolves(testCase)
    root = sphynx.util.repoRoot();
    verifyTrue(testCase, isfolder(root));
    verifyTrue(testCase, isfile(fullfile(root, 'README.md')));
end

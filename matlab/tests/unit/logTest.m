function tests = logTest
    tests = functiontests(localfunctions);
end

function testInfoEmitsAtInfoLevel(testCase)
    out = evalc('sphynx.util.log(''info'', ''hello %s'', ''world'');');
    verifyTrue(testCase, contains(out, 'hello world'));
    verifyTrue(testCase, contains(out, 'INFO'));
end

function testDebugSilentByDefault(testCase)
    out = evalc('sphynx.util.log(''debug'', ''secret'');');
    verifyEqual(testCase, out, '');
end

function testDebugEmitsWhenEnabled(testCase)
    setenv('SPHYNX_LOG_LEVEL', 'debug');
    cleaner = onCleanup(@() setenv('SPHYNX_LOG_LEVEL', ''));
    out = evalc('sphynx.util.log(''debug'', ''secret'');');
    verifyTrue(testCase, contains(out, 'secret'));
    verifyTrue(testCase, contains(out, 'DEBUG'));
end

function testWarnAlwaysEmits(testCase)
    out = evalc('sphynx.util.log(''warn'', ''attention'');');
    verifyTrue(testCase, contains(out, 'attention'));
    verifyTrue(testCase, contains(out, 'WARN'));
end

function testUnknownLevelErrors(testCase)
    verifyError(testCase, @() sphynx.util.log('shout', 'x'), ...
        'sphynx:log:unknownLevel');
end

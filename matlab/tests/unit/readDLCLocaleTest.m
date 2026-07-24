function tests = readDLCLocaleTest
    tests = functiontests(localfunctions);
end

function testReadsDotDecimalsCleanly(testCase)
    % Round-trip a small synthetic DLC CSV with '.' decimals; assert
    % no NaN in the data and that the parsed numbers match the source.
    csv = makeTempDlcCsv();
    cleaner = onCleanup(@() delete(csv)); %#ok<NASGU>

    out = sphynx.io.readDLC(csv);

    verifyEqual(testCase, out.nFrames, 5);
    verifyEqual(testCase, numel(out.bodyPartsNames), 2);
    verifyFalse(testCase, any(isnan(out.X(:))), ...
        'X has NaN -- likely DecimalSeparator misparse on this locale');
    verifyFalse(testCase, any(isnan(out.Y(:))), ...
        'Y has NaN -- likely DecimalSeparator misparse on this locale');
    % Spot-check exact values
    verifyEqual(testCase, out.X(1, 1), 100.5,  'AbsTol', 1e-6);
    verifyEqual(testCase, out.Y(1, 1), 200.25, 'AbsTol', 1e-6);
    verifyEqual(testCase, out.likelihood(1, 1), 0.987, 'AbsTol', 1e-6);
end

function testStillCleanUnderRuLocale(testCase)
    % Switch the JVM default locale to RU before parsing. readmatrix
    % consults the host locale to decide which character is the
    % thousands separator unless DecimalSeparator is forced. This test
    % proves the fix at readDLC.m:59 -- forcing '.' -- holds even
    % when the host locale would otherwise misparse.

    origLocale = java.util.Locale.getDefault();
    cleanerLoc = onCleanup(@() java.util.Locale.setDefault(origLocale)); %#ok<NASGU>
    java.util.Locale.setDefault(java.util.Locale('ru', 'RU'));

    csv = makeTempDlcCsv();
    cleanerFile = onCleanup(@() delete(csv)); %#ok<NASGU>

    out = sphynx.io.readDLC(csv);

    verifyFalse(testCase, any(isnan(out.X(:))), ...
        'X has NaN under RU locale -- fix at readDLC.m:59 was bypassed');
    verifyFalse(testCase, any(isnan(out.Y(:))), ...
        'Y has NaN under RU locale -- fix at readDLC.m:59 was bypassed');
    verifyEqual(testCase, out.X(1, 1),         100.5,  'AbsTol', 1e-6);
    verifyEqual(testCase, out.Y(1, 1),         200.25, 'AbsTol', 1e-6);
    verifyEqual(testCase, out.likelihood(1, 1), 0.987, 'AbsTol', 1e-6);
end

function csv = makeTempDlcCsv()
    csv = [tempname, '.csv'];
    fid = fopen(csv, 'w');
    assert(fid >= 0, 'Could not create temp file: %s', csv);
    fprintf(fid, 'scorer,DLC,DLC,DLC,DLC,DLC,DLC\n');
    fprintf(fid, 'bodyparts,nose,nose,nose,tail,tail,tail\n');
    fprintf(fid, 'coords,x,y,likelihood,x,y,likelihood\n');
    rows = [
        0, 100.5,  200.25, 0.987, 110.1, 210.7, 0.93;
        1, 101.2,  201.05, 0.991, 110.9, 211.2, 0.94;
        2, 102.05, 202.3,  0.988, 111.0, 212.8, 0.95;
        3, 102.9,  203.45, 0.985, 112.5, 213.0, 0.92;
        4, 103.7,  204.15, 0.989, 113.1, 214.6, 0.91;
    ];
    for r = 1:size(rows, 1)
        fprintf(fid, '%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', rows(r, :));
    end
    fclose(fid);
end

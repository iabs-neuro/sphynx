function tests = readDLCMultiAnimalTest
    tests = functiontests(localfunctions);
end

function testStfpRealFile(testCase)
    % Real 'el.csv' export (Stfp): individuals = observer / demonstrator /
    % single. Expect: detected as multi-animal, only true animals
    % (observer, demonstrator) compete; 'single' (1 bp) excluded.
    csv = fullfile(projectRoot(), 'Demo', 'DLC', ...
        'Stfp 1 D5 T2 1-14-1DLC_resnet50_STFP_2T_1GJun13shuffle1_100000_el.csv');
    assumeTrue(testCase, isfile(csv), 'Sample CSV not present');
    out = sphynx.io.readDLC(csv);
    verifyTrue(testCase, isfield(out, 'individuals'));
    verifyTrue(testCase, any(strcmp(out.individuals, 'observer')));
    verifyTrue(testCase, any(strcmp(out.individuals, 'demonstrator')));
    verifyTrue(testCase, any(strcmp(out.individuals, 'single')));
    % Selected must be one of the two true animals, not 'single' (1 bp).
    verifyTrue(testCase, ismember(out.selectedIndividual, ...
        {'observer', 'demonstrator'}));
    % Picked individual has the full body-part set (11 parts in this file).
    verifyEqual(testCase, numel(out.bodyPartsNames), 11);
end

function testBarnesRealFile(testCase)
    % Real BARNES superanimal export: animal0..animal9, missing data
    % encoded as -1.0. Picker must (a) treat -1 as missing,
    % (b) pick the most-populated animal, (c) output NaN where -1 was.
    csv = fullfile(projectRoot(), 'Demo', 'BARNES', '3_DLC', ...
        '2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv');
    assumeTrue(testCase, isfile(csv), 'BARNES sample CSV not present');
    out = sphynx.io.readDLC(csv);
    verifyEqual(testCase, numel(out.individuals), 10);
    verifyTrue(testCase, startsWith(out.selectedIndividual, 'animal'));
    % 27 body parts per animal in superanimal_topviewmouse.
    verifyEqual(testCase, numel(out.bodyPartsNames), 27);
    % Missing sentinel was -1; output must show NaN in those slots.
    verifyTrue(testCase, any(isnan(out.X(:))), ...
        'Expected NaN replacements for -1.0 sentinels');
    % And the picked animal must have at least *some* populated frames
    % (otherwise picker is broken).
    populated = sum(~isnan(out.X(:)) & ~isnan(out.Y(:)));
    verifyGreaterThan(testCase, populated, 0);
end

function testForcedIndividual(testCase)
    csv = fullfile(projectRoot(), 'Demo', 'BARNES', '3_DLC', ...
        '2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv');
    assumeTrue(testCase, isfile(csv), 'BARNES sample CSV not present');
    out = sphynx.io.readDLC(csv, 'Individual', 'animal3');
    verifyEqual(testCase, out.selectedIndividual, 'animal3');
end

function testSingleAnimalStillWorks(testCase)
    % Backward compat: 3-row header is detected and parsed unchanged.
    csv = makeSingleAnimalCsv();
    cleaner = onCleanup(@() delete(csv)); %#ok<NASGU>
    out = sphynx.io.readDLC(csv);
    verifyFalse(testCase, isfield(out, 'individuals'));
    verifyEqual(testCase, numel(out.bodyPartsNames), 2);
    verifyEqual(testCase, out.X(1, 1), 100.5,  'AbsTol', 1e-6);
end

function root = projectRoot()
    % tests/unit/<this>.m -> ../../
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function csv = makeSingleAnimalCsv()
    csv = [tempname, '.csv'];
    fid = fopen(csv, 'w');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, 'scorer,DLC,DLC,DLC,DLC,DLC,DLC\n');
    fprintf(fid, 'bodyparts,nose,nose,nose,tail,tail,tail\n');
    fprintf(fid, 'coords,x,y,likelihood,x,y,likelihood\n');
    fprintf(fid, '0,100.5,200.25,0.987,110.1,210.7,0.93\n');
    fprintf(fid, '1,101.2,201.05,0.991,110.9,211.2,0.94\n');
end

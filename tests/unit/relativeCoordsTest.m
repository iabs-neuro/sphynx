function tests = relativeCoordsTest
    tests = functiontests(localfunctions);
end

function testTailbaseAtOriginInRelative(testCase)
    % Tailbase is part 1, Center is part 2. Body extends from origin.
    BX = [0 0; 5 5; 8 8];        % tailbase, center, head — over 2 frames
    BY = [0 0; 0 0; 0 0];
    Point = struct('Tailbase', 1, 'Center', 2, 'LeftBodyCenter', [], 'RightBodyCenter', []);
    out = sphynx.bodyparts.relativeCoords(BX, BY, Point);
    % Tailbase row in R should be all zero
    verifyEqual(testCase, out.R(1, :), [0 0], 'AbsTol', 1e-9);
end

function testCenterRowAlignedAfterRotation(testCase)
    % If we rotate so center is along theta=0, then in Theta the
    % center row should be all zeros (mod 2pi).
    BX = [0 0; 5 5];
    BY = [0 0; 5 0];   % frame 1: center NE; frame 2: center east
    Point = struct('Tailbase', 1, 'Center', 2, 'LeftBodyCenter', [], 'RightBodyCenter', []);
    out = sphynx.bodyparts.relativeCoords(BX, BY, Point);
    verifyEqual(testCase, out.Theta(2, :), [0 0], 'AbsTol', 1e-9);
end

function testAngleRotMatchesBodyAxis(testCase)
    % Mouse pointing east in frame 1 (center is east of tailbase).
    BX = [0; 5];
    BY = [0; 0];
    Point = struct('Tailbase', 1, 'Center', 2, 'LeftBodyCenter', [], 'RightBodyCenter', []);
    out = sphynx.bodyparts.relativeCoords(BX, BY, Point);
    verifyEqual(testCase, out.AngleRot, 0, 'AbsTol', 1e-9);
end

function testFallbackCenterFromLeftRight(testCase)
    % No Center; LeftBodyCenter and RightBodyCenter exist.
    BX = [0; -2; 2];
    BY = [0;  0; 0];
    Point = struct('Tailbase', 1, 'Center', [], ...
                   'LeftBodyCenter', 2, 'RightBodyCenter', 3);
    out = sphynx.bodyparts.relativeCoords(BX, BY, Point);
    % Body axis (mid of left/right = origin, but tailbase is also origin)
    % Actually L=(-2,0), R=(2,0), midpoint=(0,0), tailbase=(0,0). Degenerate.
    % Move tailbase to (0, -1) so axis = +y
    BX = [0; -2; 2];
    BY = [-1; 0; 0];
    out = sphynx.bodyparts.relativeCoords(BX, BY, Point);
    % AngleRot should be pi/2 (axis points +y from tailbase to mid-center)
    verifyEqual(testCase, out.AngleRot, pi/2, 'AbsTol', 1e-9);
end

function testNoTailbaseErrors(testCase)
    BX = [1; 2]; BY = [1; 2];
    Point = struct('Tailbase', [], 'Center', 2, 'LeftBodyCenter', [], 'RightBodyCenter', []);
    verifyError(testCase, @() sphynx.bodyparts.relativeCoords(BX, BY, Point), ...
        'sphynx:relativeCoords:noTailbase');
end

function tests = zoneVisitTest
% ZONEVISITTEST  Synthetic mouse crosses wall->center->wall and is detected.
%
%   Uses sphynx.testing.makeZoneCrossDLC + sphynx.zones.classifySquare
%   + sphynx.util.inMaskSafe to verify each frame is classified into
%   the expected zone (set-membership rather than exact label, since
%   transitions span a few frames).
    tests = functiontests(localfunctions);
end

function testEachWaypointHitsExpectedZone(testCase)
    f = sphynx.testing.makeZoneCrossDLC();
    zones = sphynx.zones.classifySquare(f.arenaMask, ...
        'Strategy','corners-walls-center', ...
        'PixelsPerCm',f.pxlPerCm, ...
        'WallWidthCm',3, ...
        'CornerPoints',f.cornerPoints);

    waypointFrames = [1 30 60 90 120];
    expected = {'corners','walls','center','walls','corners'};

    for k = 1:numel(waypointFrames)
        frame = waypointFrames(k);
        if frame > size(f.trajectory,1)
            frame = size(f.trajectory,1);
        end
        x = f.trajectory(frame, 1);
        y = f.trajectory(frame, 2);
        active = '';
        for z = 1:numel(zones)
            if sphynx.util.inMaskSafe(zones(z).maskfilled, x, y)
                active = zones(z).name;
                break;
            end
        end
        verifyEqual(testCase, active, expected{k}, ...
            sprintf('frame %d at (%.1f,%.1f) expected %s, got %s', ...
            frame, x, y, expected{k}, active));
    end
end

function testArenaAtFrameEdgeDoesNotCrash(testCase)
    f = sphynx.testing.makeArenaAtFrameEdgeDLC();
    zones = sphynx.zones.classifySquare(f.arenaMask, ...
        'Strategy','corners-walls-center', ...
        'PixelsPerCm',f.pxlPerCm, ...
        'WallWidthCm',3, ...
        'CornerPoints',f.cornerPoints);
    walls = zones(strcmp({zones.name},'walls'));
    corners = zones(strcmp({zones.name},'corners'));
    verifyGreaterThan(testCase, sum(walls.maskfilled(:)), 0, ...
        'Bug-1: arena at frame edge produced empty walls zone');
    verifyGreaterThan(testCase, sum(corners.maskfilled(:)), 0, ...
        'Bug-1: arena at frame edge produced empty corners zone');
end

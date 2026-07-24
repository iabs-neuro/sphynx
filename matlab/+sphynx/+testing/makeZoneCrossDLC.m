function fixture = makeZoneCrossDLC()
% MAKEZONECROSSDLC  Synthetic mouse trajectory crossing zones.
%
%   fixture = sphynx.testing.makeZoneCrossDLC() returns a struct:
%     trajectory    - Nx2 (x, y) matrix of body-center positions
%     arenaMask     - HxW logical
%     pxlPerCm      - calibration
%     cornerPoints  - 4x2 corner positions
%     expectedZones - cell array, expected zone name at each frame
%
%   Trajectory: starts in a corner, walks along wall, turns into
%   center, crosses to the opposite wall, ends in another corner.

    H = 200; W = 300;
    pxlPerCm = 5;

    fixture.arenaMask = false(H, W);
    fixture.arenaMask(20:180, 20:280) = true;
    fixture.pxlPerCm = pxlPerCm;
    fixture.cornerPoints = [20 20; 280 20; 280 180; 20 180];

    waypoints = [
        25  25  ; ...   % corner
        25  100 ; ...   % wall
        100 100 ; ...   % center
        275 100 ; ...   % wall
        275 175 ; ...   % corner
    ];
    expectedNames = {'corners','walls','center','walls','corners'};
    nPerSegment = 30;

    traj = [];
    expected = {};
    for i = 1:size(waypoints,1)-1
        for k = 1:nPerSegment
            t = (k-1) / (nPerSegment-1);
            x = (1-t)*waypoints(i,1) + t*waypoints(i+1,1);
            y = (1-t)*waypoints(i,2) + t*waypoints(i+1,2);
            traj(end+1, :) = [x, y]; %#ok<AGROW>
            expected{end+1} = expectedNames{i}; %#ok<AGROW>
        end
    end
    fixture.trajectory = traj;
    fixture.expectedZones = expected;
end

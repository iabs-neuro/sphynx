function fixture = makeArenaAtFrameEdgeDLC()
% MAKEARENAATFRAMEEDGEDLC  Synthetic arena that touches frame edge.
%
%   fixture = sphynx.testing.makeArenaAtFrameEdgeDLC() returns a
%   struct with fields:
%     arenaMask    - HxW logical, arena occupying the whole frame
%     pxlPerCm     - pixels per cm calibration
%     cornerPoints - 4x2 matrix of arena corners
%
%   Used to verify Bug-1 zone classification on edge-touching arena.

    H = 200; W = 300;
    fixture.arenaMask = true(H, W);
    fixture.pxlPerCm = 5;
    fixture.cornerPoints = [1 1; W 1; W H; 1 H];
end

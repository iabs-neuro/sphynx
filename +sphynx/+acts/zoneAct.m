function zoneMask = zoneAct(zoneMaskFilled, BodyPartsX, BodyPartsY, partIdx, minRunFrames)
% ZONEACT  Per-frame mask: is the chosen body part inside a zone mask?
%
%   zoneMask = sphynx.acts.zoneAct(zoneMaskFilled, BX, BY, partIdx, minRunFrames)
%
%   Inputs:
%     zoneMaskFilled - HxW logical (or numeric) zone occupancy mask
%     BodyPartsX, BodyPartsY - PartsxN body-part traces (pixels)
%     partIdx        - which row of BodyPartsX/Y to query (e.g., Point.Tailbase)
%     minRunFrames   - min consecutive in-zone frames for an entry
%
%   Output:
%     zoneMask - Nx1 logical
%
%   Uses sphynx.util.inMaskSafe so out-of-frame coordinates safely
%   yield false (Bug-1 mitigation propagated to the act stage).
%
%   Decomposition of legacy BehaviorAnalyzer.m:568-579.

    raw = sphynx.util.inMaskSafe(zoneMaskFilled, ...
                                  BodyPartsX(partIdx, :)', ...
                                  BodyPartsY(partIdx, :)');
    refined = sphynx.acts.refineAct(raw, minRunFrames, minRunFrames);
    zoneMask = refined(:);
end

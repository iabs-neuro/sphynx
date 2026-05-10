function a = emptyAct()
% EMPTYACT  Canonical empty act struct. Field order matches buildSimpleAct
% / buildComplexAct so struct array assignment doesn't blow up.

    a.name         = '';
    a.type         = 'simple';   % 'simple' | 'complex' | 'special'
    a.zones        = {};
    a.zoneOp       = 'OR';       % AND | OR | EXCLUDE
    a.bodyPart     = '';
    a.bodyParts    = {};         % for special acts (freezing)
    a.speedMin     = 0;
    a.speedMax     = Inf;
    a.components   = {};         % for complex
    a.operation    = '';         % intersect | union | exclude | sequence
    a.seqDelaySec  = 0;
    a.specialKind  = '';         % for special acts
    a.rearMode     = '';
    a.thresholdCm  = NaN;
    a.thresholdPxl = NaN;
    % Post-processing applied after the boolean is computed:
    %   minDurationSec — minimum length of a run of 1s to keep. Runs
    %     shorter than this are dropped (the act "didn't last long
    %     enough to count"). 0 disables.
    %   maxGapSec — maximum length of a gap of 0s that still counts
    %     as part of the act. Gaps shorter than this get filled with
    %     1s before the duration check, so a fragmented event
    %     consolidates into one run. 0 disables.
    a.minDurationSec = 0.25;
    a.maxGapSec      = 0;
end

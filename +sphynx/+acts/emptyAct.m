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
end

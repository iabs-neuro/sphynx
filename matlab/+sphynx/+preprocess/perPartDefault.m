function s = perPartDefault(partName, cfg)
% PERPARTDEFAULT  Default per-part preprocessing settings.
%
%   s = sphynx.preprocess.perPartDefault(partName) returns a struct
%   with fields likelihoodThreshold, smoothWindowSec, interpolationMethod,
%   smoothingMethod, smoothingPolyOrder, notFoundThresholdPct.
%
%   s = sphynx.preprocess.perPartDefault(partName, cfg) uses the
%   provided pipeline config struct (sphynx.pipeline.defaultConfig).
%
%   The big smoothing window applies to body-center / tailbase parts
%   (slow, large-amplitude motion); small window applies to limbs
%   and head parts (faster small-amplitude motion).

    if nargin < 2 || isempty(cfg)
        cfg = sphynx.pipeline.defaultConfig();
    end

    bigParts = cfg.preprocess.perPart.bigParts;
    if any(strcmpi(bigParts, partName))
        winSec = cfg.preprocess.smoothWindowBigSec;
    else
        winSec = cfg.preprocess.smoothWindowSmallSec;
    end

    s.likelihoodThreshold   = cfg.preprocess.likelihoodThreshold;
    s.smoothWindowSec       = winSec;
    s.interpolationMethod   = cfg.preprocess.interpolationMethod;
    s.smoothingMethod       = cfg.preprocess.perPart.smoothingMethod;
    s.smoothingPolyOrder    = cfg.preprocess.perPart.smoothingPolyOrder;
    s.notFoundThresholdPct  = cfg.preprocess.perPart.notFoundThresholdPct;
end

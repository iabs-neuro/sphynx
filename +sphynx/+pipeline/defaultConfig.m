function cfg = defaultConfig()
% DEFAULTCONFIG  Default configuration struct for sphynx.pipeline.analyzeSession.
%
%   cfg = sphynx.pipeline.defaultConfig() returns a struct with all
%   default values, ready to be overridden by the caller.
%
%   Top-level fields:
%     paths           - {video, dlc, preset, outDir}
%     range           - {startFrame=1, endFrame=0 (= last)}
%     preprocess      - {likelihoodThreshold, smoothWindowSmallSec,
%                        smoothWindowBigSec, maxVelocityCmS,
%                        interpolationMethod}
%     acts            - {restThresholdCmS, locThresholdCmS,
%                        minRunSeconds, freezingMode, rearMode,
%                        rearThresholdAllBodyPartsPxl,
%                        rearThresholdTailbasePawsCm}
%     io              - {saveWorkspace, sessionName}
%     viz             - {enabled, headless, makeVideo}
%     verbose         - 'debug' | 'info' | 'warn' | 'error'

    cfg.paths.video   = '';
    cfg.paths.dlc     = '';
    cfg.paths.preset  = '';
    cfg.paths.outDir  = '';

    cfg.range.startFrame = 1;
    cfg.range.endFrame   = 0;          % 0 = read all

    cfg.preprocess.likelihoodThreshold = 0.95;
    cfg.preprocess.smoothWindowSmallSec = 0.10;
    cfg.preprocess.smoothWindowBigSec   = 0.25;
    cfg.preprocess.maxVelocityCmS = 50;
    cfg.preprocess.interpolationMethod = 'pchip';

    % Per-part defaults used by sphynx.preprocess.perPartDefault
    cfg.preprocess.perPart.bigParts = {'mass centre', 'mass center', 'bodycenter', ...
                                       'center', 'tailbase', 'tail base'};
    cfg.preprocess.perPart.smoothingMethod = 'sgolay';
    cfg.preprocess.perPart.smoothingPolyOrder = 3;
    cfg.preprocess.perPart.notFoundThresholdPct = 90;

    cfg.acts.restThresholdCmS  = 1;
    cfg.acts.locThresholdCmS   = 5;
    cfg.acts.minRunSeconds     = 0.25;
    cfg.acts.freezingMode      = 'HeadAndCenter';     % | 'NoseAndCenter' | 'AllBodyParts'
    cfg.acts.rearMode          = 'TailbasePaws';      % | 'AllBodyParts'
    cfg.acts.rearThresholdAllBodyPartsPxl = 170;
    cfg.acts.rearThresholdTailbasePawsCm  = 3.6;

    cfg.io.saveWorkspace = true;
    cfg.io.sessionName   = '';

    cfg.viz.enabled    = false;
    cfg.viz.headless   = true;
    cfg.viz.makeVideo  = false;

    cfg.verbose = 'info';
end

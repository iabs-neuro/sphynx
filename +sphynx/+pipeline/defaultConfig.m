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

    cfg.paths.video             = '';
    cfg.paths.dlc               = '';
    cfg.paths.preset            = '';
    cfg.paths.outDir            = '';
    % Per-experiment Preprocess Settings .mat (sphynx.io.writeTracksSettings
    % output: bodyparts + outlier + metadata). When non-empty,
    % analyzeSession applies per-part likelihoodThreshold and
    % notFoundThresholdPct to cleanBodyPart instead of the scalar
    % cfg.preprocess.likelihoodThreshold default. When empty, the
    % pipeline auto-discovers <expRoot>/<expName>_PreprocessSettings.mat
    % by walking up the DLC's parent directories.
    cfg.paths.preprocessSettings = '';

    cfg.range.startFrame = 1;
    cfg.range.endFrame   = 0;          % 0 = read all
    % R11/R16: detector exists at sphynx.preprocess.detectSessionStartFrame
    % but auto-application is OFF by default. Set true per call to
    % opt in. The Preprocess Tracking tab no longer surfaces a session-
    % start indicator and never invokes the detector implicitly.
    cfg.range.autoStart  = false;

    % Multi-animal DLC: which individual to analyse. '' = auto-pick the
    % one with the most populated x/y entries (default in readDLC).
    % Settings.metadata.individual (when present in the experiment's
    % PreprocessSettings.mat) overrides this; explicit cfg value
    % overrides Settings.
    cfg.preprocess.individual = '';
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

    cfg.acts.libraryPath = '';   % optional path to a custom acts library .mat
    cfg.acts.restThresholdCmS  = 1;
    cfg.acts.locThresholdCmS   = 5;
    cfg.acts.minRunSeconds     = 0.25;
    cfg.acts.freezingMode      = 'HeadAndCenter';     % | 'NoseAndCenter' | 'AllBodyParts'
    cfg.acts.rearMode          = 'TailbasePaws';      % | 'AllBodyParts'
    cfg.acts.rearThresholdAllBodyPartsPxl = 170;
    % 3.35 cm maximises event-level F1 against hand-scored rears
    % (W:\Projects\Rear_ML, 19 sessions, ~580 rears, DLC MiceUniversal
    % ResNet-152, open fields). The value depends on where the DLC model
    % puts the hindlimbs, so a project tracked with another model should
    % calibrate its own value once and keep it fixed for all sessions.
    cfg.acts.rearThresholdTailbasePawsCm  = 3.35;
    % Off by default. The per-session threshold (median - 1.5*SD, 7th
    % percentile) depends on how many rears the session has and on
    % tracking outliers: it collapsed to its 1.5 cm floor on LT1
    % sessions with a few far-off points, and on Rear_ML it scored worse
    % than the fixed value (event F1 0.43 vs 0.60).
    cfg.acts.rearAutoThreshold            = false;

    cfg.io.saveWorkspace = true;
    cfg.io.sessionName   = '';

    cfg.viz.enabled    = false;
    cfg.viz.headless   = true;
    cfg.viz.makeVideo  = false;

    cfg.verbose = 'info';

    % Auto-pull repo-root sphynx_defaults.jsonc if present so the
    % values the user edited there become THIS run's defaults.
    % Applied here (vs. inside analyzeSession) so the caller can still
    % override any field afterward -- jsonc seeds defaults, caller wins.
    try
        cfg = sphynx.pipeline.applyJsoncDefaults(cfg);
    catch
        % Silent: a missing / malformed jsonc must not break the
        % pipeline. readDefaultsJsonc already warns on parse errors.
    end
end

function cfg = applyJsoncDefaults(cfg, jsoncStruct)
% APPLYJSONCDEFAULTS  Merge sphynx_defaults.jsonc onto a cfg struct.
%
%   cfg = sphynx.pipeline.applyJsoncDefaults(cfg)
%   cfg = sphynx.pipeline.applyJsoncDefaults(cfg, jsoncStruct)
%
%   Maps the (tab-shaped) sphynx_defaults.jsonc layout onto the
%   flat (sphynx.pipeline.defaultConfig) cfg struct so analyzeSession
%   sees the user's overrides.
%
%   Without the second arg, auto-loads sphynx_defaults.jsonc via
%   sphynx.io.readDefaultsJsonc. Pass an explicit struct (e.g. one
%   built by tests) to bypass file IO.
%
%   Mapping (jsonc field -> cfg field):
%     paths.*                              -> cfg.paths.*
%     range.*                              -> cfg.range.*
%     io.*                                 -> cfg.io.*
%     viz.*                                -> cfg.viz.*
%     verbose                              -> cfg.verbose
%     preprocessTab.individual             -> cfg.preprocess.individual
%     preprocessTab.likelihoodThreshold    -> cfg.preprocess.likelihoodThreshold
%     preprocessTab.smoothWindowSmallSec   -> cfg.preprocess.smoothWindowSmallSec
%     preprocessTab.smoothWindowBigSec     -> cfg.preprocess.smoothWindowBigSec
%     preprocessTab.maxVelocityCmS         -> cfg.preprocess.maxVelocityCmS
%     preprocessTab.interpolationMethod    -> cfg.preprocess.interpolationMethod
%     preprocessTab.perPart.*              -> cfg.preprocess.perPart.*
%     defineActs.{libraryPath, restThresholdCmS, locThresholdCmS,
%                 minRunSeconds, freezingMode, rearMode,
%                 rearThresholdAllBodyPartsPxl,
%                 rearThresholdTailbasePawsCm, rearAutoThreshold}
%                                          -> cfg.acts.*
%
%   Tab-only UI defaults (preprocessTab.savePlots, defineActs.simple*,
%   analyzeTab.*, batchTab.*, makeOutputTable.*, plotData.*,
%   preprocessVideo.*, syntheticData.*, createPreset.*) are NOT
%   pushed onto cfg here -- their controllers consume them directly
%   from the loaded jsonc struct when (re)building UI state.

    if nargin < 2 || isempty(jsoncStruct)
        jsoncStruct = sphynx.io.readDefaultsJsonc();
    end
    if isempty(jsoncStruct) || ~isstruct(jsoncStruct); return; end

    % --- global blocks (1:1 mapping) ---
    cfg = mergeBlock(cfg, jsoncStruct, 'paths',    'paths',    {'video','dlc','preset','outDir','preprocessSettings'});
    cfg = mergeBlock(cfg, jsoncStruct, 'range',    'range',    {'startFrame','endFrame','autoStart'});
    cfg = mergeBlock(cfg, jsoncStruct, 'io',       'io',       {'saveWorkspace','sessionName'});
    cfg = mergeBlock(cfg, jsoncStruct, 'viz',      'viz',      {'enabled','headless','makeVideo'});

    if isfield(jsoncStruct, 'verbose') && ischar(jsoncStruct.verbose)
        cfg.verbose = jsoncStruct.verbose;
    end

    % --- preprocessTab -> cfg.preprocess ---
    if isfield(jsoncStruct, 'preprocessTab')
        pt = jsoncStruct.preprocessTab;
        cfg.preprocess = mergeFields(cfg.preprocess, pt, ...
            {'individual','likelihoodThreshold','smoothWindowSmallSec', ...
             'smoothWindowBigSec','maxVelocityCmS','interpolationMethod'});
        if isfield(pt, 'perPart') && isstruct(pt.perPart)
            cfg.preprocess.perPart = mergeFields(cfg.preprocess.perPart, pt.perPart, ...
                {'bigParts','smoothingMethod','smoothingPolyOrder','notFoundThresholdPct'});
        end
        % Outlier defaults are consumed by analyzeSession via
        % loadPreprocessSettings (per-experiment .mat); we don't push
        % them onto cfg here since cfg has no outlier sub-struct.
    end

    % --- defineActs -> cfg.acts ---
    if isfield(jsoncStruct, 'defineActs')
        da = jsoncStruct.defineActs;
        cfg.acts = mergeFields(cfg.acts, da, ...
            {'libraryPath','restThresholdCmS','locThresholdCmS', ...
             'minRunSeconds','freezingMode','rearMode', ...
             'rearThresholdAllBodyPartsPxl','rearThresholdTailbasePawsCm', ...
             'rearAutoThreshold'});
    end
end

function cfg = mergeBlock(cfg, src, srcName, cfgName, fields)
    if ~isfield(src, srcName) || ~isstruct(src.(srcName)); return; end
    cfg.(cfgName) = mergeFields(cfg.(cfgName), src.(srcName), fields);
end

function dst = mergeFields(dst, src, fields)
    for k = 1:numel(fields)
        f = fields{k};
        if isfield(src, f)
            v = src.(f);
            % jsondecode renders JSON null as [] for non-numeric fields;
            % don't overwrite Inf/[] sentinels with []. Only push real values.
            if ~(isempty(v) && ~ischar(v))
                dst.(f) = v;
            end
        end
    end
end

function result = analyzeSession(config)
% ANALYZESESSION  Main pipeline: DLC + preset -> Acts + traces.
%
%   result = sphynx.pipeline.analyzeSession(config)
%
%   `config` is a struct produced by sphynx.pipeline.defaultConfig and
%   overridden as needed by the caller. Required: config.paths.dlc,
%   config.paths.preset.
%
%   Returns a struct with fields:
%     bodyPartsNames    - 1xP cell of part names (after dropping NotFound)
%     BodyPartsTraces   - 1xP struct: TraceOriginal/Interpolated/Smoothed,
%                         Status, PercentNaN, PercentLowLikelihood,
%                         AverageDistance, AverageSpeed, Velocity,
%                         VelocitySmoothed
%     Point             - struct from sphynx.bodyparts.identifyParts
%     Acts              - struct array: ActName, ActArrayRefine, plus
%                         numeric stats from sphynx.acts.actStats
%     Options, Zones, ArenaAndObjects - copied from preset
%     n_frames          - number of frames analyzed
%     config            - the input config (for traceability)
%
%   This is the new entry replacing the monolithic
%   functions/BehaviorAnalyzer.m. It does NOT do plotting or video
%   output by default (see config.viz). It performs a single save at
%   the end via sphynx.io.saveSession when config.io.saveWorkspace.
%
%   See docs/superpowers/specs/2026-04-27-sphynx-stage-c-design.md.

    prevHeadless = getenv('SPHYNX_HEADLESS');
    prevLog = getenv('SPHYNX_LOG_LEVEL');
    envCleaner = onCleanup(@() restoreEnv(prevHeadless, prevLog)); %#ok<NASGU>
    if config.viz.headless
        setenv('SPHYNX_HEADLESS', '1');
    end
    if ~isempty(config.verbose)
        setenv('SPHYNX_LOG_LEVEL', config.verbose);
    end

    log = @(level, varargin) sphynx.util.log(level, varargin{:});

    % --- 1. Load preset & DLC -------------------------------------------------
    log('info', 'Reading preset: %s', config.paths.preset);
    presetData = sphynx.io.readPreset(config.paths.preset);
    Options = presetData.Options;
    Zones = presetData.Zones;
    ArenaAndObjects = presetData.ArenaAndObjects;

    log('info', 'Reading DLC: %s', config.paths.dlc);
    % R11 auto-start: if user kept startFrame=1 and autoStart is on,
    % read the full DLC first, detect the session start from the trace,
    % then re-read with that start. The detected frame is recorded in
    % config.range.startFrame so the rest of the pipeline (video offsets,
    % timestamps) sees a single source of truth.
    autoStart = false;
    if isfield(config.range, 'autoStart')
        autoStart = config.range.autoStart;
    end
    % Resolve which DLC individual to feed to readDLC.
    %
    % Policy (per-session correctness over experiment-level caching):
    %   1. explicit cfg.preprocess.individual wins -- programmatic
    %      callers can force a specific animal.
    %   2. otherwise readDLC auto-picks the most-populated individual
    %      fresh for THIS session. Once picked, the same individual
    %      is reused for every downstream readDLC call in this same
    %      analyzeSession run (so the autostart pre-scan + main slice
    %      never drift apart) and surfaces in result.SelectedIndividual.
    %
    % We deliberately do NOT consult Settings.metadata.individual or
    % similar experiment-level caches: different sessions in one
    % experiment can have different "best" individuals (animal0 in
    % one trial, animal3 in another), and a sticky cache would
    % silently force the wrong one.
    individual = '';
    if isfield(config.preprocess, 'individual')
        individual = config.preprocess.individual;
    end
    if ~isempty(individual)
        log('info', 'DLC individual override (from cfg): "%s"', individual);
    end
    if autoStart && config.range.startFrame == 1
        dlcFull = sphynx.io.readDLC(config.paths.dlc, ...
            'EndFrame', config.range.endFrame, ...
            'Individual', individual);
        [detected, detInfo] = sphynx.preprocess.detectSessionStartFrame(dlcFull);
        if isempty(detInfo.message) && detected > 1
            log('info', 'Auto-start: detected session start at frame %d (firstPop=%d, populatedRatio=%.2f)', ...
                detected, detInfo.firstPopulatedFrame, detInfo.totalPopulatedRatio);
            config.range.startFrame = detected;
        else
            log('info', 'Auto-start: keeping startFrame=1 (%s)', ...
                ifEmpty(detInfo.message, 'animal populated from frame 1'));
        end
    end
    dlc = sphynx.io.readDLC(config.paths.dlc, ...
        'StartFrame', config.range.startFrame, ...
        'EndFrame', config.range.endFrame, ...
        'Individual', individual);

    % Lock the resolved individual back into config so any later
    % readDLC re-invocation in this same analyzeSession run reuses
    % the same animal. Empty -> readDLC's auto-pick result; non-empty
    % -> the explicit cfg value. Either way, within this session
    % everything points at one animal.
    if isempty(individual) && isfield(dlc, 'selectedIndividual')
        individual = dlc.selectedIndividual;
        config.preprocess.individual = individual;
    end

    % Frame-count sanity check vs the source video. A DLC csv that
    % covers fewer frames than the video means downstream Make-video /
    % renderActStitched will see a sync drift: the DLC frame index N
    % does not necessarily land on video frame N when the export was
    % truncated or offset. Warn so the user can investigate.
    if ~isempty(config.paths.video) && isfile(config.paths.video)
        try
            vr = VideoReader(config.paths.video);
            if vr.NumFrames > 0 && dlc.nFrames < vr.NumFrames
                log('warn', ['DLC covers %d frames but video has %d ' ...
                    '(diff %d). Make-video overlays assume DLC frame N == ' ...
                    'video frame N; if your DLC export was truncated or ' ...
                    'offset, points will not align with the animal.'], ...
                    dlc.nFrames, vr.NumFrames, vr.NumFrames - dlc.nFrames);
            end
        catch
            % video may be missing or unreadable in headless probes -- not fatal
        end
    end

    nParts = numel(dlc.bodyPartsNames);
    nFrames = dlc.nFrames;
    frameRate = Options.FrameRate;
    pxlPerCm = Options.pxl2sm;
    log('info', 'Loaded %d frames, %d body parts', nFrames, nParts);

    % --- 2. Smooth-window sizes from frame rate -------------------------------
    smallWin = makeOdd(round(frameRate * config.preprocess.smoothWindowSmallSec));
    bigWin   = makeOdd(round(frameRate * config.preprocess.smoothWindowBigSec));
    minRunFrames = round(frameRate * config.acts.minRunSeconds);

    % --- 3. Clean each body-part trace ---------------------------------------
    % Fast-path: if a sibling _Preprocessed.mat exists next to the DLC,
    % consume its BodyPartsTraces directly and skip clean/interp/smooth.
    [BodyPartsTraces, keepIdx] = tryLoadPrepared(config.paths.dlc, dlc, log);
    if isempty(BodyPartsTraces)
        % Look for a per-experiment Preprocess Settings .mat. Explicit
        % cfg.paths.preprocessSettings wins; otherwise auto-discover
        % by walking up from the DLC dir to 4 levels and grabbing the
        % first *_PreprocessSettings.mat found. This is the file saved
        % by the Preprocess Tracking tab's "Save preprocessed" button.
        [perPart, outlierSettings] = loadPreprocessSettings(config, log);

        BodyPartsTraces = struct('BodyPartName', {}, 'TraceOriginal', {}, ...
            'TraceInterpolated', {}, 'TraceSmoothed', {}, 'Status', {}, ...
            'PercentNaN', {}, 'PercentLowLikelihood', {}, ...
            'Velocity', {}, 'VelocitySmoothed', {}, 'AverageSpeed', {}, ...
            'AverageDistance', {});
        keepIdx = false(1, nParts);

        % Shared context for the per-part orchestrator.
        ctxBase.frameWidth   = Options.Width;
        ctxBase.frameHeight  = Options.Height;
        ctxBase.frameRate    = frameRate;
        ctxBase.pixelsPerCm  = pxlPerCm;
        if ~isempty(outlierSettings); ctxBase.outlier = outlierSettings; end

        for part = 1:nParts
            partName = dlc.bodyPartsNames{part};
            rawX = dlc.X(part, :)';
            rawY = dlc.Y(part, :)';
            lk   = dlc.likelihood(part, :)';
            partSettings = resolvePartSettings(perPart, partName, config);

            BodyPartsTraces(part).BodyPartName = partName;
            BodyPartsTraces(part).TraceOriginal.X = rawX;
            BodyPartsTraces(part).TraceOriginal.Y = rawY;
            BodyPartsTraces(part).TraceLikelihood = lk;

            % Honor per-part "use" flag from the Settings table.
            if isfield(partSettings, 'use') && ~isempty(partSettings.use) ...
                    && ~partSettings.use
                BodyPartsTraces(part).PercentNaN = NaN;
                BodyPartsTraces(part).PercentLowLikelihood = NaN;
                BodyPartsTraces(part).Status = 'NotFound';
                log('warn', 'BodyPart "%s" use=false in Settings, skipping', partName);
                continue;
            end

            ctx = ctxBase;
            ctx.partName = partName;

            res = sphynx.preprocess.applyPerPartSettings( ...
                rawX, rawY, lk, partSettings, ctx);

            BodyPartsTraces(part).PercentNaN = res.percentNaN;
            BodyPartsTraces(part).PercentLowLikelihood = res.percentLowLikelihood;
            BodyPartsTraces(part).Status = res.status;

            if strcmp(res.status, 'NotFound')
                log('warn', 'BodyPart "%s" status NotFound, skipping', partName);
                continue;
            end
            keepIdx(part) = true;

            BodyPartsTraces(part).TraceInterpolated.X = res.X_interp;
            BodyPartsTraces(part).TraceInterpolated.Y = res.Y_interp;
            BodyPartsTraces(part).TraceSmoothed.X    = res.X_smooth;
            BodyPartsTraces(part).TraceSmoothed.Y    = res.Y_smooth;
        end
    end

    % Drop NotFound parts
    BodyPartsTraces = BodyPartsTraces(keepIdx);
    bodyPartsNames = dlc.bodyPartsNames(keepIdx);

    % Build smoothed PxN matrices for downstream
    nKept = numel(BodyPartsTraces);
    BPX = zeros(nKept, nFrames);
    BPY = zeros(nKept, nFrames);
    for part = 1:nKept
        BPX(part, :) = BodyPartsTraces(part).TraceSmoothed.X(:)';
        BPY(part, :) = BodyPartsTraces(part).TraceSmoothed.Y(:)';
    end

    % --- 4. Identify body parts and compute Center ---------------------------
    Point = sphynx.bodyparts.identifyParts(bodyPartsNames);
    [centerX, centerY] = sphynx.bodyparts.computeCenter(BPX, BPY, Point);
    if isempty(Point.Center)
        % append synthetic center to BPX/BPY and update Point
        BPX(end+1, :) = centerX; %#ok<AGROW>
        BPY(end+1, :) = centerY; %#ok<AGROW>
        Point.Center = size(BPX, 1);
    end

    % --- 5. Per-part velocities ----------------------------------------------
    for part = 1:nKept
        win = pickSmoothWindow(BodyPartsTraces(part).BodyPartName, smallWin, bigWin);
        v = sphynx.preprocess.computeVelocity(BPX(part,:)', BPY(part,:)', frameRate, pxlPerCm, ...
            'MaxVelocityCmS', config.preprocess.maxVelocityCmS, ...
            'SmoothWindow', win);
        BodyPartsTraces(part).Velocity = v;            %#ok<AGROW>
        BodyPartsTraces(part).VelocitySmoothed = v;    % already smoothed in computeVelocity
        BodyPartsTraces(part).AverageSpeed = round(mean(v, 'omitnan'), 2);
        % Total distance travelled in cm: sum of per-frame
        % displacements = sum(v) / frameRate.
        BodyPartsTraces(part).AverageDistance = round( ...
            sum(v, 'omitnan') / frameRate, 2);
    end

    % Choose the velocity used for speed acts (legacy uses Options.BodyPart.Velocity)
    if isfield(Options, 'BodyPart') && isfield(Options.BodyPart, 'Velocity')
        velPartName = Options.BodyPart.Velocity;
    else
        velPartName = 'bodycenter';
    end
    velPartIdx = find(strcmpi(bodyPartsNames, velPartName), 1);
    if isempty(velPartIdx)
        % Fallback: use computeCenter row
        velocity = sphynx.preprocess.computeVelocity(centerX(:), centerY(:), frameRate, pxlPerCm, ...
            'MaxVelocityCmS', config.preprocess.maxVelocityCmS, ...
            'SmoothWindow', bigWin);
    else
        velocity = BodyPartsTraces(velPartIdx).VelocitySmoothed;
    end

    % --- 6. Speed acts -------------------------------------------------------
    speed = sphynx.acts.speedActs(velocity, ...
        getOpt(Options, 'velocity_rest', config.acts.restThresholdCmS), ...
        getOpt(Options, 'velocity_locomotion', config.acts.locThresholdCmS), ...
        minRunFrames);

    Acts = struct('ActName', {}, 'ActArrayRefine', {}, ...
        'Category', {}, 'Definition', {});
    Acts(end+1).ActName = 'rest';
    Acts(end).ActArrayRefine = double(speed.rest(:)');
    Acts(end).Category = 'builtin';
    Acts(end).Definition = struct('zones', {{}});
    Acts(end+1).ActName = 'walk';
    Acts(end).ActArrayRefine = double(speed.walk(:)');
    Acts(end).Category = 'builtin';
    Acts(end).Definition = struct('zones', {{}});
    Acts(end+1).ActName = 'locomotion';
    Acts(end).ActArrayRefine = double(speed.locomotion(:)');
    Acts(end).Category = 'builtin';
    Acts(end).Definition = struct('zones', {{}});

    % --- 7. Freezing ---------------------------------------------------------
    BPV = zeros(nKept, nFrames);
    for part = 1:nKept
        BPV(part, :) = BodyPartsTraces(part).VelocitySmoothed(:)';
    end
    freeze = sphynx.acts.freezing(BPV, Point, config.acts.freezingMode, ...
        getOpt(Options, 'velocity_rest', config.acts.restThresholdCmS), minRunFrames);
    Acts(end+1).ActName = 'freezing';
    Acts(end).ActArrayRefine = double(freeze(:)');
    Acts(end).Category = 'builtin';
    Acts(end).Definition = struct('zones', {{}});

    % --- 8. Rear -------------------------------------------------------------
    rearOk = ~isempty(Point.Tailbase) && ~isempty(Point.LeftHindLimb) && ~isempty(Point.RightHindLimb);
    if rearOk || strcmp(config.acts.rearMode, 'AllBodyParts')
        rearMode = config.acts.rearMode;
        if strcmp(rearMode, 'TailbasePaws') && ~rearOk
            rearMode = 'AllBodyParts';
            log('warn', 'Falling back to rear mode AllBodyParts (missing parts for TailbasePaws)');
        end
        try
            autoFlag = false;
            if isfield(config.acts, 'rearAutoThreshold')
                autoFlag = logical(config.acts.rearAutoThreshold);
            end
            r = sphynx.acts.rear(BPX, BPY, Point, rearMode, ...
                'PixelsPerCm', pxlPerCm, ...
                'AllBodyPartsThresholdPxl', config.acts.rearThresholdAllBodyPartsPxl, ...
                'TailbasePawsThresholdCm',  config.acts.rearThresholdTailbasePawsCm, ...
                'AutoThreshold', autoFlag, ...
                'FrameRate', frameRate, ...
                'MinRunFrames', minRunFrames);
            Acts(end+1).ActName = 'rear';
            Acts(end).ActArrayRefine = double(r(:)');
            Acts(end).Category = 'builtin';
            Acts(end).Definition = struct('zones', {{}});
        catch ME
            log('warn', 'Rear detection failed: %s', ME.message);
        end
    end

    % --- 9. Zone acts -------------------------------------------------------
    if ~isempty(Zones)
        zoneSpec = legacyZoneActSpec();
        for k = 1:size(zoneSpec, 1)
            zoneName = zoneSpec{k, 1};
            actName  = zoneSpec{k, 2};
            partName = zoneSpec{k, 3};
            zIdx = find(strcmp({Zones.name}, zoneName), 1);
            if isempty(zIdx); continue; end
            partIdx = find(strcmpi(bodyPartsNames, partName), 1);
            if isempty(partIdx); continue; end
            mask = sphynx.acts.zoneAct(Zones(zIdx).maskfilled, BPX, BPY, partIdx, minRunFrames);
            Acts(end+1).ActName = actName; %#ok<AGROW>
            Acts(end).ActArrayRefine = double(mask(:)');
            Acts(end).Category = 'zone';
            Acts(end).Definition = struct('zones', {{zoneName}}, ...
                'bodyPart', partName);
        end
    end

    % --- 9b. Custom acts library (optional) ----------------------------------
    % If config.acts.libraryPath points to a saved acts library, evaluate
    % every act in it and append the results to Acts. Names are unique-d
    % so a custom act named "rest" doesn't collide with the built-in.
    if isfield(config.acts, 'libraryPath') && ~isempty(config.acts.libraryPath)
        if isfile(config.acts.libraryPath)
            try
                customActs = sphynx.io.loadActsSet(config.acts.libraryPath);
                ctx = struct();
                ctx.X = BPX; ctx.Y = BPY;
                ctx.velocityCmS = BPV;
                ctx.bodyParts = bodyPartsNames;
                ctx.zones = Zones;
                ctx.frameRate = frameRate;
                ctx.pixelsPerCm = pxlPerCm;
                ctx.allActs = customActs;
                ctx.resultsByName = containers.Map();
                results = sphynx.acts.evalActsLibrary(customActs, ctx);
                names = keys(results);
                for k = 1:numel(names)
                    nm = names{k};
                    % Custom acts REPLACE built-in / zone acts that
                    % share the same name (case-insensitive). Old
                    % behaviour renamed customs to <name>_custom which
                    % cluttered the etogram with duplicates.
                    dupIdx = find(strcmpi({Acts.ActName}, nm));
                    if ~isempty(dupIdx)
                        Acts(dupIdx) = []; %#ok<AGROW>
                    end
                    Acts(end+1).ActName = nm; %#ok<AGROW>
                    Acts(end).ActArrayRefine = double(results(nm));
                    Acts(end).Category = 'custom';
                    actDefIdx = find(strcmp({customActs.name}, nm), 1);
                    if ~isempty(actDefIdx)
                        Acts(end).Definition = customActs(actDefIdx);
                    else
                        Acts(end).Definition = struct('zones', {{}});
                    end
                end
                log('info', 'Custom acts library: %d acts from %s', ...
                    numel(names), config.acts.libraryPath);
            catch ME
                log('warn', 'Failed to apply custom acts library: %s', ME.message);
            end
        else
            log('warn', 'cfg.acts.libraryPath does not exist: %s', config.acts.libraryPath);
        end
    end

    % --- 9c. Within-bucket mutual exclusivity --------------------------------
    % Speed acts (rest/walk/locomotion) and spatial acts (corners/walls/
    % walls_and_corners/middle_zone/center) should not overlap on the
    % same frame. Higher-priority acts win — lower-priority bucket
    % mates get zeroed out in frames where any winner is already true.
    %
    % This is a hack pending the proper exclusive-from-the-start
    % discussion in docs/TODO.md. Done after custom acts so a user's
    % renamed/re-thresholded "rest" still participates in the bucket.
    Acts = enforceBucketExclusivity(Acts, ...
        {'locomotion', 'walk', 'rest'});
    Acts = enforceBucketExclusivity(Acts, ...
        {'corners', 'walls', 'walls_and_corners', 'middle_zone', 'center'});

    % --- 10. Stats per act ---------------------------------------------------
    centerVelocity = BodyPartsTraces(end).VelocitySmoothed; % synthetic-or-real Center
    if Point.Center <= numel(BodyPartsTraces)
        centerVelocity = BodyPartsTraces(Point.Center).VelocitySmoothed;
    end
    for line = 1:numel(Acts)
        s = sphynx.acts.actStats(Acts(line).ActArrayRefine, frameRate, 'Velocity', centerVelocity);
        Acts(line).ActNumber = s.ActNumber;
        Acts(line).ActPercent = s.ActPercent;
        Acts(line).ActDuration = s.ActDuration;
        Acts(line).ActMeanTime = s.ActMeanTime;
        Acts(line).ActMedianTime = s.ActMedianTime;
        Acts(line).ActMeanSTDTime = s.ActMeanSTDTime;
        Acts(line).ActMedianMADTime = s.ActMedianMADTime;
        Acts(line).Distance = s.Distance;
        Acts(line).ActMeanDistance = s.ActMeanDistance;
        Acts(line).ActMeanVelocity = s.ActMeanVelocity;
        Acts(line).ActMaxVelocity  = s.ActMaxVelocity;
        Acts(line).ActMinVelocity  = s.ActMinVelocity;
        Acts(line).ActVelocity     = s.ActVelocity;          % alias
        Acts(line).FirstStartSec    = s.FirstStartSec;
        Acts(line).FirstEndSec      = s.FirstEndSec;
        Acts(line).LastStartSec     = s.LastStartSec;
        Acts(line).LastEndSec       = s.LastEndSec;
        Acts(line).FirstDurationSec = s.FirstDurationSec;
        Acts(line).RestDurationSec  = s.RestDurationSec;
    end

    % --- 11. Result struct ---------------------------------------------------
    result = struct();
    result.bodyPartsNames = bodyPartsNames;
    result.BodyPartsTraces = BodyPartsTraces;
    result.Point = Point;
    result.Acts = Acts;
    result.Options = Options;
    result.Zones = Zones;
    result.ArenaAndObjects = ArenaAndObjects;
    result.n_frames = nFrames;
    result.config = config;
    % Multi-animal trace: which individual the DLC reader actually used
    % and the full list it saw. Both fields stay empty for a single-
    % animal csv. Make-video / renderActStitched can show / log these
    % so the user can tell at a glance which animal is being drawn.
    if isfield(dlc, 'selectedIndividual')
        result.SelectedIndividual = dlc.selectedIndividual;
    else
        result.SelectedIndividual = '';
    end
    if isfield(dlc, 'individuals')
        result.AllIndividuals = dlc.individuals;
    else
        result.AllIndividuals = {};
    end

    % --- 11b. Barnes paradigm metrics (if applicable) ----------------------
    % Computes nose / body hole-visit counts, first-checked-hole angular
    % error, mean angular error of checked holes, and target visit order.
    % Triggered when:
    %   (a) Options.ExperimentType == 'Barnes', AND
    %   (b) the loaded acts library actually contains at least one
    %       nose_at_object* act -- otherwise every Barnes metric would
    %       trivially be zero and just spam the log. Make-video and
    %       similar callers that pass a 1-act temp library hit this
    %       guard and skip cleanly.
    if isfield(Options, 'ExperimentType') ...
            && ischar(Options.ExperimentType) ...
            && strcmpi(Options.ExperimentType, 'Barnes') ...
            && hasBarnesNoseActs(Acts)
        try
            result.BarnesMetrics = sphynx.pipeline.barnesSessionMetrics(result);
            log('info', 'Barnes metrics computed (%d nose visits, target visit order = %s)', ...
                result.BarnesMetrics.TotalNoseHoleVisits, ...
                num2str(result.BarnesMetrics.TargetHoleVisitOrder));
        catch ME
            log('warn', 'Barnes metrics failed: %s', ME.message);
        end
    end

    % --- 12. Save ------------------------------------------------------------
    if config.io.saveWorkspace && ~isempty(config.paths.outDir)
        sessionName = config.io.sessionName;
        if isempty(sessionName)
            [~, sessionName, ~] = fileparts(config.paths.dlc);
        end
        sphynx.io.saveSession(result, config.paths.outDir, sessionName);
    end
end

function Acts = enforceBucketExclusivity(Acts, priorityNames)
    % Walk priorityNames in order. Each act only keeps frames not
    % already claimed by a higher-priority bucket-mate. Acts whose
    % names aren't in priorityNames are untouched.
    if isempty(Acts) || isempty(priorityNames); return; end
    names = {Acts.ActName};
    cumMask = [];
    for k = 1:numel(priorityNames)
        idx = find(strcmpi(names, priorityNames{k}), 1);
        if isempty(idx); continue; end
        a = logical(Acts(idx).ActArrayRefine(:)');
        if isempty(cumMask)
            cumMask = a;
        else
            % Only frames where no higher-priority act is active.
            a = a & ~cumMask;
            Acts(idx).ActArrayRefine = double(a);
            cumMask = cumMask | a;
        end
    end
end

function restoreEnv(prevHeadless, prevLog)
    setenv('SPHYNX_HEADLESS', prevHeadless);
    setenv('SPHYNX_LOG_LEVEL', prevLog);
end

function [perPart, outlierStruct] = loadPreprocessSettings(config, log)
    % Returns (perPart, outlier). perPart is the Settings.bodyparts
    % struct array (or [] if nothing found). outlier is the
    % Settings.outlier struct (or [] if nothing found / missing field).
    %
    % Explicit cfg.paths.preprocessSettings wins; otherwise we walk
    % up from the DLC dir for up to 4 levels looking for the first
    % *_PreprocessSettings.mat. The same loader serves single-session
    % analyzeSession AND batch (Batch tab calls analyzeSession per
    % session, so the auto-discovery runs per session and naturally
    % picks up the experiment-level settings file).
    perPart = [];
    outlierStruct = [];

    explicit = '';
    if isfield(config.paths, 'preprocessSettings')
        explicit = config.paths.preprocessSettings;
    end

    if ~isempty(explicit) && isfile(explicit)
        try
            S = sphynx.io.readTracksSettings(explicit);
            perPart = S.bodyparts;
            if isfield(S, 'outlier'); outlierStruct = S.outlier; end
            log('info', 'Loaded preprocess settings: %s (%d parts%s)', ...
                explicit, numel(perPart), ifEmpty(outlierTag(outlierStruct), ''));
            return;
        catch ME
            log('warn', 'preprocessSettings read failed (%s): %s', ...
                explicit, ME.message);
        end
    end

    if isempty(config.paths.dlc); return; end
    d = fileparts(config.paths.dlc);
    for hop = 1:4
        if isempty(d) || ~isfolder(d); break; end
        hits = dir(fullfile(d, '*_PreprocessSettings.mat'));
        if ~isempty(hits)
            cand = fullfile(hits(1).folder, hits(1).name);
            try
                S = sphynx.io.readTracksSettings(cand);
                perPart = S.bodyparts;
                if isfield(S, 'outlier'); outlierStruct = S.outlier; end
                log('info', 'Auto-loaded preprocess settings: %s (%d parts%s)', ...
                    cand, numel(perPart), ifEmpty(outlierTag(outlierStruct), ''));
                return;
            catch ME
                log('warn', 'Skipping %s: %s', cand, ME.message);
            end
        end
        parent = fileparts(d);
        if strcmp(parent, d); break; end
        d = parent;
    end
end

function tag = outlierTag(outlier)
    tag = '';
    if isempty(outlier) || ~isstruct(outlier); return; end
    parts = {};
    if isfield(outlier, 'velocityJump') && isfield(outlier.velocityJump, 'enabled') ...
            && outlier.velocityJump.enabled
        parts{end+1} = 'vj';
    end
    if isfield(outlier, 'hampel') && isfield(outlier.hampel, 'enabled') ...
            && outlier.hampel.enabled
        parts{end+1} = 'hampel';
    end
    if ~isempty(parts)
        tag = sprintf(', outlier=%s', strjoin(parts, '+'));
    end
end

function s = resolvePartSettings(perPart, partName, config)
    % Build the settings struct expected by applyPerPartSettings.
    % Per-part Settings.bodyparts row wins; falls back to defaults
    % from sphynx.preprocess.perPartDefault, finally to config-level
    % scalars (likelihoodThreshold / interpolationMethod) so legacy
    % callers without a Settings .mat still work.
    base = sphynx.preprocess.perPartDefault(partName, config);
    % `use` default true so a part without an explicit Settings row
    % still gets processed.
    base.use = true;

    s = base;
    if isempty(perPart); return; end
    idx = find(strcmpi({perPart.name}, partName), 1);
    if isempty(idx); return; end
    row = perPart(idx);
    % Override with whatever fields the saved row actually carries.
    fns = {'use', 'likelihoodThreshold', 'smoothWindowSec', ...
           'interpolationMethod', 'smoothingMethod', 'smoothingPolyOrder', ...
           'notFoundThresholdPct'};
    for k = 1:numel(fns)
        f = fns{k};
        if isfield(row, f) && ~isempty(row.(f))
            s.(f) = row.(f);
        end
    end
end

function [arr, keepIdx] = tryLoadPrepared(dlcPath, dlc, log)
    % Look for <dlcBase>_Preprocessed.mat next to the DLC csv. If found
    % and the bodypart names match, return the BodyPartsTraces array
    % directly with computed Velocity/AverageSpeed/AverageDistance left
    % blank (they are filled later in step 5).
    arr = []; keepIdx = [];
    [d, base, ~] = fileparts(dlcPath);
    p = fullfile(d, [base '_Preprocessed.mat']);
    if ~isfile(p); return; end
    s = load(p, 'BodyPartsTraces');
    if ~isfield(s, 'BodyPartsTraces') || isempty(s.BodyPartsTraces); return; end
    namesA = {s.BodyPartsTraces.BodyPartName};
    if numel(namesA) ~= numel(dlc.bodyPartsNames) || ~all(strcmp(namesA, dlc.bodyPartsNames))
        log('warn', 'Found %s but bodyparts schema differs — falling back to recompute', p);
        return;
    end
    log('info', 'Loaded preprocessed traces from %s', p);
    n = numel(s.BodyPartsTraces);
    arr = struct('BodyPartName', {}, 'TraceOriginal', {}, ...
        'TraceInterpolated', {}, 'TraceSmoothed', {}, 'Status', {}, ...
        'PercentNaN', {}, 'PercentLowLikelihood', {}, ...
        'Velocity', {}, 'VelocitySmoothed', {}, 'AverageSpeed', {}, ...
        'AverageDistance', {});
    keepIdx = false(1, n);
    for k = 1:n
        t = s.BodyPartsTraces(k);
        arr(k).BodyPartName = t.BodyPartName;
        arr(k).TraceOriginal = t.TraceOriginal;
        arr(k).TraceLikelihood = t.TraceLikelihood;
        arr(k).TraceInterpolated = t.TraceInterpolated;
        arr(k).TraceSmoothed = t.TraceSmoothed;
        arr(k).Status = t.Status;
        arr(k).PercentNaN = t.PercentNaN;
        arr(k).PercentLowLikelihood = t.PercentLowLikelihood;
        keepIdx(k) = ~strcmp(t.Status, 'NotFound');
    end
end

function v = ifEmpty(x, fallback)
    if isempty(x); v = fallback; else; v = x; end
end

function w = makeOdd(w)
    if w < 3, w = 3; end
    if mod(w, 2) == 0, w = w + 1; end
end

function v = clamp(x, lo, hi)
    v = x;
    v(v < lo) = lo;
    v(v > hi) = hi;
end

function v = getOpt(Options, name, default)
    if isfield(Options, name)
        v = Options.(name);
    else
        v = default;
    end
end

function tf = hasBarnesNoseActs(Acts)
    % True when the analyzeSession Acts array carries any
    % nose_at_object<N> entry -- the minimum signal Barnes session
    % metrics need to be meaningful. Built-in speed/posture acts and
    % standalone "rest" Make-video runs don't trip this guard.
    tf = false;
    if isempty(Acts); return; end
    for k = 1:numel(Acts)
        nm = lower(char(Acts(k).ActName));
        if startsWith(nm, 'nose_at_object')
            tf = true; return;
        end
    end
end

function w = pickSmoothWindow(partName, smallWin, bigWin)
    % Big-body-mass parts get the larger smoothing window. List mirrors
    % the synonyms recognised by sphynx.bodyparts.identifyParts so a DLC
    % schema using underscored names (mouse_center, tail_base, etc.)
    % gets the same smoothing as the bare-word legacy schema.
    bigParts = {'mass centre', 'mass center', ...
                'bodycenter', 'body center', 'body_center', ...
                'center', 'mouse_center', 'mouse center', ...
                'tailbase', 'tail base', 'tail_base', 'tail1'};
    if any(strcmpi(bigParts, partName))
        w = bigWin;
    else
        w = smallWin;
    end
end

function spec = legacyZoneActSpec()
    % { zoneName,                actName,    bodyPartName }
    %
    % Zone names match what sphynx.zones.classifySquare and
    % sphynx.preset.buildObjectZones actually produce in CreatePresetApp:
    %   classifySquare 'corners-walls-center':
    %     corners / walls / walls_and_corners / center /
    %     arena_realout / corners_realout / walls_realout /
    %     walls_and_corners_realout
    %   buildObjectZones (R8.4 lowercase):
    %     object1_real / object1_realout / object1_out / ... /
    %     objectall_real / objectall_realout / objectall_out
    %
    % If a zone isn't in the preset (e.g. object3_realout for a 2-object
    % session), the loop in step 9 silently skips it — no error.
    spec = {
        'corners_realout',        'corners',  'tailbase';
        'walls_realout',          'walls',    'tailbase';
        'center',                 'center',   'tailbase';
        'object1_realout',        'object1',  'nose';
        'object2_realout',        'object2',  'nose';
        'object3_realout',        'object3',  'nose';
        'object4_realout',        'object4',  'nose';
        'objectall_realout',      'objects',  'nose';
    };
end

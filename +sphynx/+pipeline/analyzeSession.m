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
    if autoStart && config.range.startFrame == 1
        dlcFull = sphynx.io.readDLC(config.paths.dlc, ...
            'EndFrame', config.range.endFrame);
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
        'EndFrame', config.range.endFrame);

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
        BodyPartsTraces = struct('BodyPartName', {}, 'TraceOriginal', {}, ...
            'TraceInterpolated', {}, 'TraceSmoothed', {}, 'Status', {}, ...
            'PercentNaN', {}, 'PercentLowLikelihood', {}, ...
            'Velocity', {}, 'VelocitySmoothed', {}, 'AverageSpeed', {}, ...
            'AverageDistance', {});
        keepIdx = false(1, nParts);

        for part = 1:nParts
            rawX = dlc.X(part, :)';
            rawY = dlc.Y(part, :)';
            lk = dlc.likelihood(part, :)';
            cleaned = sphynx.preprocess.cleanBodyPart(rawX, rawY, lk, ...
                'FrameWidth', Options.Width, ...
                'FrameHeight', Options.Height, ...
                'LikelihoodThreshold', config.preprocess.likelihoodThreshold);

            BodyPartsTraces(part).BodyPartName = dlc.bodyPartsNames{part};
            BodyPartsTraces(part).TraceOriginal.X = rawX;
            BodyPartsTraces(part).TraceOriginal.Y = rawY;
            BodyPartsTraces(part).TraceLikelihood = lk;
            BodyPartsTraces(part).PercentNaN = cleaned.PercentNaN;
            BodyPartsTraces(part).PercentLowLikelihood = cleaned.PercentLowLikelihood;
            BodyPartsTraces(part).Status = cleaned.Status;

            if strcmp(cleaned.Status, 'NotFound')
                log('warn', 'BodyPart "%s" status NotFound, skipping', dlc.bodyPartsNames{part});
                continue;
            end
            keepIdx(part) = true;

            % Interpolate gaps
            intX = sphynx.preprocess.interpolateGaps(cleaned.X, 'Method', config.preprocess.interpolationMethod);
            intY = sphynx.preprocess.interpolateGaps(cleaned.Y, 'Method', config.preprocess.interpolationMethod);
            % Clamp to frame bounds (legacy behavior)
            intX = clamp(intX, 1, Options.Width);
            intY = clamp(intY, 1, Options.Height);
            BodyPartsTraces(part).TraceInterpolated.X = intX;
            BodyPartsTraces(part).TraceInterpolated.Y = intY;

            % Smooth (bigger window for body-center / tailbase)
            win = pickSmoothWindow(dlc.bodyPartsNames{part}, smallWin, bigWin);
            smX = sphynx.preprocess.smoothTrace(intX, win);
            smY = sphynx.preprocess.smoothTrace(intY, win);
            BodyPartsTraces(part).TraceSmoothed.X = smX;
            BodyPartsTraces(part).TraceSmoothed.Y = smY;
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
        Acts(line).FirstStartSec   = s.FirstStartSec;
        Acts(line).FirstEndSec     = s.FirstEndSec;
        Acts(line).LastStartSec    = s.LastStartSec;
        Acts(line).LastEndSec      = s.LastEndSec;
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

function w = pickSmoothWindow(partName, smallWin, bigWin)
    bigParts = {'mass centre', 'mass center', 'bodycenter', 'center', ...
                'tailbase', 'tail base'};
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

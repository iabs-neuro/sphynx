function outPath = renderActsVideo(result, videoPath, outDir, varargin)
% RENDERACTSVIDEO  Write an mp4 with each frame annotated by which acts
% are currently active and where the body parts are.
%
%   outPath = sphynx.pipeline.renderActsVideo(result, videoPath, outDir, ...)
%
% Inputs:
%   result    - struct from sphynx.pipeline.analyzeSession
%   videoPath - source mp4
%   outDir    - destination dir; output is <outDir>/<videobase>_acts.mp4
%
% Optional name-value:
%   'FrameRate' - output fps (default = source fps)
%   'Range'     - [startFrame endFrame] (default whole video)
%   'Quality'   - 1..100 (default 75)
%   'Overlay'   - 'minimal' | 'full' (default 'full'); kept for back-compat
%   'Features'  - struct with optional fields (all true by default):
%                   trajectory (running bodycenter trail)
%                   velocity   (current speed in cm/s, top-right)
%                   actsList   (vertical list of active acts, top-left)
%                   zones      (highlight zones containing the bodycenter)
%                 'minimal' Overlay sets every flag false; 'full' true.
%   'ProgressFcn' - fcn(0..1, msg) called periodically

    p = inputParser;
    p.addRequired('result');
    p.addRequired('videoPath', @(s) ischar(s) || isstring(s));
    p.addRequired('outDir', @(s) ischar(s) || isstring(s));
    p.addParameter('FrameRate', [], @(v) isempty(v) || isnumeric(v));
    p.addParameter('Range', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    p.addParameter('Quality', 75, @(v) isnumeric(v) && v > 0 && v <= 100);
    p.addParameter('Overlay', 'full', @(s) any(strcmp(s, {'minimal', 'full'})));
    p.addParameter('Features', [], @(s) isempty(s) || isstruct(s));
    p.addParameter('OutputName', '', @(s) ischar(s) || isstring(s));
    p.addParameter('ProgressFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));
    parse(p, result, videoPath, outDir, varargin{:});

    % Resolve feature flags. Explicit Features struct overrides Overlay.
    fdef = struct('trajectory', true, 'velocity', true, ...
                  'actsList', true, 'zones', true, ...
                  'presentation', false);
    if strcmp(p.Results.Overlay, 'minimal')
        fdef = structfun(@(~) false, fdef, 'UniformOutput', false);
    end
    feat = mergeStruct(fdef, p.Results.Features);

    if ~isfile(videoPath)
        error('sphynx:renderActsVideo:videoNotFound', '%s', videoPath);
    end
    if ~isfolder(outDir); mkdir(outDir); end
    [~, base, ~] = fileparts(videoPath);
    outName = char(p.Results.OutputName);
    if isempty(outName); outName = [base '_acts.mp4']; end
    if ~endsWith(lower(outName), '.mp4'); outName = [outName '.mp4']; end
    outPath = fullfile(outDir, outName);

    reader = VideoReader(videoPath);
    fps = reader.FrameRate;
    if ~isempty(p.Results.FrameRate); fps = p.Results.FrameRate; end
    nFrames = min(reader.NumFrames, result.n_frames);

    range = p.Results.Range;
    if isempty(range); range = [1 nFrames]; end
    range(1) = max(1, range(1));
    range(2) = min(nFrames, range(2));

    writer = VideoWriter(outPath, 'MPEG-4');
    writer.FrameRate = fps;
    writer.Quality = p.Results.Quality;
    open(writer);
    cleaner = onCleanup(@() close(writer));

    % Acts as Nx(nFrames) logical
    nActs = numel(result.Acts);
    actMat = false(nActs, nFrames);
    for k = 1:nActs
        a = result.Acts(k).ActArrayRefine;
        if numel(a) >= nFrames
            actMat(k, :) = logical(a(1:nFrames));
        end
    end
    actNames = {result.Acts.ActName};
    actColors = lines(max(1, nActs));

    % Visual style. `presentation` swaps three elements to a bolder,
    % cleaner look for slide decks; everything else is unchanged.
    pres = isfield(feat, 'presentation') && feat.presentation;
    % Optional presentation tuning knobs (let sample clips sweep without
    % code edits; all default to the tuned baseline when absent):
    %   presScale      - uniform font/step scale (1.0 baseline)
    %   presSpacingMul - extra multiplier on label spacing only
    %   presTrajMul    - extra multiplier on trajectory line width
    %   presZoneAlpha  - explicit zone-fill FaceAlpha override
    presScale      = optNum(feat, pres, 'presScale', 1.0);
    presSpacingMul = optNum(feat, pres, 'presSpacingMul', 1.0);
    presTrajMul    = optNum(feat, pres, 'presTrajMul', 1.0);
    if pres
        % Baseline = user-approved look (2026-05-19): font60, trajectory
        % LW 5.25, label spacing x1.5, zone alpha 0.075. Knobs default to
        % 1.0 so the GUI checkbox alone reproduces exactly this.
        trajColor = [0 0.30 0];   trajLW = 5.25 * presTrajMul;
        zoneLW = 2.5;   zoneAlpha = 0.075;
        speedFont = round(48 * presScale);
        subFont   = round(43 * presScale);   % Speed_act / Zone / Acts:
        actsFont  = round(60 * presScale);   % act item names
        panelDy   = round(101 * presScale * presSpacingMul); % Speed/.../Zone step
        actsDy    = round(120 * presScale * presSpacingMul); % acts list step
        if isfield(feat, 'presZoneAlpha') && isnumeric(feat.presZoneAlpha) ...
                && isscalar(feat.presZoneAlpha) && feat.presZoneAlpha >= 0
            zoneAlpha = feat.presZoneAlpha;
        end
    else
        trajColor = [0.10 0.50 0.90]; trajLW = 1.2;
        zoneLW = 1.2;   zoneAlpha = 0.20;
        speedFont = 18;  subFont = 16;  actsFont = 15;
        panelDy   = 26;  actsDy  = 26;
    end

    % Body parts
    bps = result.BodyPartsTraces;
    nBP = numel(bps);
    bpColors = parula(max(1, nBP));
    % Bodycenter index (used by trajectory trail + velocity readout).
    bcIdx = find(strcmpi({bps.BodyPartName}, 'bodycenter'), 1);
    if isempty(bcIdx); bcIdx = 1; end
    centerX = []; centerY = []; centerVel = [];
    if isfield(bps(bcIdx), 'TraceSmoothed') && ~isempty(bps(bcIdx).TraceSmoothed)
        centerX = bps(bcIdx).TraceSmoothed.X;
        centerY = bps(bcIdx).TraceSmoothed.Y;
    end
    if isfield(bps(bcIdx), 'VelocitySmoothed')
        centerVel = bps(bcIdx).VelocitySmoothed;
    end
    % Zones for the optional zone overlay.
    zones = [];
    if isfield(result, 'Zones'); zones = result.Zones; end

    % Bucket each act by name into speed / spatial / posture /
    % composite. The overlay treats the buckets differently:
    %   speed   -> "Speed_act:" line, NOT shown in Acts list.
    %   spatial -> "Zone:" line, NOT shown in Acts list.
    %   rest    -> stacked under "Acts:".
    actBuckets = cell(1, nActs);
    for k = 1:nActs
        actBuckets{k} = sphynx.util.actBucket(actNames{k});
    end

    % Pre-resolve per-frame: which speed-act is active, which spatial
    % acts are active, and the union of zone masks for currently
    % active acts (used for the on-frame zone tint).
    speedActMap     = repmat({''}, 1, nFrames);
    spatialActsMap  = cell(1, nFrames);
    spatialActsMap(:) = {{}};
    activeZoneMaskByFrame = cell(1, nFrames);

    % Build per-act zone-mask union once. result.Acts(k).Definition.zones
    % is a cellstr of zone names; resolve via the preset zones list.
    actZoneMasks = cell(1, nActs);
    if ~isempty(zones)
        for k = 1:nActs
            actZones = {};
            try
                if isfield(result.Acts(k), 'Definition') ...
                        && isfield(result.Acts(k).Definition, 'zones')
                    actZones = result.Acts(k).Definition.zones;
                end
            catch; end
            if isempty(actZones); continue; end
            if ischar(actZones); actZones = {actZones}; end
            mask = [];
            for zi = 1:numel(actZones)
                zIdx = find(strcmp({zones.name}, actZones{zi}), 1);
                if isempty(zIdx); continue; end
                if isfield(zones(zIdx), 'maskfilled') ...
                        && ~isempty(zones(zIdx).maskfilled)
                    m = logical(zones(zIdx).maskfilled);
                    if isempty(mask); mask = m; else; mask = mask | m; end
                end
            end
            actZoneMasks{k} = mask;
        end
    end

    for f = range(1):range(2)
        if f > nFrames; break; end
        active = find(actMat(:, f));
        unionMask = [];
        for jj = 1:numel(active)
            k = active(jj);
            switch actBuckets{k}
                case 'speed'
                    speedActMap{f} = actNames{k};
                case 'spatial'
                    spatialActsMap{f} = [spatialActsMap{f}, actNames(k)];
            end
            m = actZoneMasks{k};
            if ~isempty(m)
                if isempty(unionMask); unionMask = m;
                else; unionMask = unionMask | m; end
            end
        end
        activeZoneMaskByFrame{f} = unionMask;
    end

    % Off-screen render via figure
    fig = figure('Visible', 'off', 'Position', [100 100 reader.Width reader.Height]);
    cleanerFig = onCleanup(@() closeIfValid(fig));
    ax = axes(fig, 'Position', [0 0 1 1]);
    axis(ax, 'off'); ax.YDir = 'reverse';

    progress = p.Results.ProgressFcn;
    nOut = range(2) - range(1) + 1;
    for f = range(1):range(2)
        try
            img = read(reader, f);
        catch
            continue;
        end
        cla(ax);
        imshow(img, 'Parent', ax); hold(ax, 'on');

        % Zone tint — fill ONLY the zones referenced by currently
        % active acts (act.Definition.zones). Preset zones that
        % aren't tied to any active act are not drawn.
        if feat.zones && f <= numel(activeZoneMaskByFrame) ...
                && ~isempty(activeZoneMaskByFrame{f})
            B = bwboundaries(activeZoneMaskByFrame{f});
            for bb = 1:numel(B)
                fill(ax, B{bb}(:,2), B{bb}(:,1), [1 0.7 0], ...
                    'FaceAlpha', zoneAlpha, 'EdgeColor', [1 0.5 0], ...
                    'LineWidth', zoneLW);
            end
        end

        % Trajectory trail — bodycenter from range(1) up to current f.
        if feat.trajectory && ~isempty(centerX)
            t1 = range(1); t2 = min(f, numel(centerX));
            plot(ax, centerX(t1:t2), centerY(t1:t2), '-', ...
                'Color', trajColor, 'LineWidth', trajLW);
        end

        % Body part dots — always (BA-style).
        for b = 1:nBP
            if isfield(bps(b), 'TraceSmoothed') && ~isempty(bps(b).TraceSmoothed)
                x = bps(b).TraceSmoothed.X(min(f, end));
                y = bps(b).TraceSmoothed.Y(min(f, end));
                if isfinite(x) && isfinite(y)
                    plot(ax, x, y, 'o', 'MarkerSize', 6, ...
                        'MarkerEdgeColor', bpColors(b, :), ...
                        'MarkerFaceColor', bpColors(b, :));
                end
            end
        end

        % Structured info block on the LEFT side, big font:
        %   Speed: 12.3 cm/s
        %   Speed_act: locomotion
        %   Zone: walls, corners
        %   Acts:
        %     freezing
        %     object1
        %     ...
        x0 = 12;          % left margin
        y0 = 28;          % first baseline
        dy = panelDy;     % line height (Speed/Speed_act/Zone)
        if feat.velocity && ~isempty(centerVel) && f <= numel(centerVel) ...
                && isfinite(centerVel(f))
            text(ax, x0, y0, sprintf('Speed: %.1f cm/s', centerVel(f)), ...
                'Color', 'w', 'FontSize', speedFont, 'FontWeight', 'bold', ...
                'BackgroundColor', [0 0 0 0.55]);
            y0 = y0 + dy;
            spAct = '';
            if f <= numel(speedActMap); spAct = speedActMap{f}; end
            if isempty(spAct); spAct = '—'; end
            text(ax, x0, y0, sprintf('Speed_act: %s', spAct), ...
                'Color', 'w', 'FontSize', subFont, 'FontWeight', 'bold', ...
                'Interpreter', 'none', ...
                'BackgroundColor', [0 0 0 0.55]);
            y0 = y0 + dy;
        end
        spatialList = {};
        if f <= numel(spatialActsMap); spatialList = spatialActsMap{f}; end
        if feat.zones
            zname = '—';
            if ~isempty(spatialList); zname = strjoin(spatialList, ', '); end
            text(ax, x0, y0, sprintf('Zone: %s', zname), ...
                'Color', 'w', 'FontSize', subFont, 'FontWeight', 'bold', ...
                'Interpreter', 'none', ...
                'BackgroundColor', [0 0 0 0.55]);
            y0 = y0 + dy;
        end
        if feat.actsList
            text(ax, x0, y0, 'Acts:', ...
                'Color', 'w', 'FontSize', subFont, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0 0 0 0.55]);
            y0 = y0 + actsDy;
            % Skip acts that already appear under Speed_act / Zone.
            shownInfo = [{speedActMap{f}}, spatialList];
            shownInfo = shownInfo(~cellfun(@isempty, shownInfo));
            active = find(actMat(:, f));
            for j = 1:numel(active)
                k = active(j);
                if any(strcmp(actNames{k}, shownInfo)); continue; end
                text(ax, x0 + max(18, round(actsFont * 0.5)), y0, actNames{k}, ...
                    'Color', actColors(k, :), 'FontSize', actsFont, ...
                    'FontWeight', 'bold', 'Interpreter', 'none', ...
                    'BackgroundColor', [0 0 0 0.55]);
                y0 = y0 + actsDy - 4;
            end
        end

        frame = getframe(ax);
        writeVideo(writer, frame);

        if ~isempty(progress) && (mod(f, 30) == 0 || f == range(2))
            progress((f - range(1) + 1) / nOut, sprintf('Rendering frame %d / %d', f - range(1) + 1, nOut));
        end
    end
end

function closeIfValid(h)
    if ~isempty(h) && isvalid(h); close(h); end
end

function v = optNum(feat, enabled, name, default)
    % Read an optional positive scalar numeric tuning knob from `feat`.
    v = default;
    if enabled && isfield(feat, name) && isnumeric(feat.(name)) ...
            && isscalar(feat.(name)) && feat.(name) > 0
        v = feat.(name);
    end
end

function out = mergeStruct(defaults, override)
    out = defaults;
    if isempty(override); return; end
    fns = fieldnames(override);
    for k = 1:numel(fns)
        out.(fns{k}) = override.(fns{k});
    end
end


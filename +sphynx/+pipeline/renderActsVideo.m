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
    p.addParameter('ProgressFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));
    parse(p, result, videoPath, outDir, varargin{:});

    % Resolve feature flags. Explicit Features struct overrides Overlay.
    fdef = struct('trajectory', true, 'velocity', true, ...
                  'actsList', true, 'zones', true);
    if strcmp(p.Results.Overlay, 'minimal')
        fdef = structfun(@(~) false, fdef, 'UniformOutput', false);
    end
    feat = mergeStruct(fdef, p.Results.Features);

    if ~isfile(videoPath)
        error('sphynx:renderActsVideo:videoNotFound', '%s', videoPath);
    end
    if ~isfolder(outDir); mkdir(outDir); end
    [~, base, ~] = fileparts(videoPath);
    outPath = fullfile(outDir, [base '_acts.mp4']);

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

        % Optional zone tint — half-transparent fill of zones the
        % bodycenter sits in right now.
        if feat.zones && ~isempty(zones) && ~isempty(centerX) && f <= numel(centerX)
            cx = round(centerX(f)); cy = round(centerY(f));
            for zk = 1:numel(zones)
                if ~isfield(zones(zk), 'maskfilled') ...
                        || isempty(zones(zk).maskfilled); continue; end
                m = logical(zones(zk).maskfilled);
                [Hm, Wm] = size(m);
                if cx<1||cy<1||cx>Wm||cy>Hm; continue; end
                if ~m(cy, cx); continue; end
                B = bwboundaries(m);
                for bb = 1:numel(B)
                    fill(ax, B{bb}(:,2), B{bb}(:,1), [1 0.7 0], ...
                        'FaceAlpha', 0.20, 'EdgeColor', [1 0.5 0], ...
                        'LineWidth', 1.2);
                end
            end
        end

        % Trajectory trail — bodycenter from range(1) up to current f.
        if feat.trajectory && ~isempty(centerX)
            t1 = range(1); t2 = min(f, numel(centerX));
            plot(ax, centerX(t1:t2), centerY(t1:t2), '-', ...
                'Color', [0.10 0.50 0.90], 'LineWidth', 1.2);
        end

        % Body part dots (always — gives the BA-style overlay).
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

        % Active acts as labels stacked top-left.
        if feat.actsList
            active = find(actMat(:, f));
            for j = 1:numel(active)
                k = active(j);
                text(ax, 10, 20 + (j-1) * 22, actNames{k}, ...
                    'Color', actColors(k, :), 'FontSize', 14, ...
                    'FontWeight', 'bold', 'Interpreter', 'none', ...
                    'BackgroundColor', [0 0 0 0.5]);
            end
        end

        % Velocity readout — top-right.
        if feat.velocity && ~isempty(centerVel) && f <= numel(centerVel) ...
                && isfinite(centerVel(f))
            text(ax, reader.Width - 10, 22, ...
                sprintf('%.1f cm/s', centerVel(f)), ...
                'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'right', ...
                'BackgroundColor', [0 0 0 0.5]);
        end

        % Thin acts timeline + playhead — kept on by default; tied to
        % actsList so 'minimal' suppresses both.
        if feat.actsList
            barH = max(1, round(reader.Height * 0.04));
            barY0 = reader.Height - barH * (nActs + 1);
            for k = 1:nActs
                yT = barY0 + (k-1) * barH;
                if actMat(k, f)
                    rectangle(ax, 'Position', [0, yT, reader.Width, barH-1], ...
                        'FaceColor', actColors(k, :), 'EdgeColor', 'none');
                end
            end
            xp = reader.Width * (f - range(1)) / max(1, nOut);
            line(ax, [xp xp], [barY0, reader.Height], 'Color', 'w', 'LineWidth', 1.5);
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

function out = mergeStruct(defaults, override)
    out = defaults;
    if isempty(override); return; end
    fns = fieldnames(override);
    for k = 1:numel(fns)
        out.(fns{k}) = override.(fns{k});
    end
end

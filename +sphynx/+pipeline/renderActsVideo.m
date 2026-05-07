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
%   'Overlay'   - 'minimal' | 'full' (default 'full' — points + text)
%   'ProgressFcn' - fcn(0..1, msg) called periodically
%
% The overlay shows:
%   * smoothed body-part dots (one color per part).
%   * for each currently-active act, a colored badge with the name in
%     the top-left corner.
%   * a thin acts-timeline at the bottom with a vertical playhead.

    p = inputParser;
    p.addRequired('result');
    p.addRequired('videoPath', @(s) ischar(s) || isstring(s));
    p.addRequired('outDir', @(s) ischar(s) || isstring(s));
    p.addParameter('FrameRate', [], @(v) isempty(v) || isnumeric(v));
    p.addParameter('Range', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    p.addParameter('Quality', 75, @(v) isnumeric(v) && v > 0 && v <= 100);
    p.addParameter('Overlay', 'full', @(s) any(strcmp(s, {'minimal', 'full'})));
    p.addParameter('ProgressFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));
    parse(p, result, videoPath, outDir, varargin{:});

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

        if strcmp(p.Results.Overlay, 'full')
            % Body part dots
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

            % Active acts as labels stacked top-left
            active = find(actMat(:, f));
            for j = 1:numel(active)
                k = active(j);
                text(ax, 10, 20 + (j-1) * 22, actNames{k}, ...
                    'Color', actColors(k, :), 'FontSize', 14, ...
                    'FontWeight', 'bold', 'Interpreter', 'none', ...
                    'BackgroundColor', [0 0 0 0.5]);
            end

            % Thin acts timeline at the bottom
            barH = max(1, round(reader.Height * 0.04));
            barY0 = reader.Height - barH * (nActs + 1);
            for k = 1:nActs
                yT = barY0 + (k-1) * barH;
                if actMat(k, f)
                    rectangle(ax, 'Position', [0, yT, reader.Width, barH-1], ...
                        'FaceColor', actColors(k, :), 'EdgeColor', 'none');
                end
            end
            % Playhead
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

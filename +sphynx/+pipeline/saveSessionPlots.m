function paths = saveSessionPlots(result, outDir, varargin)
% SAVESESSIONPLOTS  Write the session-wide overview plots that the
% Analyze Session tab shows on screen (trajectory over GoodVideoFrame,
% occupancy heatmap, speed histogram, speed vs time) to PNG + FIG
% files.
%
%   paths = sphynx.pipeline.saveSessionPlots(result, outDir, ...)
%
% Inputs:
%   result  - struct from sphynx.pipeline.analyzeSession
%   outDir  - destination dir; created if missing.
%
% Optional name-value:
%   'HeatmapBinCm' - bin size for the occupancy heatmap (default 4).
%   'Prefix'       - filename prefix; default '' produces e.g.
%                    'trajectory.png'. Pass 'foo_' to get 'foo_trajectory.png'.
%
% Files written (PNG + FIG for each):
%   <prefix>trajectory      bodycenter trace over GoodVideoFrame, cm.
%   <prefix>heatmap         occupancy in seconds, gaussian-smoothed.
%   <prefix>speed_histogram bodycenter speed distribution, 150 bins.
%   <prefix>speed_vs_time   bodycenter speed trace.
%
% Returns paths.<which> with each saved PNG path.

    p = inputParser;
    p.addRequired('result');
    p.addRequired('outDir', @(s) ischar(s) || isstring(s));
    p.addParameter('HeatmapBinCm', 4, @(v) isnumeric(v) && v > 0);
    p.addParameter('Prefix', '', @(s) ischar(s) || isstring(s));
    parse(p, result, outDir, varargin{:});
    outDir = char(outDir);
    prefix = char(p.Results.Prefix);
    if ~isfolder(outDir); mkdir(outDir); end
    paths = struct();

    bps = result.BodyPartsTraces;
    bcIdx = find(strcmpi({bps.BodyPartName}, 'bodycenter'), 1);
    if isempty(bcIdx); bcIdx = 1; end
    pxlPerCm = 1;
    if isfield(result, 'Options') && isfield(result.Options, 'pxl2sm')
        pxlPerCm = result.Options.pxl2sm;
    end
    fps = 30;
    if isfield(result, 'Options') && isfield(result.Options, 'FrameRate')
        fps = result.Options.FrameRate;
    end
    frame = [];
    if isfield(result, 'Options')
        for fld = {'GoodVideoFrame', 'GoodVideoFrameGray'}
            if isfield(result.Options, fld{1}) ...
                    && ~isempty(result.Options.(fld{1}))
                frame = result.Options.(fld{1}); break;
            end
        end
    end

    X = []; Y = []; v = [];
    if isfield(bps(bcIdx), 'TraceSmoothed') && ~isempty(bps(bcIdx).TraceSmoothed)
        X = bps(bcIdx).TraceSmoothed.X(:);
        Y = bps(bcIdx).TraceSmoothed.Y(:);
    end
    if isfield(bps(bcIdx), 'VelocitySmoothed')
        v = bps(bcIdx).VelocitySmoothed(:);
    end
    xCm = X / pxlPerCm; yCm = Y / pxlPerCm;
    bpName = bps(bcIdx).BodyPartName;

    % --- Trajectory over GoodVideoFrame, cm axes -----------------------
    paths.trajectory = save2(outDir, [prefix 'trajectory'], @() ...
        renderTrajectory(frame, xCm, yCm, pxlPerCm, bpName));

    % --- Occupancy heatmap (seconds, gaussian-smoothed) ---------------
    paths.heatmap = save2(outDir, [prefix 'heatmap'], @() ...
        renderHeatmap(xCm, yCm, result, p.Results.HeatmapBinCm, fps));

    % --- Speed histogram ---------------------------------------------
    paths.speed_histogram = save2(outDir, [prefix 'speed_histogram'], @() ...
        renderSpeedHistogram(v, bpName));

    % --- Speed vs time -----------------------------------------------
    paths.speed_vs_time = save2(outDir, [prefix 'speed_vs_time'], @() ...
        renderSpeedTrace(v, fps, bpName));
end

function pngPath = save2(outDir, base, makeFigFcn)
    fig = makeFigFcn();
    pngPath = fullfile(outDir, [base '.png']);
    figPath = fullfile(outDir, [base '.fig']);
    try
        saveas(fig, pngPath);
        saveas(fig, figPath);
    catch
        pngPath = '';
    end
    close(fig);
end

function fig = renderTrajectory(frame, xCm, yCm, pxlPerCm, bpName)
    fig = figure('Visible', 'off', 'Position', [100 100 800 700]);
    ax = axes('Parent', fig);
    if ~isempty(frame)
        imshow(frame, 'Parent', ax, ...
            'XData', [0 size(frame,2)/pxlPerCm], ...
            'YData', [0 size(frame,1)/pxlPerCm]);
        hold(ax, 'on');
    end
    plot(ax, xCm, yCm, '-', 'Color', [0.10 0.50 0.90], 'LineWidth', 1.2);
    ax.DataAspectRatio = [1 1 1];
    ax.YDir = 'reverse';
    if ~isempty(frame)
        ax.XLim = [0 size(frame,2)/pxlPerCm];
        ax.YLim = [0 size(frame,1)/pxlPerCm];
    end
    xlabel(ax, 'X, cm', 'FontSize', 14);
    ylabel(ax, 'Y, cm', 'FontSize', 14);
    ax.FontSize = 13;
    title(ax, sprintf('Trajectory (%s)', bpName), ...
        'Interpreter', 'none', 'FontSize', 15);
end

function fig = renderHeatmap(xCm, yCm, result, binCm, fps)
    fig = figure('Visible', 'off', 'Position', [100 100 800 700]);
    ax = axes('Parent', fig);
    extentX = max(xCm); extentY = max(yCm);
    if isfield(result, 'Options') ...
            && isfield(result.Options, 'pxl2sm') ...
            && isfield(result.Options, 'Width') ...
            && isfield(result.Options, 'Height')
        extentX = result.Options.Width  / result.Options.pxl2sm;
        extentY = result.Options.Height / result.Options.pxl2sm;
    end
    edgesX = 0:binCm:max(extentX, binCm);
    edgesY = 0:binCm:max(extentY, binCm);
    valid = isfinite(xCm) & isfinite(yCm);
    counts = histcounts2(xCm(valid), yCm(valid), edgesX, edgesY);
    secs = counts / fps;
    secsSmooth = imgaussfilt(secs, 1);
    imagesc(ax, edgesX, edgesY, secsSmooth');
    ax.YDir = 'reverse';
    colormap(ax, 'parula');
    cb = colorbar(ax);
    cb.Label.String = 'time, s';
    cb.Label.FontSize = 14;
    cb.FontSize = 12;
    ax.DataAspectRatio = [1 1 1];
    ax.XLim = [0 extentX]; ax.YLim = [0 extentY];
    xlabel(ax, 'X, cm', 'FontSize', 14);
    ylabel(ax, 'Y, cm', 'FontSize', 14);
    ax.FontSize = 13;
    title(ax, sprintf('Occupancy (%g cm bins, gaussian σ=1 bin)', binCm), ...
        'FontSize', 15);
end

function fig = renderSpeedHistogram(v, bpName)
    fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
    ax = axes('Parent', fig);
    if ~isempty(v) && any(isfinite(v))
        histogram(ax, v(isfinite(v)), 150, ...
            'FaceColor', [0.30 0.70 0.30], 'EdgeColor', 'none');
    end
    xlabel(ax, 'speed, cm/s', 'FontSize', 14);
    ylabel(ax, 'frames', 'FontSize', 14);
    ax.FontSize = 13;
    title(ax, sprintf('Speed histogram (%s)', bpName), ...
        'Interpreter', 'none', 'FontSize', 15);
end

function fig = renderSpeedTrace(v, fps, bpName)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 400]);
    ax = axes('Parent', fig);
    if ~isempty(v)
        if isfinite(fps)
            t = (0:numel(v)-1)' / fps;
            plot(ax, t, v, '-', 'Color', [0.30 0.55 0.85], 'LineWidth', 0.8);
            xlabel(ax, 'time, s', 'FontSize', 14);
        else
            plot(ax, 1:numel(v), v, '-', 'Color', [0.30 0.55 0.85], 'LineWidth', 0.8);
            xlabel(ax, 'frame', 'FontSize', 14);
        end
        ylabel(ax, 'speed, cm/s', 'FontSize', 14);
    end
    ax.FontSize = 13;
    title(ax, sprintf('Speed vs time (%s)', bpName), ...
        'Interpreter', 'none', 'FontSize', 15);
end

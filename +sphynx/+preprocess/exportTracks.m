function paths = exportTracks(state, opts)
% EXPORTTRACKS  Save per-experiment Settings + per-session traces + plots.
%
%   paths = sphynx.preprocess.exportTracks(state, opts)
%
%   Inputs:
%     state - struct with fields perPart, processed, manualRegions,
%             outlier, dlc, paths.dlc, paths.video, paths.preset, paths.root
%     opts  - struct with fields:
%               outputDir   - target directory; per-session file goes here
%               savePlots   - logical, whether to write per-part PNGs
%               experimentName - char for metadata
%
%   Returns paths struct:
%     paths.settings   - per-experiment .mat
%     paths.session    - per-session .mat
%     paths.plotsDir   - directory containing per-part PNGs (or '')

    if ~isfield(opts, 'outputDir') || isempty(opts.outputDir)
        error('sphynx:exportTracks:missingOutputDir', ...
            'opts.outputDir is required');
    end
    if ~isfolder(opts.outputDir); mkdir(opts.outputDir); end

    % Pick a base name from the DLC path
    [~, dlcBase, ~] = fileparts(state.paths.dlc);
    if isempty(dlcBase); dlcBase = 'session'; end

    % Per-experiment settings live next to the project root if known,
    % otherwise alongside the per-session file.
    expName = '';
    settingsDir = opts.outputDir;
    if isfield(state.paths, 'root') && ~isempty(state.paths.root) && isfolder(state.paths.root)
        settingsDir = state.paths.root;
        [~, expName, ~] = fileparts(state.paths.root);
    end
    if isempty(expName); expName = dlcBase; end

    paths.settings = fullfile(settingsDir, [expName '_PreprocessSettings.mat']);
    sphynx.io.writeTracksSettings(paths.settings, state.perPart, state.outlier, expName);

    % Per-session: BodyPartsTraces struct array
    BodyPartsTraces = buildTraces(state);
    ManualExclusionRegions = state.manualRegions; %#ok<NASGU>
    Source = struct( ...
        'dlcPath',      state.paths.dlc, ...
        'videoPath',    state.paths.video, ...
        'presetPath',   state.paths.preset, ...
        'settingsPath', paths.settings); %#ok<NASGU>

    paths.session = fullfile(opts.outputDir, [dlcBase '_Preprocessed.mat']);
    save(paths.session, 'BodyPartsTraces', 'ManualExclusionRegions', 'Source');

    % Per-part plots
    paths.plotsDir = '';
    if isfield(opts, 'savePlots') && opts.savePlots
        paths.plotsDir = fullfile(opts.outputDir, [dlcBase '_traces']);
        if ~isfolder(paths.plotsDir); mkdir(paths.plotsDir); end
        for i = 1:numel(BodyPartsTraces)
            tr = BodyPartsTraces(i);
            png = fullfile(paths.plotsDir, [tr.BodyPartName '.png']);
            renderTracePlot(tr, png);
        end
    end
end

function arr = buildTraces(state)
    n = numel(state.perPart);
    arr = struct('BodyPartName', {}, 'TraceOriginal', {}, 'TraceLikelihood', {}, ...
        'TraceInterpolated', {}, 'TraceSmoothed', {}, 'Status', {}, ...
        'PercentNaN', {}, 'PercentLowLikelihood', {}, 'PercentOutliersDetected', {}, ...
        'AppliedSettings', {});
    for i = 1:n
        name = state.perPart(i).name;
        rawX = state.dlc.X(i, :)';
        rawY = state.dlc.Y(i, :)';
        lk   = state.dlc.likelihood(i, :)';
        if i <= numel(state.processed) && ~isempty(state.processed(i).status)
            p = state.processed(i);
        else
            p = emptyProcessedRow(numel(rawX));
        end
        arr(i).BodyPartName = name;
        arr(i).TraceOriginal.X = rawX;
        arr(i).TraceOriginal.Y = rawY;
        arr(i).TraceLikelihood = lk;
        arr(i).TraceInterpolated.X = p.X_interp;
        arr(i).TraceInterpolated.Y = p.Y_interp;
        arr(i).TraceSmoothed.X = p.X_smooth;
        arr(i).TraceSmoothed.Y = p.Y_smooth;
        arr(i).Status = p.status;
        arr(i).PercentNaN = p.percentNaN;
        arr(i).PercentLowLikelihood = p.percentLowLikelihood;
        arr(i).PercentOutliersDetected = p.percentOutliers;
        arr(i).AppliedSettings = state.perPart(i);
    end
end

function p = emptyProcessedRow(n)
    p.X_interp = nan(n, 1);
    p.Y_interp = nan(n, 1);
    p.X_smooth = nan(n, 1);
    p.Y_smooth = nan(n, 1);
    p.status   = 'NotComputed';
    p.percentNaN = NaN;
    p.percentLowLikelihood = NaN;
    p.percentOutliers = NaN;
end

function renderTracePlot(tr, pngPath)
    fig = figure('Visible', 'off', 'Position', [50 50 1100 700]);
    cleaner = onCleanup(@() close(fig));
    n = numel(tr.TraceLikelihood);
    t = (1:n)';

    subplot(3, 1, 1); hold on;
    plot(t, tr.TraceOriginal.X,     'Color', [0.10 0.40 0.80], 'LineWidth', 1.0);
    plot(t, tr.TraceInterpolated.X, 'Color', [0.95 0.55 0.10], 'LineWidth', 0.9);
    plot(t, tr.TraceSmoothed.X,     'Color', [0.10 0.65 0.20], 'LineWidth', 0.9);
    title(sprintf('%s — X (px)', tr.BodyPartName), 'Interpreter', 'none');
    legend({'raw', 'interp', 'smoothed'}, 'Location', 'best');
    xlabel('frame'); ylabel('X, px'); grid on;

    subplot(3, 1, 2); hold on;
    plot(t, tr.TraceOriginal.Y,     'Color', [0.10 0.40 0.80], 'LineWidth', 1.0);
    plot(t, tr.TraceInterpolated.Y, 'Color', [0.95 0.55 0.10], 'LineWidth', 0.9);
    plot(t, tr.TraceSmoothed.Y,     'Color', [0.10 0.65 0.20], 'LineWidth', 0.9);
    title(sprintf('%s — Y (px)', tr.BodyPartName), 'Interpreter', 'none');
    xlabel('frame'); ylabel('Y, px'); grid on;

    subplot(3, 1, 3);
    histogram(tr.TraceLikelihood, 'BinWidth', 0.01, ...
        'FaceColor', [0.30 0.60 0.30], 'EdgeColor', 'none');
    title(sprintf('%s — likelihood', tr.BodyPartName), 'Interpreter', 'none');
    xlabel('likelihood'); ylabel('count'); xlim([0 1]); grid on;

    print(fig, pngPath, '-dpng', '-r120');
end

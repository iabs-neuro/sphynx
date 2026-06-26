classdef AnalyzeSessionTabController < handle
% ANALYZESESSIONTABCONTROLLER  Run analyzeSession on a single session
% from the GUI, tweak thresholds, and inspect results.
%
% MVP scope:
%   * Browse DLC / Preset / Output dir.
%   * Override config thresholds (rest, locomotion, freezing mode).
%   * Run pipeline -> populate result panel with act %s and trajectory.
%   * Plot trajectory + acts timeline + speed histogram.

    properties
        Tab
        Figure
        ParentApp

        % Loading (matches Define Acts: 6 buttons + editable path fields)
        RootPathField
        PresetPathField
        VideoPathField
        DLCPathField
        OutDirPathField
        ActsLibraryPathField
        RootButton
        PresetButton
        VideoButton
        DLCButton
        OutDirButton
        ActsLibraryButton
        PreprocessSettingsButton
        PreprocessSettingsPathField

        % Run + results (speed thresholds + freezing/rear modes
        % live in defaultConfig.m; the etogram bucket order is
        % computed from act-name patterns, no UI toggle.)
        RunButton
        SessionStatsLabel
        ResultTable

        % Plots
        TrajAxes
        HeatmapAxes
        TimelineAxes
        SpeedHistAxes
        SpeedTraceAxes

        % Etogram acts filter (R21)
        EtogramActsListBox

        % Output options — main video
        MainVideoEnableCheckbox
        MainVideoStartField
        MainVideoDurationField
        MainVideoTrajectoryCheckbox
        MainVideoVelocityCheckbox
        MainVideoActsListCheckbox
        MainVideoZonesCheckbox
        MainVideoPresentationCheckbox

        % Output options — per-act videos
        ActsVideoListBox
        ActsVideoDurationField

        % Output options — trajectory PNG+FIG plots
        PlotBodypartsCheckbox
        PlotSessionCheckbox

        % Heatmap bin size (cm)
        HeatmapBinField

        % Save/Load analysis settings
        RenderMainVideoButton
        RenderActsVideosButton
        SavePlotsButton
        SaveSettingsButton
        LoadSettingsButton

        % Log
        LogTextArea

        State
    end

    methods
        function obj = AnalyzeSessionTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('result', []);
            obj.buildUI();
        end

        function delete(~)
        end

        function runAnalyze(obj)
            cfg = sphynx.pipeline.defaultConfig();
            cfg.paths.dlc    = obj.DLCPathField.Value;
            cfg.paths.preset = obj.PresetPathField.Value;
            cfg.paths.video  = obj.VideoPathField.Value;
            % Session subfolder: per-session outputs all go into one
            % directory named after the video stem. Skip when there's
            % no output dir (saveWorkspace stays disabled then).
            if ~isempty(obj.OutDirPathField.Value)
                cfg.paths.outDir = obj.sessionDir();
            else
                cfg.paths.outDir = '';
            end
            % Rest/Loc thresholds + FreezingMode/RearMode use defaults
            % from defaultConfig.m. Per-experiment overrides will land
            % in Define Acts (see docs/TODO.md).
            if ~isempty(obj.ActsLibraryPathField) ...
                    && ~isempty(obj.ActsLibraryPathField.Value)
                cfg.acts.libraryPath = obj.ActsLibraryPathField.Value;
            end
            if ~isempty(obj.PreprocessSettingsPathField) ...
                    && ~isempty(obj.PreprocessSettingsPathField.Value)
                cfg.paths.preprocessSettings = obj.PreprocessSettingsPathField.Value;
            end
            cfg.io.saveWorkspace = ~isempty(cfg.paths.outDir);
            cfg.viz.headless = true;
            cfg.verbose = 'info';

            obj.applog('info', 'Running analyzeSession on %s ...', cfg.paths.dlc);
            try
                obj.State.result = sphynx.pipeline.analyzeSession(cfg);
            catch ME
                obj.applog('error', 'Run failed: %s', ME.message);
                return;
            end
            obj.applog('info', 'Done. %d frames, %d acts.', ...
                obj.State.result.n_frames, numel(obj.State.result.Acts));
            obj.refreshResults();
            obj.refreshActsVideoListBox();
        end

        function renderMainVideo(obj)
            if isempty(obj.State.result)
                obj.applog('warn', 'Run analyze first'); return;
            end
            if ~obj.MainVideoEnableCheckbox.Value
                obj.applog('warn', 'Main-video render is disabled in Options');
                return;
            end
            videoPath = obj.resolveVideoPath();
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Pick a video first (current: "%s")', ...
                    videoPath); return;
            end
            outDir = obj.sessionDir();
            startSec = obj.MainVideoStartField.Value;
            durSec   = obj.MainVideoDurationField.Value;
            fps = obj.State.result.Options.FrameRate;
            startF = max(1, round(startSec * fps) + 1);
            endF   = startF + max(1, round(durSec * fps)) - 1;
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Rendering main video', ...
                'Message', 'Starting...', 'Cancelable', 'off');
            cleaner = onCleanup(@() closeIfValid(dlg));
            feat = obj.collectMainVideoFeatures();
            [~, stem] = fileparts(videoPath);
            try
                outPath = sphynx.pipeline.renderActsVideo(obj.State.result, ...
                    videoPath, outDir, ...
                    'Range', [startF endF], ...
                    'Features', feat, ...
                    'OutputName', [stem '_main.mp4'], ...
                    'ProgressFcn', @(v, m) updateDlg(dlg, v, m));
                obj.applog('info', 'Main video saved: %s', outPath);
            catch ME
                obj.applog('error', 'Render failed: %s', ME.message);
            end
        end

        function feat = collectMainVideoFeatures(obj)
            feat = struct( ...
                'trajectory', obj.MainVideoTrajectoryCheckbox.Value, ...
                'velocity',   obj.MainVideoVelocityCheckbox.Value, ...
                'actsList',   obj.MainVideoActsListCheckbox.Value, ...
                'zones',      obj.MainVideoZonesCheckbox.Value, ...
                'presentation', obj.MainVideoPresentationCheckbox.Value);
        end

        function renderActsVideos(obj)
            % Per-act videos in the same BA-style as Define Acts'
            % Make-video / "Render & save all": stitched active frames,
            % stampCircle dots, hi-bodypart in red, event counter,
            % velocity readout. Streams via VideoWriter through the
            % shared sphynx.pipeline.renderActStitched.
            if isempty(obj.State.result)
                obj.applog('warn', 'Run analyze first'); return;
            end
            sel = obj.ActsVideoListBox.Value;
            if ischar(sel); sel = {sel}; end
            if isempty(sel)
                obj.applog('warn', 'Select acts to render in the Options panel');
                return;
            end
            videoPath = obj.resolveVideoPath();
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Pick a video first (current: "%s")', ...
                    videoPath); return;
            end
            actsDir = fullfile(obj.sessionDir(), 'Acts_video');
            if ~isfolder(actsDir); mkdir(actsDir); end
            durSec = obj.ActsVideoDurationField.Value;
            r = obj.State.result;
            presetData = [];
            try; presetData = sphynx.io.readPreset(obj.PresetPathField.Value); catch; end
            videoOffset = 0;
            try; videoOffset = r.config.range.startFrame - 1; catch; end

            dlg = uiprogressdlg(obj.Figure, ...
                'Title', 'Render acts videos', ...
                'Message', 'Starting...', 'Indeterminate', 'on', ...
                'Cancelable', 'on');
            cleaner = onCleanup(@() closeIfValid(dlg)); %#ok<NASGU>
            saved = 0;
            for k = 1:numel(sel)
                if dlg.CancelRequested; break; end
                actName = sel{k};
                dlg.Indeterminate = 'on';
                dlg.Message = sprintf('Locating %d/%d: %s', k, numel(sel), actName);
                try
                    outPath = sphynx.pipeline.renderActStitched( ...
                        r, videoPath, actsDir, actName, ...
                        'DurationSec', durSec, ...
                        'PresetData', presetData, ...
                        'VideoOffset', videoOffset, ...
                        'ProgressDlg', dlg);
                    if isempty(outPath)
                        obj.applog('info', '"%s" — 0 active frames, skip', actName);
                    else
                        saved = saved + 1;
                        obj.applog('info', '"%s" -> %s', actName, outPath);
                    end
                catch ME
                    obj.applog('warn', '"%s" failed: %s', actName, ME.message);
                end
            end
            obj.applog('info', 'Acts videos done: %d / %d -> %s', ...
                saved, numel(sel), actsDir);
        end

        function savePlots(obj)
            if isempty(obj.State.result)
                obj.applog('warn', 'Run analyze first'); return;
            end
            saveSession   = obj.PlotSessionCheckbox.Value;
            saveBodyparts = obj.PlotBodypartsCheckbox.Value;
            if ~saveSession && ~saveBodyparts
                obj.applog('warn', 'Both plot options are disabled');
                return;
            end
            sessRoot = obj.sessionDir();

            if saveSession
                try
                    sphynx.pipeline.saveSessionPlots(obj.State.result, ...
                        sessRoot, ...
                        'HeatmapBinCm', obj.HeatmapBinField.Value);
                    obj.applog('info', ...
                        'Session plots: trajectory/heatmap/speed PNG+FIG -> %s', sessRoot);
                catch ME
                    obj.applog('error', 'Session plots failed: %s', ME.message);
                end
            end

            if ~saveBodyparts; return; end
            plotsDir = fullfile(sessRoot, 'bodyparts_trajectory');
            if ~isfolder(plotsDir); mkdir(plotsDir); end
            r = obj.State.result;
            bps = r.BodyPartsTraces;
            pxlPerCm = 1;
            if isfield(r, 'Options') && isfield(r.Options, 'pxl2sm')
                pxlPerCm = r.Options.pxl2sm;
            end
            frame = [];
            if isfield(r, 'Options')
                for fld = {'GoodVideoFrame', 'GoodVideoFrameGray'}
                    if isfield(r.Options, fld{1}) && ~isempty(r.Options.(fld{1}))
                        frame = r.Options.(fld{1}); break;
                    end
                end
            end
            fps = 30;
            if isfield(r, 'Options') && isfield(r.Options, 'FrameRate')
                fps = r.Options.FrameRate;
            end
            saved = 0;
            for i = 1:numel(bps)
                bp = bps(i);
                if ~isfield(bp, 'TraceSmoothed') || isempty(bp.TraceSmoothed); continue; end
                X = bp.TraceSmoothed.X(:);
                Y = bp.TraceSmoothed.Y(:);
                if isempty(X); continue; end
                t = (0:numel(X)-1)' / fps;
                lk = [];
                if isfield(bp, 'TraceLikelihood') && ~isempty(bp.TraceLikelihood)
                    lk = bp.TraceLikelihood(:);
                end

                fig = figure('Visible', 'off', 'Position', [100 100 1000 1000]);
                tl = tiledlayout(fig, 4, 1, 'Padding', 'compact', ...
                    'TileSpacing', 'compact');

                % Top tile: 2D trajectory over GoodVideoFrame in cm.
                axT = nexttile(tl, 1);
                if ~isempty(frame)
                    imshow(frame, 'Parent', axT, ...
                        'XData', [0 size(frame,2)/pxlPerCm], ...
                        'YData', [0 size(frame,1)/pxlPerCm]);
                    hold(axT, 'on');
                end
                plot(axT, X/pxlPerCm, Y/pxlPerCm, '-', ...
                    'Color', [0.10 0.50 0.90], 'LineWidth', 1.2);
                axT.DataAspectRatio = [1 1 1];
                axT.YDir = 'reverse';
                xlabel(axT, 'X, cm', 'FontSize', 13);
                ylabel(axT, 'Y, cm', 'FontSize', 13);
                axT.FontSize = 12;
                title(axT, sprintf('Trajectory — %s', bp.BodyPartName), ...
                    'Interpreter', 'none', 'FontSize', 14);

                % Bottom three tiles: X(t), Y(t), likelihood(t).
                axX = nexttile(tl, 2);
                plot(axX, t, X/pxlPerCm, '-', 'Color', [0.85 0.40 0.20], ...
                    'LineWidth', 0.9);
                ylabel(axX, 'X, cm', 'FontSize', 13);
                axX.FontSize = 12; box(axX, 'on');

                axY = nexttile(tl, 3);
                plot(axY, t, Y/pxlPerCm, '-', 'Color', [0.20 0.65 0.30], ...
                    'LineWidth', 0.9);
                ylabel(axY, 'Y, cm', 'FontSize', 13);
                axY.FontSize = 12; box(axY, 'on');

                axL = nexttile(tl, 4);
                if ~isempty(lk)
                    plot(axL, t(1:numel(lk)), lk, '-', ...
                        'Color', [0.40 0.40 0.40], 'LineWidth', 0.9);
                    ylim(axL, [0 1]);
                else
                    text(axL, 0.5, 0.5, 'no likelihood trace', ...
                        'HorizontalAlignment', 'center', 'Units', 'normalized');
                end
                ylabel(axL, 'likelihood', 'FontSize', 13);
                xlabel(axL, 'time, s', 'FontSize', 13);
                axL.FontSize = 12; box(axL, 'on');

                linkaxes([axX, axY, axL], 'x');
                base = fullfile(plotsDir, sprintf('trajectory_%s', bp.BodyPartName));
                try
                    saveas(fig, [base '.png']);
                    saveas(fig, [base '.fig']);
                    saved = saved + 1;
                catch ME
                    obj.applog('warn', 'Skip %s: %s', bp.BodyPartName, ME.message);
                end
                close(fig);
            end
            obj.applog('info', 'Bodyparts trajectory: %d plots -> %s', saved, plotsDir);
        end

        function saveSettings(obj)
            startDir = obj.resourceStartDir();
            [f, p] = uiputfile({'*.mat', 'Analysis settings .mat'}, ...
                'Save analysis settings', fullfile(startDir, 'analysis_settings.mat'));
            if isequal(f, 0); return; end
            settings = obj.collectSettings(); %#ok<NASGU>
            try
                save(fullfile(p, f), '-struct', 'settings');
                obj.applog('info', 'Settings saved: %s', fullfile(p, f));
            catch ME
                obj.applog('error', 'Save settings failed: %s', ME.message);
            end
        end

        function loadSettings(obj)
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mat', 'Analysis settings .mat'}, ...
                'Load analysis settings', startDir);
            if isequal(f, 0); return; end
            try
                s = load(fullfile(p, f));
                obj.applySettings(s);
                obj.applog('info', 'Settings loaded: %s', fullfile(p, f));
            catch ME
                obj.applog('error', 'Load settings failed: %s', ME.message);
            end
        end

        function s = collectSettings(obj)
            s.mainVideo = struct( ...
                'enabled',    obj.MainVideoEnableCheckbox.Value, ...
                'startSec',   obj.MainVideoStartField.Value, ...
                'durationSec',obj.MainVideoDurationField.Value, ...
                'trajectory', obj.MainVideoTrajectoryCheckbox.Value, ...
                'velocity',   obj.MainVideoVelocityCheckbox.Value, ...
                'actsList',   obj.MainVideoActsListCheckbox.Value, ...
                'zones',      obj.MainVideoZonesCheckbox.Value, ...
                'presentation', obj.MainVideoPresentationCheckbox.Value);
            v = obj.ActsVideoListBox.Value;
            if ischar(v); v = {v}; end
            s.actsVideo = struct( ...
                'selected',    {v}, ...
                'durationSec', obj.ActsVideoDurationField.Value);
            s.plotBodyparts = obj.PlotBodypartsCheckbox.Value;
            s.plotSession   = obj.PlotSessionCheckbox.Value;
            s.heatmapBinCm  = obj.HeatmapBinField.Value;
        end

        function applySettings(obj, s)
            if isfield(s, 'mainVideo')
                m = s.mainVideo;
                if isfield(m, 'enabled');    obj.MainVideoEnableCheckbox.Value     = m.enabled; end
                if isfield(m, 'startSec');   obj.MainVideoStartField.Value         = m.startSec; end
                if isfield(m, 'durationSec');obj.MainVideoDurationField.Value      = m.durationSec; end
                if isfield(m, 'trajectory'); obj.MainVideoTrajectoryCheckbox.Value = m.trajectory; end
                if isfield(m, 'velocity');   obj.MainVideoVelocityCheckbox.Value   = m.velocity; end
                if isfield(m, 'actsList');   obj.MainVideoActsListCheckbox.Value   = m.actsList; end
                if isfield(m, 'zones');      obj.MainVideoZonesCheckbox.Value      = m.zones; end
                if isfield(m, 'presentation'); obj.MainVideoPresentationCheckbox.Value = m.presentation; end
            end
            if isfield(s, 'actsVideo')
                a = s.actsVideo;
                if isfield(a, 'durationSec'); obj.ActsVideoDurationField.Value = a.durationSec; end
                if isfield(a, 'selected') && ~isempty(a.selected)
                    items = obj.ActsVideoListBox.Items;
                    keep = a.selected(ismember(a.selected, items));
                    if ~isempty(keep); obj.ActsVideoListBox.Value = keep; end
                end
            end
            if isfield(s, 'plotBodyparts'); obj.PlotBodypartsCheckbox.Value = s.plotBodyparts; end
            if isfield(s, 'plotSession');   obj.PlotSessionCheckbox.Value   = s.plotSession;   end
            if isfield(s, 'heatmapBinCm');  obj.HeatmapBinField.Value      = s.heatmapBinCm;  end
        end
    end

    methods (Access = private)
        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {340, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];
            outer.ColumnSpacing = 6;

            obj.buildLeftConfig(outer);
            obj.buildRightResults(outer);
        end

        function buildLeftConfig(obj, parent)
            left = uigridlayout(parent, [6, 1]);
            left.Layout.Column = 1;
            % R20 layout: loader paths / loader settings / options /
            % save-load row / run+render buttons / log. Total options
            % row gets a fixed height so the log row absorbs the
            % freed space (acts videos box shrunk ~30%).
            left.RowHeight = {64, 64, 410, 30, 36, '1x'};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            obj.buildLoaderPaths(left);
            obj.buildLoaderSettings(left);
            obj.buildOptionsPanel(left);
            obj.buildSettingsRow(left);
            obj.buildRunRow(left);
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
            obj.LogTextArea.Layout.Row = 6;
        end

        function buildLoaderPaths(obj, parent)
            % R20 row 1: project paths (Root + Preset + Video + DLC +
            % Out dir). Mirrors the Batch tab loader.
            loader = uigridlayout(parent, [2, 5]);
            loader.Layout.Row = 1;
            loader.RowHeight = {28, 26};
            loader.ColumnWidth = repmat({'1x'}, 1, 5);
            loader.RowSpacing = 4;
            loader.ColumnSpacing = 4;
            loader.Padding = [0 0 0 0];

            obj.RootButton = uibutton(loader, 'Text', 'Root', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Pick project root (auto-fills from previous tabs)', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Root'));
            obj.PresetButton = uibutton(loader, 'Text', 'Preset', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Preset'));
            obj.VideoButton = uibutton(loader, 'Text', 'Video', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Video'));
            obj.DLCButton = uibutton(loader, 'Text', 'DLC', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('DLC'));
            obj.OutDirButton = uibutton(loader, 'Text', 'Out dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('OutDir'));

            obj.RootPathField = uieditfield(loader, 'text', 'Value', '', ...
                'Tooltip', 'Project root');
            obj.PresetPathField = uieditfield(loader, 'text', 'Value', '', ...
                'Tooltip', 'Preset .mat');
            obj.VideoPathField = uieditfield(loader, 'text', 'Value', '', ...
                'Tooltip', 'Session video');
            obj.DLCPathField = uieditfield(loader, 'text', 'Value', '', ...
                'Tooltip', 'DLC csv');
            obj.OutDirPathField = uieditfield(loader, 'text', 'Value', '', ...
                'Tooltip', 'Output dir for plots/videos/.mat');

            obj.inheritRootFromParentApp();
        end

        function buildLoaderSettings(obj, parent)
            % R20 row 2: settings files (Preprocess + Acts library).
            % Same layout idiom as the Batch tab so the two tabs feel
            % aligned.
            row = uigridlayout(parent, [2, 2]);
            row.Layout.Row = 2;
            row.RowHeight = {28, 26};
            row.ColumnWidth = {'1x', '1x'};
            row.RowSpacing = 4;
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];

            obj.PreprocessSettingsButton = uibutton(row, ...
                'Text', 'Preproc settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', '<exp>_PreprocessSettings.mat from Preprocess Tracking. Empty = auto-discover from DLC parent dir.', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Preprocess'));
            obj.ActsLibraryButton = uibutton(row, 'Text', 'Acts library', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Acts library .mat from Define Acts (built-ins used if empty)', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('ActsLibrary'));

            obj.PreprocessSettingsPathField = uieditfield(row, 'text', 'Value', '', ...
                'Tooltip', 'Preprocess settings .mat');
            obj.ActsLibraryPathField = uieditfield(row, 'text', 'Value', '', ...
                'Tooltip', 'Optional acts library .mat (built-ins used if empty)');
        end

        function buildOptionsPanel(obj, parent)
            % Three sections inside one grid: Main video / Acts videos /
            % Trajectory plots. These knobs are saved/loaded as a struct
            % so the same setup can be reused in Batch.
            opts = uigridlayout(parent, [3, 1]);
            opts.Layout.Row = 3;
            % R20: acts videos row trimmed ~30% (was '1x' = flex, now
            % fixed 170 px) so the log row underneath absorbs the
            % freed space.
            opts.RowHeight = {180, 170, 56};
            opts.RowSpacing = 4;
            opts.Padding = [0 0 0 0];

            % --- Main video panel ------------------------------------
            mvPanel = uipanel(opts, 'Title', 'Main video');
            mvPanel.Layout.Row = 1;
            mvGrid = uigridlayout(mvPanel, [5, 4]);
            mvGrid.RowHeight = {26, 26, 26, 26, 26};
            mvGrid.ColumnWidth = {'1x', 70, '1x', 70};
            mvGrid.RowSpacing = 3;
            mvGrid.ColumnSpacing = 4;
            mvGrid.Padding = [4 4 4 4];

            obj.MainVideoEnableCheckbox = uicheckbox(mvGrid, ...
                'Text', 'Render', 'Value', true);
            obj.MainVideoEnableCheckbox.Layout.Row = 1;
            obj.MainVideoEnableCheckbox.Layout.Column = [1 4];

            uilabel(mvGrid, 'Text', 'Start, s:');
            obj.MainVideoStartField = uieditfield(mvGrid, 'numeric', ...
                'Value', 0, 'Limits', [0 100000]);
            uilabel(mvGrid, 'Text', 'Duration, s:');
            obj.MainVideoDurationField = uieditfield(mvGrid, 'numeric', ...
                'Value', 30, 'Limits', [0.1 36000]);

            obj.MainVideoTrajectoryCheckbox = uicheckbox(mvGrid, ...
                'Text', 'Trajectory', 'Value', true, ...
                'Tooltip', 'Overlay bodycenter trail');
            obj.MainVideoVelocityCheckbox = uicheckbox(mvGrid, ...
                'Text', 'Velocity', 'Value', true, ...
                'Tooltip', 'Show current speed');
            obj.MainVideoActsListCheckbox = uicheckbox(mvGrid, ...
                'Text', 'Active acts list', 'Value', true, ...
                'Tooltip', 'Vertical list of currently active acts');
            obj.MainVideoZonesCheckbox = uicheckbox(mvGrid, ...
                'Text', 'Current zones', 'Value', true, ...
                'Tooltip', 'Highlight zones containing the animal');

            obj.MainVideoPresentationCheckbox = uicheckbox(mvGrid, ...
                'Text', 'For presentation', 'Value', false, ...
                'Tooltip', ['Presentation styling: dark-green thick ' ...
                'trajectory, zone outlines (no fill), larger spaced ' ...
                'acts list']);
            obj.MainVideoPresentationCheckbox.Layout.Row = 5;
            obj.MainVideoPresentationCheckbox.Layout.Column = [1 4];

            % --- Acts videos panel -----------------------------------
            avPanel = uipanel(opts, 'Title', 'Acts videos (per-act)');
            avPanel.Layout.Row = 2;
            avGrid = uigridlayout(avPanel, [2, 1]);
            avGrid.RowHeight = {'1x', 28};
            avGrid.RowSpacing = 4;
            avGrid.Padding = [4 4 4 4];

            obj.ActsVideoListBox = uilistbox(avGrid, ...
                'Items', {'(run analyze first)'}, ...
                'Multiselect', 'on', ...
                'Tooltip', 'Acts to render once Run analyze populates results');

            durRow = uigridlayout(avGrid, [1, 2]);
            durRow.Layout.Row = 2;
            durRow.RowHeight = {28};
            durRow.ColumnWidth = {110, 70};
            durRow.Padding = [0 0 0 0];
            uilabel(durRow, 'Text', 'Duration, s:');
            obj.ActsVideoDurationField = uieditfield(durRow, 'numeric', ...
                'Value', 5, 'Limits', [0.1 600]);

            % --- Plot save options + heatmap bin ---------------------
            tail = uigridlayout(opts, [2, 3]);
            tail.Layout.Row = 3;
            tail.RowHeight = {26, 26};
            tail.ColumnWidth = {'1x', 110, 70};
            tail.RowSpacing = 2;
            tail.ColumnSpacing = 4;
            tail.Padding = [0 0 0 0];
            obj.PlotSessionCheckbox = uicheckbox(tail, ...
                'Text', 'Save session plots (trajectory, heatmap, speed)', ...
                'Value', true, ...
                'Tooltip', 'Saves the right-pane plots as PNG+FIG into the session dir');
            obj.PlotSessionCheckbox.Layout.Row = 1;
            obj.PlotSessionCheckbox.Layout.Column = [1 3];
            obj.PlotBodypartsCheckbox = uicheckbox(tail, ...
                'Text', 'Save bodyparts trajectory (PNG + FIG)', ...
                'Value', false, ...
                'Tooltip', 'One 4-tile plot per body part in bodyparts_trajectory/');
            obj.PlotBodypartsCheckbox.Layout.Row = 2;
            obj.PlotBodypartsCheckbox.Layout.Column = 1;
            lb = uilabel(tail, 'Text', 'Heatmap bin, cm:');
            lb.Layout.Row = 2; lb.Layout.Column = 2;
            obj.HeatmapBinField = uieditfield(tail, 'numeric', ...
                'Value', 4, 'Limits', [0.1 100], ...
                'Tooltip', 'Bin size for the occupancy heatmap (cm).', ...
                'ValueChangedFcn', @(~,~) obj.refreshResults());
            obj.HeatmapBinField.Layout.Row = 2;
            obj.HeatmapBinField.Layout.Column = 3;
        end

        function buildSettingsRow(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 4;
            row.RowHeight = {28};
            row.ColumnWidth = {'1x', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.SaveSettingsButton = uibutton(row, 'Text', 'Save settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Save options + thresholds to .mat for batch reuse', ...
                'ButtonPushedFcn', @(~,~) obj.saveSettings());
            obj.LoadSettingsButton = uibutton(row, 'Text', 'Load settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadSettings());
        end

        function buildRunRow(obj, parent)
            row = uigridlayout(parent, [1, 4]);
            row.Layout.Row = 5;
            row.RowHeight = {32};
            row.ColumnWidth = {'1x', '1x', '1x', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.RunButton = uibutton(row, 'Text', 'Run analyze', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.runAnalyze());
            obj.RenderMainVideoButton = uibutton(row, 'Text', 'Render main', ...
                'BackgroundColor', [0.55 0.85 1.00], ...
                'Tooltip', 'Render main video per the Options panel', ...
                'ButtonPushedFcn', @(~,~) obj.renderMainVideo());
            obj.RenderActsVideosButton = uibutton(row, 'Text', 'Render acts', ...
                'BackgroundColor', [0.55 0.85 1.00], ...
                'Tooltip', 'Per-act videos for the acts selected in Options', ...
                'ButtonPushedFcn', @(~,~) obj.renderActsVideos());
            obj.SavePlotsButton = uibutton(row, 'Text', 'Save plots', ...
                'BackgroundColor', [0.78 0.95 0.78], ...
                'Tooltip', 'Save bodyparts trajectory PNG+FIG (Options panel)', ...
                'ButtonPushedFcn', @(~,~) obj.savePlots());
        end

        function refreshActsVideoListBox(obj)
            r = obj.State.result;
            if isempty(r) || isempty(r.Acts)
                obj.ActsVideoListBox.Items = {'(run analyze first)'};
                obj.ActsVideoListBox.Value = {};
                return;
            end
            names = {r.Acts.ActName};
            obj.ActsVideoListBox.Items = names;
            obj.ActsVideoListBox.Value = {};
        end

        function inheritRootFromParentApp(obj)
            if isempty(obj.ParentApp); return; end
            try
                if isprop(obj.ParentApp, 'State') ...
                        && isfield(obj.ParentApp.State, 'projectRoot') ...
                        && ~isempty(obj.ParentApp.State.projectRoot) ...
                        && isfolder(obj.ParentApp.State.projectRoot) ...
                        && isempty(obj.RootPathField.Value)
                    obj.RootPathField.Value = obj.ParentApp.State.projectRoot;
                end
            catch
            end
        end

        function s = sessionStem(obj)
            % Derive session name from the loaded video filename.
            videoPath = obj.VideoPathField.Value;
            s = '';
            if ~isempty(videoPath); [~, s] = fileparts(videoPath); end
            if isempty(s) && ~isempty(obj.DLCPathField.Value)
                [~, s] = fileparts(obj.DLCPathField.Value);
            end
            if isempty(s); s = 'session'; end
        end

        function v = resolveVideoPath(obj)
            % Prefer the UI field. Trim whitespace + strip wrapping
            % quotes (drag-and-drop from Explorer sometimes wraps the
            % path in "..."). Fall back to the path baked into the
            % completed Run's config so Render still works even if the
            % field was cleared after analysis.
            v = '';
            if ~isempty(obj.VideoPathField) && isvalid(obj.VideoPathField)
                raw = strtrim(char(obj.VideoPathField.Value));
                if numel(raw) >= 2 && raw(1) == '"' && raw(end) == '"'
                    raw = raw(2:end-1);
                end
                v = raw;
            end
            if (isempty(v) || ~isfile(v)) && ~isempty(obj.State.result)
                try
                    cv = obj.State.result.config.paths.video;
                    if ~isempty(cv) && isfile(cv); v = cv; end
                catch
                end
            end
        end

        function d = sessionDir(obj, parent)
            % All saves for one Run go into <parent>/<sessionStem>/.
            % `parent` is whatever the caller picked as the output root
            % (typically obj.OutDirPathField.Value or a fallback).
            if nargin < 2 || isempty(parent)
                parent = obj.OutDirPathField.Value;
                if isempty(parent) && ~isempty(obj.VideoPathField.Value)
                    parent = fileparts(obj.VideoPathField.Value);
                end
            end
            d = fullfile(parent, obj.sessionStem());
            if ~isfolder(d); mkdir(d); end
        end

        function dir = resourceStartDir(obj)
            if ~isempty(obj.RootPathField) ...
                    && ~isempty(obj.RootPathField.Value) ...
                    && isfolder(obj.RootPathField.Value)
                dir = obj.RootPathField.Value; return;
            end
            if ~isempty(obj.ParentApp) ...
                    && isprop(obj.ParentApp, 'State') ...
                    && isfield(obj.ParentApp.State, 'projectRoot') ...
                    && ~isempty(obj.ParentApp.State.projectRoot) ...
                    && isfolder(obj.ParentApp.State.projectRoot)
                dir = obj.ParentApp.State.projectRoot; return;
            end
            dir = pwd;
        end

        function buildRightResults(obj, parent)
            % R21: 5 rows x 3 cols. Col 1 is a vertical strip from row 3
            % to row 5 hosting an Etogram-acts filter listbox; rows 1-2
            % (header + results table) still span the full width; the
            % plot pairs (traj/heatmap, speedhist/speedtrace) and the
            % etogram occupy cols 2-3.
            right = uigridlayout(parent, [5, 3]);
            right.Layout.Column = 2;
            right.RowHeight = {44, 160, '1x', 180, 180};
            right.ColumnWidth = {180, '1x', '1x'};
            right.RowSpacing = 4;
            right.ColumnSpacing = 6;
            right.Padding = [0 0 0 0];

            % Row 1: session-wide bodycenter summary (filled by
            % refreshResults; placeholder before the first run).
            obj.SessionStatsLabel = uilabel(right, ...
                'Text', 'Session: run analyze to see avg speed / distance', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'HorizontalAlignment', 'left');
            obj.SessionStatsLabel.Layout.Row = 1;
            obj.SessionStatsLabel.Layout.Column = [1 3];

            % Row 2: per-act results table.
            obj.ResultTable = uitable(right, 'ColumnName', ...
                {'Act', '%', 'dur, s', 'count', 'mean dur, s', ...
                 'mean v, cm/s', 'distance, cm', ...
                 'first start, s', 'first end, s'});
            obj.ResultTable.Layout.Row = 2;
            obj.ResultTable.Layout.Column = [1 3];

            % R21: Etogram-acts filter -- vertical strip in col 1,
            % spans rows 3-5 (from the trajectory row to the bottom).
            % Multi-select; redraws etogram on selection change so the
            % user can focus on a subset of acts.
            obj.EtogramActsListBox = uilistbox(right, ...
                'Items', {'(run analyze first)'}, ...
                'Multiselect', 'on', 'Value', {}, ...
                'Tooltip', 'Check which acts to render on the etogram', ...
                'ValueChangedFcn', @(~,~) obj.onEtogramSelectionChanged());
            obj.EtogramActsListBox.Layout.Row = [3 5];
            obj.EtogramActsListBox.Layout.Column = 1;

            % Row 3: trajectory (over GoodVideoFrame, axes in cm) + heatmap
            obj.TrajAxes = uiaxes(right);
            obj.TrajAxes.Layout.Row = 3; obj.TrajAxes.Layout.Column = 2;
            title(obj.TrajAxes, 'Trajectory');
            obj.TrajAxes.DataAspectRatio = [1 1 1];
            obj.TrajAxes.YDir = 'reverse';
            obj.TrajAxes.Box = 'on';

            obj.HeatmapAxes = uiaxes(right);
            obj.HeatmapAxes.Layout.Row = 3; obj.HeatmapAxes.Layout.Column = 3;
            title(obj.HeatmapAxes, 'Occupancy heatmap');
            obj.HeatmapAxes.DataAspectRatio = [1 1 1];
            obj.HeatmapAxes.YDir = 'reverse';
            obj.HeatmapAxes.Box = 'on';

            % Row 4: etogram (cols 2-3)
            obj.TimelineAxes = uiaxes(right);
            obj.TimelineAxes.Layout.Row = 4;
            obj.TimelineAxes.Layout.Column = [2 3];
            title(obj.TimelineAxes, 'Acts etogram');
            obj.TimelineAxes.Box = 'on';

            % Row 5: speed histogram + speed-vs-time trace
            obj.SpeedHistAxes = uiaxes(right);
            obj.SpeedHistAxes.Layout.Row = 5;
            obj.SpeedHistAxes.Layout.Column = 2;
            title(obj.SpeedHistAxes, 'Speed histogram');
            obj.SpeedHistAxes.Box = 'on';

            obj.SpeedTraceAxes = uiaxes(right);
            obj.SpeedTraceAxes.Layout.Row = 5;
            obj.SpeedTraceAxes.Layout.Column = 3;
            title(obj.SpeedTraceAxes, 'Speed vs time');
            obj.SpeedTraceAxes.Box = 'on';
        end

        function onEtogramSelectionChanged(obj)
            if isempty(obj.State.result); return; end
            obj.drawEtogram(obj.State.result);
        end

        function refreshEtogramActsList(obj, r)
            % Populate the filter listbox to mirror the current run.
            % Default = all checked so the etogram looks unchanged
            % until the user opts to filter.
            if isempty(obj.EtogramActsListBox) || ~isvalid(obj.EtogramActsListBox)
                return;
            end
            if isempty(r) || isempty(r.Acts)
                obj.EtogramActsListBox.Items = {'(run analyze first)'};
                obj.EtogramActsListBox.Value = {};
                return;
            end
            names = {r.Acts.ActName};
            obj.EtogramActsListBox.Items = names;
            obj.EtogramActsListBox.Value = names;
        end

        function pickPath(obj, kind)
            startDir = obj.resourceStartDir();
            switch kind
                case 'Root'
                    d = uigetdir(startDir, 'Project root');
                    if ~isequal(d, 0); obj.RootPathField.Value = d; end
                case 'DLC'
                    [f, p] = uigetfile({'*.csv'}, 'Pick DLC csv', startDir);
                    if ~isequal(f, 0); obj.DLCPathField.Value = fullfile(p, f); end
                case 'Preset'
                    [f, p] = uigetfile({'*.mat'}, 'Pick preset', startDir);
                    if ~isequal(f, 0); obj.PresetPathField.Value = fullfile(p, f); end
                case 'Video'
                    [f, p] = uigetfile({'*.mp4;*.avi;*.mov;*.mkv'}, 'Pick video', startDir);
                    if ~isequal(f, 0); obj.VideoPathField.Value = fullfile(p, f); end
                case 'OutDir'
                    d = uigetdir(startDir, 'Output dir');
                    if ~isequal(d, 0); obj.OutDirPathField.Value = d; end
                case 'ActsLibrary'
                    [f, p] = uigetfile({'*.mat', 'Acts library .mat'}, ...
                        'Pick acts library', startDir);
                    if ~isequal(f, 0); obj.ActsLibraryPathField.Value = fullfile(p, f); end
                case 'Preprocess'
                    [f, p] = uigetfile({'*.mat', 'Preprocess settings .mat'}, ...
                        'Pick preprocess settings', startDir);
                    if ~isequal(f, 0); obj.PreprocessSettingsPathField.Value = fullfile(p, f); end
            end
        end

        function refreshResults(obj)
            if isempty(obj.State.result); return; end
            r = obj.State.result;

            % --- Results table (full library, including zone acts) -----
            n = numel(r.Acts);
            data = cell(n, 9);
            for k = 1:n
                a = r.Acts(k);
                data{k, 1} = a.ActName;
                data{k, 2} = sprintf('%.1f', getOr(a, 'ActPercent', NaN));
                data{k, 3} = sprintf('%.2f', getOr(a, 'ActDuration', NaN));
                data{k, 4} = getOr(a, 'ActNumber', 0);
                data{k, 5} = sprintf('%.2f', getOr(a, 'ActMeanTime', NaN));
                data{k, 6} = sprintf('%.2f', getOr(a, 'ActMeanVelocity', NaN));
                data{k, 7} = sprintf('%.2f', getOr(a, 'Distance', NaN));
                data{k, 8} = formatSec(getOr(a, 'FirstStartSec', NaN));
                data{k, 9} = formatSec(getOr(a, 'FirstEndSec', NaN));
            end
            obj.ResultTable.Data = data;

            % --- Bodycenter idx (used by trajectory + heatmap + speed) -
            bps = r.BodyPartsTraces;
            idx = find(strcmpi({bps.BodyPartName}, 'bodycenter'), 1);
            if isempty(idx); idx = 1; end

            % --- Session-wide bodycenter summary -----------------------
            avgSpeed = NaN; totalDist = NaN;
            if isfield(bps(idx), 'AverageSpeed')
                avgSpeed = bps(idx).AverageSpeed;
            end
            if isfield(bps(idx), 'AverageDistance')
                totalDist = bps(idx).AverageDistance;
            end
            sessSec = NaN;
            if isfield(r, 'n_frames') && isfield(r, 'Options') ...
                    && isfield(r.Options, 'FrameRate')
                sessSec = r.n_frames / r.Options.FrameRate;
            end
            lines = { sprintf( ...
                'Session (bodycenter): avg speed %.2f cm/s   |   total distance %.1f cm   |   duration %.1f s   |   %d frames', ...
                avgSpeed, totalDist, sessSec, r.n_frames) };
            % Barnes-paradigm row 2: only shown when analyzeSession
            % attached BarnesMetrics to the result (it does so when
            % Options.ExperimentType == 'Barnes').
            if isfield(r, 'BarnesMetrics') && isstruct(r.BarnesMetrics)
                bm = r.BarnesMetrics;
                lines{end + 1} = sprintf( ...
                    ['Barnes: target visit #%s   |   %d holes checked   ' ...
                     '|   first hole error %s deg   |   mean error %s deg   ' ...
                     '|   nose-pokes %d   |   body visits %d'], ...
                    formatNum(getOr(bm, 'TargetHoleVisitOrder', NaN)), ...
                    getOr(bm, 'NumCheckedHoles', 0), ...
                    formatNum(getOr(bm, 'FirstCheckedHoleErrorDeg', NaN)), ...
                    formatNum(getOr(bm, 'MeanCheckedHoleErrorDeg', NaN)), ...
                    getOr(bm, 'TotalNoseHoleVisits', 0), ...
                    getOr(bm, 'TotalBodyHoleVisits', 0));
            end
            obj.SessionStatsLabel.Text = lines;
            pxlPerCm = 1;
            if isfield(r, 'Options') && isfield(r.Options, 'pxl2sm')
                pxlPerCm = r.Options.pxl2sm;
            end
            X = bps(idx).TraceSmoothed.X(:);
            Y = bps(idx).TraceSmoothed.Y(:);
            xCm = X / pxlPerCm;
            yCm = Y / pxlPerCm;
            v   = bps(idx).VelocitySmoothed(:);
            frameRate = NaN;
            if isfield(r, 'Options') && isfield(r.Options, 'FrameRate')
                frameRate = r.Options.FrameRate;
            end

            % --- Trajectory over GoodVideoFrame, cm axes --------------
            try
                obj.drawTrajectory(r, bps, idx, X, Y, pxlPerCm);
            catch ME
                obj.applog('warn', 'Trajectory plot failed: %s', ME.message);
            end

            % --- Occupancy heatmap (cm grid) --------------------------
            try
                obj.drawHeatmap(xCm, yCm, r);
            catch ME
                obj.applog('warn', 'Heatmap plot failed: %s', ME.message);
            end

            % --- Speed histogram + speed-vs-time trace ----------------
            try
                obj.drawSpeed(v, frameRate);
            catch ME
                obj.applog('warn', 'Speed plot failed: %s', ME.message);
            end

            % --- Etogram (filtered + categorized) ---------------------
            obj.refreshEtogramActsList(r);
            obj.drawEtogram(r);
        end

        function drawTrajectory(obj, r, bps, idx, X, Y, pxlPerCm)
            ax = obj.TrajAxes;
            cla(ax); hold(ax, 'on');
            frame = [];
            if isfield(r, 'Options')
                opts = r.Options;
                for fld = {'GoodVideoFrame', 'GoodVideoFrameGray'}
                    if isfield(opts, fld{1}) && ~isempty(opts.(fld{1}))
                        frame = opts.(fld{1}); break;
                    end
                end
            end
            if ~isempty(frame)
                imshow(frame, 'Parent', ax, ...
                    'XData', [0 size(frame,2)/pxlPerCm], ...
                    'YData', [0 size(frame,1)/pxlPerCm]);
            end
            plot(ax, X/pxlPerCm, Y/pxlPerCm, ...
                'Color', [0.10 0.50 0.90], 'LineWidth', 1.0);
            ax.DataAspectRatio = [1 1 1];
            ax.YDir = 'reverse';
            ax.XLim = [0 size(frame,2)/pxlPerCm];
            ax.YLim = [0 size(frame,1)/pxlPerCm];
            xlabel(ax, 'X, cm', 'FontSize', 12);
            ylabel(ax, 'Y, cm', 'FontSize', 12);
            ax.FontSize = 11;
            title(ax, sprintf('Trajectory (%s)', bps(idx).BodyPartName), ...
                'Interpreter', 'none', 'FontSize', 13);
            hold(ax, 'off');
        end

        function drawHeatmap(obj, xCm, yCm, r)
            ax = obj.HeatmapAxes;
            cla(ax);
            extentX = max(xCm); extentY = max(yCm);
            if isfield(r, 'Options') && isfield(r.Options, 'pxl2sm') ...
                    && isfield(r.Options, 'Width') && isfield(r.Options, 'Height')
                extentX = r.Options.Width / r.Options.pxl2sm;
                extentY = r.Options.Height / r.Options.pxl2sm;
            end
            binCm = 4;
            if ~isempty(obj.HeatmapBinField) && isvalid(obj.HeatmapBinField)
                binCm = max(0.1, obj.HeatmapBinField.Value);
            end
            edgesX = 0:binCm:max(extentX, binCm);
            edgesY = 0:binCm:max(extentY, binCm);
            valid = isfinite(xCm) & isfinite(yCm);
            counts = histcounts2(xCm(valid), yCm(valid), edgesX, edgesY);
            % Frames -> seconds via the analyzed FrameRate.
            fps = 30;
            if isfield(r, 'Options') && isfield(r.Options, 'FrameRate')
                fps = r.Options.FrameRate;
            end
            secs = counts / fps;
            % Gaussian smooth in cm units. Sigma = bin (one bin width) so
            % the smoothing scale matches the user's chosen resolution.
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
                'FontSize', 14);
        end

        function drawSpeed(obj, v, frameRate)
            % Histogram (150 bins, cm/s) and the velocity trace.
            ax1 = obj.SpeedHistAxes;
            cla(ax1);
            if ~isempty(v) && any(isfinite(v))
                histogram(ax1, v(isfinite(v)), 150, ...
                    'FaceColor', [0.30 0.70 0.30], 'EdgeColor', 'none');
            end
            xlabel(ax1, 'speed, cm/s', 'FontSize', 12);
            ylabel(ax1, 'frames', 'FontSize', 12);
            ax1.FontSize = 11;
            title(ax1, 'Speed histogram (bodycenter)', 'FontSize', 13);

            ax2 = obj.SpeedTraceAxes;
            cla(ax2);
            if ~isempty(v)
                if isfinite(frameRate)
                    t = (0:numel(v)-1)' / frameRate;
                    plot(ax2, t, v, 'Color', [0.30 0.55 0.85], 'LineWidth', 0.8);
                    xlabel(ax2, 'time, s', 'FontSize', 12);
                else
                    plot(ax2, 1:numel(v), v, 'Color', [0.30 0.55 0.85], 'LineWidth', 0.8);
                    xlabel(ax2, 'frame', 'FontSize', 12);
                end
                ylabel(ax2, 'speed, cm/s', 'FontSize', 12);
            end
            ax2.FontSize = 11;
            title(ax2, 'Speed vs time (bodycenter)', 'FontSize', 13);
        end

        function drawEtogram(obj, r)
            ax = obj.TimelineAxes;
            cla(ax); hold(ax, 'on');

            % Bucket acts by name pattern: speed → spatial → posture →
            % composite. Within a bucket, sort by name.
            n0 = numel(r.Acts);
            if n0 == 0
                title(ax, 'Acts etogram — no acts');
                hold(ax, 'off'); return;
            end
            names0 = {r.Acts.ActName};
            % R21: filter by EtogramActsListBox selection. Empty
            % selection or never-populated listbox = show all.
            selected = {};
            if ~isempty(obj.EtogramActsListBox) ...
                    && isvalid(obj.EtogramActsListBox)
                selected = obj.EtogramActsListBox.Value;
                if ischar(selected); selected = {selected}; end
            end
            if ~isempty(selected)
                keep = ismember(names0, selected);
                if ~any(keep)
                    title(ax, 'Acts etogram — no acts selected');
                    hold(ax, 'off'); return;
                end
                r2 = r; r2.Acts = r.Acts(keep);
                names0 = {r2.Acts.ActName};
            else
                r2 = r;
            end
            buckets = cellfun(@(nm) sphynx.util.actBucket(nm), names0, 'UniformOutput', false);
            [~, sortIdx] = sortActs(buckets, names0);
            actsToPlot = r2.Acts(sortIdx);
            n = numel(actsToPlot);

            % Colors per bucket so the visual grouping is obvious.
            bucketColors = struct('speed', [0.20 0.55 0.90], ...
                                  'spatial', [0.85 0.55 0.20], ...
                                  'posture', [0.20 0.70 0.30], ...
                                  'composite', [0.55 0.30 0.75]);
            for k = 1:n
                a = actsToPlot(k).ActArrayRefine;
                bk = sphynx.util.actBucket(actsToPlot(k).ActName);
                col = bucketColors.(bk);
                yLine = ones(size(a)) * (n - k + 1);
                yLine(~a) = NaN;
                plot(ax, 1:numel(a), yLine, '-', 'LineWidth', 5, 'Color', col);
            end
            ax.YTick = 1:n;
            ax.YTickLabel = flip({actsToPlot.ActName});
            xlabel(ax, 'frame', 'FontSize', 12);
            ax.FontSize = 11;
            ax.YLim = [0.5 n + 0.5];
            title(ax, sprintf('Acts etogram (%d acts, ordered: speed → spatial → posture → composite)', n), ...
                'Interpreter', 'none', 'FontSize', 13);
            hold(ax, 'off');
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[Analyze] ' fmt], varargin{:});
            if isempty(obj.LogTextArea) || ~isvalid(obj.LogTextArea); return; end
            line = sprintf(['[' upper(level) '] ' fmt], varargin{:});
            current = obj.LogTextArea.Value;
            if isempty(current); current = {}; end
            if ~iscell(current); current = cellstr(current); end
            obj.LogTextArea.Value = [{line}; current(:)];
        end
    end
end

function rgb = semanticColor(kind)
    switch kind
        case 'action';   rgb = [1.00 0.85 0.85];
        case 'geometry'; rgb = [1.00 0.96 0.78];
        case 'info';     rgb = [0.78 0.95 0.95];
        otherwise;       rgb = [0.94 0.94 0.94];
    end
end

function v = getOr(s, name, fallback)
    if isfield(s, name); v = s.(name); else; v = fallback; end
end

function s = formatSec(x)
    if isnan(x); s = '—'; else; s = sprintf('%.2f', x); end
end

function s = formatNum(x)
    % Used for Barnes-metric numbers in the SessionStatsLabel header.
    % %g trims trailing zeros so integer counts show as "4" and angles
    % as "18.5" without forcing the trailing ".0".
    if ~isnumeric(x) || isempty(x) || isnan(x)
        s = '-';
    else
        s = sprintf('%g', x);
    end
end

function updateDlg(dlg, frac, msg)
    if isvalid(dlg)
        dlg.Value = max(0, min(1, frac));
        dlg.Message = msg;
    end
end

function closeIfValid(h)
    if ~isempty(h) && isvalid(h); try; close(h); catch; end; end
end

function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end

function [sortedBuckets, idx] = sortActs(buckets, names)
    order = struct('speed', 1, 'spatial', 2, 'posture', 3, 'composite', 4);
    n = numel(buckets);
    keys = zeros(n, 1);
    for k = 1:n; keys(k) = order.(buckets{k}); end
    [~, idx] = sortrows([keys, (1:n)'], [1 2]);
    % Re-sort within each bucket alphabetically (case-insensitive).
    out = idx;
    for tier = 1:4
        sl = keys(idx) == tier;
        sub = idx(sl);
        if numel(sub) <= 1; continue; end
        [~, oo] = sort(lower(names(sub)));
        out(find(sl, 1):find(sl, 1)+numel(sub)-1) = sub(oo);
    end
    idx = out;
    sortedBuckets = buckets(idx);
end

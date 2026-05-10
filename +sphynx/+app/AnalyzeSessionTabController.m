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

        % Threshold overrides (rest/loc kept on this tab; freezing/rear
        % moved to defaults — see docs/TODO.md to relocate to Define Acts)
        RestField
        LocField

        % Run + results
        RunButton
        ResultTable

        % Plots
        TrajAxes
        HeatmapAxes
        TimelineAxes
        SpeedHistAxes
        SpeedTraceAxes

        % Etogram filter
        ShowZoneActsCheckbox

        % Output options — main video
        MainVideoEnableCheckbox
        MainVideoStartField
        MainVideoDurationField
        MainVideoTrajectoryCheckbox
        MainVideoVelocityCheckbox
        MainVideoActsListCheckbox
        MainVideoZonesCheckbox

        % Output options — per-act videos
        ActsVideoListBox
        ActsVideoDurationField

        % Output options — trajectory PNG+FIG plots
        PlotBodypartsCheckbox

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
            cfg.paths.outDir = obj.OutDirPathField.Value;
            cfg.acts.restThresholdCmS = obj.RestField.Value;
            cfg.acts.locThresholdCmS  = obj.LocField.Value;
            % FreezingMode/RearMode use defaults from defaultConfig.m
            % until per-experiment defaults land in Define Acts.
            if ~isempty(obj.ActsLibraryPathField) ...
                    && ~isempty(obj.ActsLibraryPathField.Value)
                cfg.acts.libraryPath = obj.ActsLibraryPathField.Value;
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
            videoPath = obj.VideoPathField.Value;
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Pick a video first'); return;
            end
            outDir = obj.OutDirPathField.Value;
            if isempty(outDir); outDir = fileparts(videoPath); end
            startSec = obj.MainVideoStartField.Value;
            durSec   = obj.MainVideoDurationField.Value;
            fps = obj.State.result.Options.FrameRate;
            startF = max(1, round(startSec * fps) + 1);
            endF   = startF + max(1, round(durSec * fps)) - 1;
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Rendering main video', ...
                'Message', 'Starting...', 'Cancelable', 'off');
            cleaner = onCleanup(@() closeIfValid(dlg));
            feat = obj.collectMainVideoFeatures();
            try
                outPath = sphynx.pipeline.renderActsVideo(obj.State.result, ...
                    videoPath, outDir, ...
                    'Range', [startF endF], ...
                    'Features', feat, ...
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
                'zones',      obj.MainVideoZonesCheckbox.Value);
        end

        function renderActsVideos(obj)
            if isempty(obj.State.result)
                obj.applog('warn', 'Run analyze first'); return;
            end
            sel = obj.ActsVideoListBox.Value;
            if ischar(sel); sel = {sel}; end
            if isempty(sel)
                obj.applog('warn', 'Select acts to render in the Options panel');
                return;
            end
            videoPath = obj.VideoPathField.Value;
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Pick a video first'); return;
            end
            outDir = obj.OutDirPathField.Value;
            if isempty(outDir); outDir = fileparts(videoPath); end
            actsDir = fullfile(outDir, 'Acts_video');
            if ~isfolder(actsDir); mkdir(actsDir); end
            durSec = obj.ActsVideoDurationField.Value;
            r = obj.State.result;
            fps = r.Options.FrameRate;
            nWin = max(1, round(double(durSec) * double(fps)));
            [~, sessionStem] = fileparts(videoPath);
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Render acts videos', ...
                'Indeterminate', 'on', 'Cancelable', 'on');
            cleaner = onCleanup(@() closeIfValid(dlg));
            saved = 0;
            for k = 1:numel(sel)
                if dlg.CancelRequested; break; end
                actName = sel{k};
                rIdx = find(strcmp({r.Acts.ActName}, actName), 1);
                if isempty(rIdx); continue; end
                bool = logical(r.Acts(rIdx).ActArrayRefine);
                activeFrames = find(bool);
                if isempty(activeFrames)
                    obj.applog('info', '"%s" — 0 active frames, skip', actName);
                    continue;
                end
                nTake = min(numel(activeFrames), nWin);
                first = activeFrames(1);
                last  = activeFrames(min(nTake, numel(activeFrames)));
                outPath = fullfile(actsDir, sprintf('%s_%s.mp4', ...
                    sessionStem, matlab.lang.makeValidName(actName)));
                try
                    sphynx.pipeline.renderActsVideo(r, videoPath, actsDir, ...
                        'Range', [first last], ...
                        'Overlay', 'full', ...
                        'ProgressFcn', @(v, m) updateDlg(dlg, v, m));
                    saved = saved + 1;
                    obj.applog('info', '"%s" rendered (frames %d..%d)', ...
                        actName, first, last);
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
            if ~obj.PlotBodypartsCheckbox.Value
                obj.applog('warn', 'Bodyparts trajectory is disabled in Options');
                return;
            end
            outDir = obj.OutDirPathField.Value;
            if isempty(outDir); outDir = fileparts(obj.VideoPathField.Value); end
            if isempty(outDir); obj.applog('warn', 'Pick output dir'); return; end
            plotsDir = fullfile(outDir, 'plots');
            if ~isfolder(plotsDir); mkdir(plotsDir); end
            try
                sphynx.preprocess.exportTracks(obj.State.result.BodyPartsTraces, ...
                    struct('plotsDir', plotsDir));
                obj.applog('info', 'Bodyparts trajectory plots saved -> %s', plotsDir);
            catch ME
                obj.applog('error', 'Plot save failed: %s', ME.message);
            end
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
            s.restThresholdCmS = obj.RestField.Value;
            s.locThresholdCmS  = obj.LocField.Value;
            s.mainVideo = struct( ...
                'enabled',    obj.MainVideoEnableCheckbox.Value, ...
                'startSec',   obj.MainVideoStartField.Value, ...
                'durationSec',obj.MainVideoDurationField.Value, ...
                'trajectory', obj.MainVideoTrajectoryCheckbox.Value, ...
                'velocity',   obj.MainVideoVelocityCheckbox.Value, ...
                'actsList',   obj.MainVideoActsListCheckbox.Value, ...
                'zones',      obj.MainVideoZonesCheckbox.Value);
            v = obj.ActsVideoListBox.Value;
            if ischar(v); v = {v}; end
            s.actsVideo = struct( ...
                'selected',    {v}, ...
                'durationSec', obj.ActsVideoDurationField.Value);
            s.plotBodyparts = obj.PlotBodypartsCheckbox.Value;
        end

        function applySettings(obj, s)
            if isfield(s, 'restThresholdCmS'); obj.RestField.Value = s.restThresholdCmS; end
            if isfield(s, 'locThresholdCmS');  obj.LocField.Value  = s.locThresholdCmS;  end
            if isfield(s, 'mainVideo')
                m = s.mainVideo;
                if isfield(m, 'enabled');    obj.MainVideoEnableCheckbox.Value     = m.enabled; end
                if isfield(m, 'startSec');   obj.MainVideoStartField.Value         = m.startSec; end
                if isfield(m, 'durationSec');obj.MainVideoDurationField.Value      = m.durationSec; end
                if isfield(m, 'trajectory'); obj.MainVideoTrajectoryCheckbox.Value = m.trajectory; end
                if isfield(m, 'velocity');   obj.MainVideoVelocityCheckbox.Value   = m.velocity; end
                if isfield(m, 'actsList');   obj.MainVideoActsListCheckbox.Value   = m.actsList; end
                if isfield(m, 'zones');      obj.MainVideoZonesCheckbox.Value      = m.zones; end
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
            left = uigridlayout(parent, [7, 1]);
            left.Layout.Column = 1;
            % Row layout: loader strip / speed thresholds / etogram
            % filter / Options panel / settings save-load / run+render
            % buttons / log.
            left.RowHeight = {64, 32, 28, '1x', 30, 36, 90};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            obj.buildLoaderStrip(left);
            obj.buildSpeedThresholds(left);
            obj.buildEtogramFilter(left);
            obj.buildOptionsPanel(left);
            obj.buildSettingsRow(left);
            obj.buildRunRow(left);
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
            obj.LogTextArea.Layout.Row = 7;
        end

        function buildLoaderStrip(obj, parent)
            loader = uigridlayout(parent, [2, 6]);
            loader.Layout.Row = 1;
            loader.RowHeight = {28, 26};
            loader.ColumnWidth = repmat({'1x'}, 1, 6);
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
            obj.ActsLibraryButton = uibutton(loader, 'Text', 'Acts lib', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('ActsLibrary'));

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
            obj.ActsLibraryPathField = uieditfield(loader, 'text', 'Value', '', ...
                'Tooltip', 'Optional acts library .mat (built-ins used if empty)');

            obj.inheritRootFromParentApp();
        end

        function buildSpeedThresholds(obj, parent)
            row = uigridlayout(parent, [1, 4]);
            row.Layout.Row = 2;
            row.RowHeight = {28};
            row.ColumnWidth = {110, 70, 110, 70};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            uilabel(row, 'Text', 'Rest, cm/s:');
            obj.RestField = uieditfield(row, 'numeric', 'Value', 1, 'Limits', [0 1000]);
            uilabel(row, 'Text', 'Locomotion, cm/s:');
            obj.LocField = uieditfield(row, 'numeric', 'Value', 5, 'Limits', [0 1000]);
        end

        function buildEtogramFilter(obj, parent)
            obj.ShowZoneActsCheckbox = uicheckbox(parent, ...
                'Text', 'Show zone acts in etogram', ...
                'Value', false, ...
                'Tooltip', ['Zone acts (corners/walls/center/etc.) are auto-' ...
                            'derived from the preset. Hide them to keep the ' ...
                            'etogram focused on built-ins + custom library.'], ...
                'ValueChangedFcn', @(~,~) obj.refreshResults());
            obj.ShowZoneActsCheckbox.Layout.Row = 3;
        end

        function buildOptionsPanel(obj, parent)
            % Three sections inside one grid: Main video / Acts videos /
            % Trajectory plots. These knobs are saved/loaded as a struct
            % so the same setup can be reused in Batch.
            opts = uigridlayout(parent, [3, 1]);
            opts.Layout.Row = 4;
            opts.RowHeight = {180, '1x', 30};
            opts.RowSpacing = 4;
            opts.Padding = [0 0 0 0];

            % --- Main video panel ------------------------------------
            mvPanel = uipanel(opts, 'Title', 'Main video');
            mvPanel.Layout.Row = 1;
            mvGrid = uigridlayout(mvPanel, [4, 4]);
            mvGrid.RowHeight = {26, 26, 26, 26};
            mvGrid.ColumnWidth = {'1x', 70, '1x', 70};
            mvGrid.RowSpacing = 3;
            mvGrid.ColumnSpacing = 4;
            mvGrid.Padding = [4 4 4 4];

            obj.MainVideoEnableCheckbox = uicheckbox(mvGrid, ...
                'Text', 'Render', 'Value', false);
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

            % --- Trajectory plots ------------------------------------
            obj.PlotBodypartsCheckbox = uicheckbox(opts, ...
                'Text', 'Save bodyparts trajectory (PNG + FIG)', ...
                'Value', false, ...
                'Tooltip', 'Same per-bodypart panels as Preprocess Tracking');
            obj.PlotBodypartsCheckbox.Layout.Row = 3;
        end

        function buildSettingsRow(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 5;
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
            row.Layout.Row = 6;
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
            % 4 rows: results table | trajectory + heatmap | etogram |
            % speed histogram + speed trace.
            right = uigridlayout(parent, [4, 2]);
            right.Layout.Column = 2;
            right.RowHeight = {160, '1x', 180, 180};
            right.ColumnWidth = {'1x', '1x'};
            right.RowSpacing = 4;
            right.ColumnSpacing = 6;
            right.Padding = [0 0 0 0];

            % Row 1: results table spanning both cols
            obj.ResultTable = uitable(right, 'ColumnName', ...
                {'Act', '%', 'duration', 'count', 'mean dur, s'});
            obj.ResultTable.Layout.Row = 1;
            obj.ResultTable.Layout.Column = [1 2];

            % Row 2: trajectory (over GoodVideoFrame, axes in cm) + heatmap
            obj.TrajAxes = uiaxes(right);
            obj.TrajAxes.Layout.Row = 2; obj.TrajAxes.Layout.Column = 1;
            title(obj.TrajAxes, 'Trajectory');
            obj.TrajAxes.DataAspectRatio = [1 1 1];
            obj.TrajAxes.YDir = 'reverse';
            obj.TrajAxes.Box = 'on';

            obj.HeatmapAxes = uiaxes(right);
            obj.HeatmapAxes.Layout.Row = 2; obj.HeatmapAxes.Layout.Column = 2;
            title(obj.HeatmapAxes, 'Occupancy heatmap');
            obj.HeatmapAxes.DataAspectRatio = [1 1 1];
            obj.HeatmapAxes.YDir = 'reverse';
            obj.HeatmapAxes.Box = 'on';

            % Row 3: etogram (full width)
            obj.TimelineAxes = uiaxes(right);
            obj.TimelineAxes.Layout.Row = 3;
            obj.TimelineAxes.Layout.Column = [1 2];
            title(obj.TimelineAxes, 'Acts etogram');
            obj.TimelineAxes.Box = 'on';

            % Row 4: speed histogram + speed-vs-time trace
            obj.SpeedHistAxes = uiaxes(right);
            obj.SpeedHistAxes.Layout.Row = 4;
            obj.SpeedHistAxes.Layout.Column = 1;
            title(obj.SpeedHistAxes, 'Speed histogram');
            obj.SpeedHistAxes.Box = 'on';

            obj.SpeedTraceAxes = uiaxes(right);
            obj.SpeedTraceAxes.Layout.Row = 4;
            obj.SpeedTraceAxes.Layout.Column = 2;
            title(obj.SpeedTraceAxes, 'Speed vs time');
            obj.SpeedTraceAxes.Box = 'on';
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
            end
        end

        function refreshResults(obj)
            if isempty(obj.State.result); return; end
            r = obj.State.result;

            % --- Results table (full library, including zone acts) -----
            n = numel(r.Acts);
            data = cell(n, 5);
            for k = 1:n
                a = r.Acts(k);
                data{k, 1} = a.ActName;
                data{k, 2} = sprintf('%.1f', getOr(a, 'ActPercent', NaN));
                data{k, 3} = sprintf('%.2f', getOr(a, 'ActDuration', NaN));
                data{k, 4} = getOr(a, 'ActNumber', 0);
                data{k, 5} = sprintf('%.2f', getOr(a, 'ActMeanTime', NaN));
            end
            obj.ResultTable.Data = data;

            % --- Bodycenter idx (used by trajectory + heatmap + speed) -
            bps = r.BodyPartsTraces;
            idx = find(strcmpi({bps.BodyPartName}, 'bodycenter'), 1);
            if isempty(idx); idx = 1; end
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
            % Frame extent in cm to bound the heatmap.
            extentX = max(xCm); extentY = max(yCm);
            if isfield(r, 'Options') && isfield(r.Options, 'pxl2sm') ...
                    && isfield(r.Options, 'Width') && isfield(r.Options, 'Height')
                extentX = r.Options.Width / r.Options.pxl2sm;
                extentY = r.Options.Height / r.Options.pxl2sm;
            end
            % 1 cm bins
            edgesX = 0:1:max(extentX, 1);
            edgesY = 0:1:max(extentY, 1);
            valid = isfinite(xCm) & isfinite(yCm);
            counts = histcounts2(xCm(valid), yCm(valid), edgesX, edgesY);
            % imagesc expects rows=Y, cols=X
            imagesc(ax, edgesX, edgesY, counts');
            ax.YDir = 'reverse';
            colormap(ax, 'parula');
            cb = colorbar(ax);
            cb.Label.String = 'frames';
            cb.Label.FontSize = 11;
            ax.DataAspectRatio = [1 1 1];
            ax.XLim = [0 extentX]; ax.YLim = [0 extentY];
            xlabel(ax, 'X, cm', 'FontSize', 12);
            ylabel(ax, 'Y, cm', 'FontSize', 12);
            ax.FontSize = 11;
            title(ax, 'Occupancy heatmap (1 cm bins)', 'FontSize', 13);
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

            % Filter zone acts unless checkbox is on. Always show
            % built-ins + custom-library acts.
            showZone = ~isempty(obj.ShowZoneActsCheckbox) ...
                && obj.ShowZoneActsCheckbox.Value;
            keep = false(1, numel(r.Acts));
            for k = 1:numel(r.Acts)
                cat = '';
                if isfield(r.Acts(k), 'Category')
                    cat = r.Acts(k).Category;
                end
                if isempty(cat); cat = 'builtin'; end  % defensive
                keep(k) = strcmp(cat, 'builtin') ...
                    || strcmp(cat, 'custom') ...
                    || (showZone && strcmp(cat, 'zone'));
            end
            actsToPlot = r.Acts(keep);
            n = numel(actsToPlot);
            if n == 0
                title(ax, 'Acts etogram — no acts to show');
                hold(ax, 'off'); return;
            end

            % Color palette: built-ins use lines(.), custom acts use
            % a contrasting palette so they stand out.
            builtinPal = lines(7);
            customPal  = [hsv(7) * 0.6 + 0.3];  % softened HSV, distinct
            for k = 1:n
                a = actsToPlot(k).ActArrayRefine;
                cat = '';
                if isfield(actsToPlot(k), 'Category'); cat = actsToPlot(k).Category; end
                switch cat
                    case 'custom'; col = customPal(mod(k-1,7)+1, :);
                    case 'zone';   col = [0.5 0.5 0.5];
                    otherwise;     col = builtinPal(mod(k-1,7)+1, :);
                end
                yLine = ones(size(a)) * (n - k + 1);
                yLine(~a) = NaN;
                plot(ax, 1:numel(a), yLine, '-', 'LineWidth', 5, 'Color', col);
            end
            ax.YTick = 1:n;
            ax.YTickLabel = flip({actsToPlot.ActName});
            xlabel(ax, 'frame', 'FontSize', 12);
            ax.FontSize = 11;
            ax.YLim = [0.5 n + 0.5];
            title(ax, sprintf('Acts etogram (%d acts shown%s)', n, ...
                ternary(showZone, '', '; zone acts hidden')), ...
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

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

        % Loading
        DLCField
        PresetField
        VideoField
        OutDirField
        ActsLibraryField

        % Threshold overrides
        RestField
        LocField
        FreezingModeDropDown

        % Run + results
        RunButton
        RenderVideoButton
        ResultTable

        % Plots
        TrajAxes
        HeatmapAxes
        TimelineAxes
        SpeedHistAxes
        SpeedTraceAxes

        % Etogram filter
        ShowZoneActsCheckbox

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
            cfg.paths.dlc    = obj.DLCField.Value;
            cfg.paths.preset = obj.PresetField.Value;
            cfg.paths.outDir = obj.OutDirField.Value;
            cfg.acts.restThresholdCmS = obj.RestField.Value;
            cfg.acts.locThresholdCmS  = obj.LocField.Value;
            cfg.acts.freezingMode     = obj.FreezingModeDropDown.Value;
            if ~isempty(obj.ActsLibraryField) && ~isempty(obj.ActsLibraryField.Value)
                cfg.acts.libraryPath = obj.ActsLibraryField.Value;
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
        end

        function renderActsVideo(obj)
            if isempty(obj.State.result)
                obj.applog('warn', 'Run analyze first'); return;
            end
            videoPath = obj.VideoField.Value;
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Pick a video first'); return;
            end
            outDir = obj.OutDirField.Value;
            if isempty(outDir); outDir = fileparts(videoPath); end
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Rendering acts video', ...
                'Message', 'Starting...', 'Cancelable', 'off');
            cleaner = onCleanup(@() closeIfValid(dlg));
            try
                outPath = sphynx.pipeline.renderActsVideo(obj.State.result, ...
                    videoPath, outDir, ...
                    'ProgressFcn', @(v, m) updateDlg(dlg, v, m));
                obj.applog('info', 'Acts video saved: %s', outPath);
            catch ME
                obj.applog('error', 'Render failed: %s', ME.message);
            end
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
            left = uigridlayout(parent, [16, 2]);
            left.Layout.Column = 1;
            left.RowHeight = repmat({30}, 1, 16);
            left.ColumnWidth = {110, '1x'};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            uilabel(left, 'Text', 'DLC:');
            obj.DLCField = uieditfield(left, 'text', 'Value', '');
            uilabel(left, 'Text', 'Preset:');
            obj.PresetField = uieditfield(left, 'text', 'Value', '');
            uilabel(left, 'Text', 'Video:');
            obj.VideoField = uieditfield(left, 'text', 'Value', '', ...
                'Tooltip', 'optional — needed only for Render acts video');
            uilabel(left, 'Text', 'Output dir:');
            obj.OutDirField = uieditfield(left, 'text', 'Value', '');
            uilabel(left, 'Text', 'Acts library:');
            obj.ActsLibraryField = uieditfield(left, 'text', 'Value', '', ...
                'Tooltip', 'optional .mat from Define Acts; built-in defaults if empty');

            % Browse row 1: DLC / Preset / Video / Out dir
            uilabel(left, 'Text', '');
            br = uigridlayout(left, [1, 4]);
            br.RowHeight = {28};
            br.ColumnWidth = {'1x', '1x', '1x', '1x'};
            br.Padding = [0 0 0 0];
            br.ColumnSpacing = 4;
            uibutton(br, 'Text', 'DLC...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('DLC'));
            uibutton(br, 'Text', 'Preset...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Preset'));
            uibutton(br, 'Text', 'Video...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Video'));
            uibutton(br, 'Text', 'Out dir...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('OutDir'));

            % Browse row 2: Acts library
            uilabel(left, 'Text', '');
            uibutton(left, 'Text', 'Acts library...', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('ActsLibrary'));

            uilabel(left, 'Text', 'Rest cm/s:');
            obj.RestField = uieditfield(left, 'numeric', 'Value', 1);
            uilabel(left, 'Text', 'Locomotion cm/s:');
            obj.LocField = uieditfield(left, 'numeric', 'Value', 5);
            uilabel(left, 'Text', 'Freezing mode:');
            obj.FreezingModeDropDown = uidropdown(left, ...
                'Items', {'HeadAndCenter', 'NoseAndCenter', 'AllBodyParts'}, ...
                'Value', 'HeadAndCenter');

            uilabel(left, 'Text', '');
            obj.RunButton = uibutton(left, 'Text', 'Run analyze', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.runAnalyze());

            uilabel(left, 'Text', '');
            obj.RenderVideoButton = uibutton(left, 'Text', 'Render acts video', ...
                'BackgroundColor', [0.55 0.85 1.00], 'FontWeight', 'bold', ...
                'Tooltip', 'After Run — render mp4 with body parts and active acts overlay', ...
                'ButtonPushedFcn', @(~,~) obj.renderActsVideo());

            uilabel(left, 'Text', '');
            obj.ShowZoneActsCheckbox = uicheckbox(left, ...
                'Text', 'Show zone acts in etogram', ...
                'Value', false, ...
                'Tooltip', ['Zone acts (corners/walls/center/etc.) are auto-' ...
                            'derived from the preset. Hide them to keep the ' ...
                            'etogram focused on built-ins + custom library.'], ...
                'ValueChangedFcn', @(~,~) obj.refreshResults());

            % Log area
            uilabel(left, 'Text', '');
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
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
            startDir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                startDir = obj.ParentApp.State.projectRoot;
            end
            switch kind
                case 'DLC'
                    [f, p] = uigetfile({'*.csv'}, 'Pick DLC csv', startDir);
                    if ~isequal(f, 0); obj.DLCField.Value = fullfile(p, f); end
                case 'Preset'
                    [f, p] = uigetfile({'*.mat'}, 'Pick preset', startDir);
                    if ~isequal(f, 0); obj.PresetField.Value = fullfile(p, f); end
                case 'Video'
                    [f, p] = uigetfile({'*.mp4;*.avi;*.mov'}, 'Pick video', startDir);
                    if ~isequal(f, 0); obj.VideoField.Value = fullfile(p, f); end
                case 'OutDir'
                    d = uigetdir(startDir, 'Output dir');
                    if ~isequal(d, 0); obj.OutDirField.Value = d; end
                case 'ActsLibrary'
                    [f, p] = uigetfile({'*.mat', 'Acts library .mat'}, ...
                        'Pick acts library', startDir);
                    if ~isequal(f, 0); obj.ActsLibraryField.Value = fullfile(p, f); end
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

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
        OutDirField

        % Threshold overrides
        RestField
        LocField
        FreezingModeDropDown

        % Run + results
        RunButton
        ResultTable

        % Plots
        TrajAxes
        TimelineAxes
        SpeedHistAxes

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
            left = uigridlayout(parent, [12, 2]);
            left.Layout.Column = 1;
            left.RowHeight = repmat({30}, 1, 12);
            left.ColumnWidth = {110, '1x'};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            uilabel(left, 'Text', 'DLC:');
            obj.DLCField = uieditfield(left, 'text', 'Value', '');
            uilabel(left, 'Text', 'Preset:');
            obj.PresetField = uieditfield(left, 'text', 'Value', '');
            uilabel(left, 'Text', 'Output dir:');
            obj.OutDirField = uieditfield(left, 'text', 'Value', '');

            % Browse row
            uilabel(left, 'Text', '');
            br = uigridlayout(left, [1, 3]);
            br.RowHeight = {28};
            br.ColumnWidth = {'1x', '1x', '1x'};
            br.Padding = [0 0 0 0];
            br.ColumnSpacing = 4;
            uibutton(br, 'Text', 'DLC...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('DLC'));
            uibutton(br, 'Text', 'Preset...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Preset'));
            uibutton(br, 'Text', 'Out dir...', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('OutDir'));

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

            % Log area
            uilabel(left, 'Text', '');
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
        end

        function buildRightResults(obj, parent)
            right = uigridlayout(parent, [3, 2]);
            right.Layout.Column = 2;
            right.RowHeight = {180, '1x', 180};
            right.ColumnWidth = {'1x', '1x'};
            right.RowSpacing = 4;
            right.ColumnSpacing = 6;
            right.Padding = [0 0 0 0];

            % Top: results table spanning both cols
            obj.ResultTable = uitable(right, 'ColumnName', ...
                {'Act', '%', 'duration', 'count', 'mean dur, s'});
            obj.ResultTable.Layout.Row = 1;
            obj.ResultTable.Layout.Column = [1 2];

            % Middle row: trajectory (left), timeline (right)
            obj.TrajAxes = uiaxes(right);
            obj.TrajAxes.Layout.Row = 2; obj.TrajAxes.Layout.Column = 1;
            title(obj.TrajAxes, 'Trajectory');
            obj.TrajAxes.DataAspectRatio = [1 1 1];
            obj.TrajAxes.YDir = 'reverse';
            obj.TrajAxes.Box = 'on';

            obj.TimelineAxes = uiaxes(right);
            obj.TimelineAxes.Layout.Row = 2; obj.TimelineAxes.Layout.Column = 2;
            title(obj.TimelineAxes, 'Acts timeline');
            obj.TimelineAxes.Box = 'on';

            % Bottom: speed histogram spanning
            obj.SpeedHistAxes = uiaxes(right);
            obj.SpeedHistAxes.Layout.Row = 3; obj.SpeedHistAxes.Layout.Column = [1 2];
            title(obj.SpeedHistAxes, 'Speed histogram');
            obj.SpeedHistAxes.Box = 'on';
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
                case 'OutDir'
                    d = uigetdir(startDir, 'Output dir');
                    if ~isequal(d, 0); obj.OutDirField.Value = d; end
            end
        end

        function refreshResults(obj)
            if isempty(obj.State.result); return; end
            r = obj.State.result;
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

            % Trajectory: bodycenter smoothed
            try
                bps = r.BodyPartsTraces;
                idx = find(strcmpi({bps.BodyPartName}, 'bodycenter'), 1);
                if isempty(idx); idx = 1; end
                cla(obj.TrajAxes);
                plot(obj.TrajAxes, bps(idx).TraceSmoothed.X, bps(idx).TraceSmoothed.Y, ...
                    'Color', [0.10 0.50 0.90], 'LineWidth', 1);
                obj.TrajAxes.DataAspectRatio = [1 1 1];
                obj.TrajAxes.YDir = 'reverse';
                title(obj.TrajAxes, sprintf('Trajectory — %s', bps(idx).BodyPartName), ...
                    'Interpreter', 'none');

                % Speed histogram
                cla(obj.SpeedHistAxes);
                v = bps(idx).VelocitySmoothed;
                if ~isempty(v)
                    histogram(obj.SpeedHistAxes, v, 50, ...
                        'FaceColor', [0.30 0.70 0.30], 'EdgeColor', 'none');
                    xlabel(obj.SpeedHistAxes, 'speed, cm/s');
                    title(obj.SpeedHistAxes, 'Speed histogram (bodycenter)');
                end
            catch
            end

            % Acts timeline
            cla(obj.TimelineAxes);
            hold(obj.TimelineAxes, 'on');
            for k = 1:n
                a = r.Acts(k).ActArrayRefine;
                if ~islogical(a) && ~isnumeric(a); continue; end
                yLine = ones(size(a)) * (n - k + 1);
                yLine(~a) = NaN;
                plot(obj.TimelineAxes, 1:numel(a), yLine, '-', 'LineWidth', 5);
            end
            obj.TimelineAxes.YTick = 1:n;
            obj.TimelineAxes.YTickLabel = flip({r.Acts.ActName});
            xlabel(obj.TimelineAxes, 'frame');
            title(obj.TimelineAxes, 'Acts timeline');
            hold(obj.TimelineAxes, 'off');
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

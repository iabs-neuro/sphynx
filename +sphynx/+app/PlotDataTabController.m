classdef PlotDataTabController < handle
% PLOTDATATABCONTROLLER  Plot Data tab: load the wide super-table CSV,
% pick a metric, auto-select a test (t-test / 1-way / 2-way / RM ANOVA),
% and render a Prism-style bar chart with significance stars.
%
% Workflow:
%   1. Browse CSV produced by Make Output Table.
%   2. Load -> metrics list + factor list populate from headers.
%   3. Pick metric + factor1 (X) + optional factor2 (legend); other
%      metadata columns can be used to split (one plot per level).
%   4. Adjust plot style (errorbar / font / size / colormap / show points)
%      and stats (auto / show stars / forced test / correction).
%   5. Plot -> axes; Save PNG; Save all metrics -> folder.

    properties
        Tab
        Figure
        ParentApp

        % Loader
        TableField
        BrowseButton
        LoadButton

        % Metric / factor controls
        MetricDropDown
        Factor1DropDown
        Factor2DropDown
        SplitDropDown

        % Style controls
        ErrBarDropDown
        ShowPointsChk
        ColormapDropDown
        FontNameDropDown
        FontSizeField
        TitleFontField
        AxisFontField

        % Stats controls
        AutoStatsChk
        ShowStarsChk
        TestDropDown
        CorrectionDropDown

        % Buttons
        PlotButton
        SavePngButton
        SaveAllButton

        % Output
        Axes
        StatsTextArea
        LogTextArea

        % State
        State
    end

    methods
        function obj = PlotDataTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('table', table.empty, 'metrics', struct([]), ...
                'factorCols', {{}}, 'idCol', '');
            obj.buildUI();
        end

        function delete(~)
        end

        % ---------- Loading ----------

        function loadTable(obj)
            p = obj.TableField.Value;
            if isempty(p) || ~isfile(p)
                obj.applog('warn', 'CSV not found: %s', p); return;
            end
            try
                T = readtable(p);
            catch ME
                obj.applog('error', 'readtable failed: %s', ME.message); return;
            end
            obj.State.table = T;
            [metrics, factorCols, idCol] = sphynx.stats.extractMetrics(T);
            obj.State.metrics    = metrics;
            obj.State.factorCols = factorCols;
            obj.State.idCol      = idCol;
            obj.populateDropDowns();
            obj.applog('info', 'Loaded %d rows x %d cols; %d metrics; factors: %s', ...
                height(T), width(T), numel(metrics), strjoin(factorCols, ','));
        end

        % ---------- Plot ----------

        function makePlot(obj)
            metricName = obj.MetricDropDown.Value;
            if isempty(metricName); return; end
            metric = obj.findMetricByLabel(metricName);
            if isempty(metric); obj.applog('warn', 'metric not found'); return; end
            longL = sphynx.stats.metricToLong(obj.State.table, metric, ...
                obj.State.idCol, obj.State.factorCols);
            longL = longL(~isnan(longL.value), :);
            f1 = obj.Factor1DropDown.Value;
            f2 = obj.Factor2DropDown.Value;
            if strcmp(f1, '<auto session>')
                f1 = 'session';
                if ~ismember('session', longL.Properties.VariableNames) || ...
                        all(cellfun('isempty', longL.session))
                    obj.applog('warn', 'metric has no session column; pick a factor'); return;
                end
            end
            if strcmp(f2, '<none>'); f2 = ''; end
            split = obj.SplitDropDown.Value;
            if strcmp(split, '<none>'); split = ''; end

            % Splitting: if split factor chosen, only plot the first level
            % on the on-screen axes. Save All handles all levels.
            if ~isempty(split) && any(strcmp(longL.Properties.VariableNames, split))
                vSplit = longL.(split);
                if ~iscell(vSplit); vSplit = cellstr(string(vSplit)); end
                levSplit = unique(vSplit, 'stable');
                if ~isempty(levSplit)
                    longL = longL(strcmp(vSplit, levSplit{1}), :);
                    obj.applog('info', 'Plotting %s=%s (use Save All for the rest)', ...
                        split, levSplit{1});
                end
            end

            [statsRes, statsNote] = obj.runOrSkipStats(longL, f1, f2);
            style = obj.collectStyle();
            style.title = sprintf('%s', metricName);
            sphynx.plot.barWithStats(obj.Axes, longL, f1, f2, statsRes, style);
            obj.refreshStatsArea(statsRes, statsNote);
        end

        function savePng(obj)
            startDir = obj.startDir();
            [f, p] = uiputfile({'*.png'}, 'Save PNG', ...
                fullfile(startDir, sprintf('%s.png', obj.MetricDropDown.Value)));
            if isequal(f, 0); return; end
            try
                exportgraphics(obj.Axes, fullfile(p, f), 'Resolution', 300);
                obj.applog('info', 'Saved %s', fullfile(p, f));
            catch ME
                obj.applog('error', 'Save failed: %s', ME.message);
            end
        end

        function saveAll(obj)
            % Iterate every metric x every split level and write a PNG.
            if isempty(obj.State.metrics)
                obj.applog('warn', 'Load a table first'); return;
            end
            startDir = obj.startDir();
            outDir = uigetdir(startDir, 'Output folder');
            if isequal(outDir, 0); return; end
            n = 0;
            f1 = obj.Factor1DropDown.Value;
            f2 = obj.Factor2DropDown.Value;
            split = obj.SplitDropDown.Value;
            if strcmp(f1, '<auto session>'); f1 = 'session'; end
            if strcmp(f2, '<none>'); f2 = ''; end
            if strcmp(split, '<none>'); split = ''; end
            style = obj.collectStyle();
            % Use an off-screen figure for fast batch render.
            fhid = figure('Visible', 'off', 'Color', 'w', ...
                'Units', 'pixels', 'Position', [100 100 720 540]);
            cleanup = onCleanup(@() close(fhid));
            ax = axes(fhid); %#ok<LAXES>
            for m = 1:numel(obj.State.metrics)
                metric = obj.State.metrics(m);
                longL = sphynx.stats.metricToLong(obj.State.table, metric, ...
                    obj.State.idCol, obj.State.factorCols);
                longL = longL(~isnan(longL.value), :);
                if isempty(longL) || height(longL) < 2; continue; end
                splitLevels = {''};
                if ~isempty(split) && any(strcmp(longL.Properties.VariableNames, split))
                    v = longL.(split);
                    if ~iscell(v); v = cellstr(string(v)); end
                    splitLevels = unique(v, 'stable');
                end
                for kS = 1:numel(splitLevels)
                    Lp = longL;
                    if ~isempty(split) && ~isempty(splitLevels{kS})
                        v = Lp.(split);
                        if ~iscell(v); v = cellstr(string(v)); end
                        Lp = Lp(strcmp(v, splitLevels{kS}), :);
                    end
                    [statsRes, ~] = obj.runOrSkipStats(Lp, f1, f2);
                    titleStr = metric.label;
                    fname = matlab.lang.makeValidName(metric.label);
                    if ~isempty(splitLevels{kS})
                        titleStr = sprintf('%s [%s=%s]', metric.label, split, splitLevels{kS});
                        fname = sprintf('%s__%s', fname, ...
                            matlab.lang.makeValidName(splitLevels{kS}));
                    end
                    style2 = style; style2.title = titleStr;
                    sphynx.plot.barWithStats(ax, Lp, f1, f2, statsRes, style2);
                    try
                        exportgraphics(ax, fullfile(outDir, [fname '.png']), 'Resolution', 300);
                        n = n + 1;
                    catch ME
                        obj.applog('warn', 'skip %s: %s', fname, ME.message);
                    end
                end
            end
            obj.applog('info', 'Saved %d plots to %s', n, outDir);
        end

        % ---------- Internal helpers ----------

        function metric = findMetricByLabel(obj, lbl)
            metric = [];
            for k = 1:numel(obj.State.metrics)
                if strcmp(obj.State.metrics(k).label, lbl)
                    metric = obj.State.metrics(k); return;
                end
            end
        end

        function style = collectStyle(obj)
            style = struct();
            style.errorbar = obj.ErrBarDropDown.Value;
            style.showPoints = obj.ShowPointsChk.Value;
            style.showStars = obj.ShowStarsChk.Value;
            style.colormap = obj.ColormapDropDown.Value;
            style.fontName = obj.FontNameDropDown.Value;
            style.fontSize = double(obj.FontSizeField.Value);
            style.titleFontSize = double(obj.TitleFontField.Value);
            style.axisFontSize = double(obj.AxisFontField.Value);
        end

        function [R, note] = runOrSkipStats(obj, longL, f1, f2)
            R = []; note = '';
            if ~obj.AutoStatsChk.Value; return; end
            factors = {};
            if ~isempty(f1) && any(strcmp(longL.Properties.VariableNames, f1))
                factors{end+1} = f1;
            end
            if ~isempty(f2) && any(strcmp(longL.Properties.VariableNames, f2))
                factors{end+1} = f2;
            end
            if isempty(factors); note = 'no factors selected'; return; end
            opts = struct( ...
                'test', obj.TestDropDown.Value, ...
                'correction', obj.CorrectionDropDown.Value);
            try
                R = sphynx.stats.runTest(longL, factors, opts);
                note = R.note;
            catch ME
                note = sprintf('stats err: %s', ME.message);
            end
        end

        function refreshStatsArea(obj, R, note)
            if isempty(R)
                obj.StatsTextArea.Value = {note};
                return;
            end
            lines = {};
            lines{end+1} = sprintf('Test: %s', R.test);
            lines{end+1} = sprintf('Factors: %s', strjoin(R.factors, ', '));
            lines{end+1} = sprintf('N subjects: %d', R.nSubjects);
            if isnumeric(R.stat); lines{end+1} = sprintf('stat=%.3f', R.stat); end
            if isnumeric(R.p);    lines{end+1} = sprintf('p=%.4g', R.p); end
            lines{end+1} = R.note;
            if ~isempty(R.pairwise) && height(R.pairwise) > 0
                lines{end+1} = '-- pairwise --';
                for r = 1:height(R.pairwise)
                    lines{end+1} = sprintf('%s vs %s : p=%.4g %s', ...
                        R.pairwise.groupA{r}, R.pairwise.groupB{r}, ...
                        R.pairwise.p(r), sphynx.stats.pStars(R.pairwise.p(r))); %#ok<AGROW>
                end
            end
            obj.StatsTextArea.Value = lines(:);
        end

        function dir = startDir(obj)
            dir = pwd;
            if ~isempty(obj.ParentApp) && isprop(obj.ParentApp, 'State') && ...
                    isfield(obj.ParentApp.State, 'projectRoot') && ...
                    ~isempty(obj.ParentApp.State.projectRoot) && ...
                    isfolder(obj.ParentApp.State.projectRoot)
                dir = obj.ParentApp.State.projectRoot;
            end
            tp = obj.TableField.Value;
            if ~isempty(tp) && isfile(tp); dir = fileparts(tp); end
        end

        function pickTable(obj)
            startDir = obj.startDir();
            [f, p] = uigetfile({'*.csv;*.xlsx;*.xls', 'Wide table (CSV / XLSX)'}, ...
                'Pick wide table', startDir);
            if ~isequal(f, 0)
                obj.TableField.Value = fullfile(p, f);
                obj.loadTable();
            end
            obj.restoreFocus();
        end

        function restoreFocus(obj)
            try
                if ~isempty(obj.Figure) && isvalid(obj.Figure); figure(obj.Figure); end
            catch
            end
        end

        function populateDropDowns(obj)
            labels = {obj.State.metrics.label};
            if isempty(labels); labels = {''}; end
            obj.MetricDropDown.Items = labels;
            obj.MetricDropDown.Value = labels{1};

            % Factor1: include 'session' auto + the explicit factor cols
            f1Items = {'<auto session>'};
            for k = 1:numel(obj.State.factorCols); f1Items{end+1} = obj.State.factorCols{k}; end
            obj.Factor1DropDown.Items = f1Items;
            % Default: first explicit factor if available, else auto session
            if numel(f1Items) > 1
                obj.Factor1DropDown.Value = f1Items{2};
            else
                obj.Factor1DropDown.Value = '<auto session>';
            end

            f2Items = [{'<none>'}, obj.State.factorCols];
            obj.Factor2DropDown.Items = f2Items;
            obj.Factor2DropDown.Value = '<none>';

            splitItems = [{'<none>'}, obj.State.factorCols];
            obj.SplitDropDown.Items = splitItems;
            obj.SplitDropDown.Value = '<none>';
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[Plot] ' fmt], varargin{:});
            if isempty(obj.LogTextArea) || ~isvalid(obj.LogTextArea); return; end
            line = sprintf(['[' upper(level) '] ' fmt], varargin{:});
            current = obj.LogTextArea.Value;
            if isempty(current); current = {}; end
            if ~iscell(current); current = cellstr(current); end
            obj.LogTextArea.Value = [{line}; current(:)];
        end

        % ---------- UI ----------

        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {360, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];
            outer.ColumnSpacing = 6;
            obj.buildLeft(outer);
            obj.buildRight(outer);
        end

        function buildLeft(obj, parent)
            left = uigridlayout(parent, [7, 1]);
            left.Layout.Column = 1;
            left.RowHeight = {64, 124, 116, 92, 36, 28, '1x'};
            left.RowSpacing = 6;
            left.Padding = [0 0 0 0];

            obj.buildLoader(left);
            obj.buildMetricRow(left);
            obj.buildStylePanel(left);
            obj.buildStatsPanel(left);
            obj.buildButtonsRow(left);
            obj.buildStatsArea(left);
        end

        function buildLoader(obj, parent)
            row = uigridlayout(parent, [2, 4]);
            row.Layout.Row = 1;
            row.RowHeight = {28, 28};
            row.ColumnWidth = {'1x', '1x', '1x', '1x'};
            row.ColumnSpacing = 4; row.RowSpacing = 4;
            row.Padding = [0 0 0 0];
            uilabel(row, 'Text', 'Wide CSV:');
            obj.TableField = uieditfield(row, 'text', 'Value', '');
            obj.TableField.Layout.Column = [2 4];
            obj.BrowseButton = uibutton(row, 'Text', 'Browse', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickTable());
            obj.LoadButton = uibutton(row, 'Text', 'Load', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.loadTable());
        end

        function buildMetricRow(obj, parent)
            row = uigridlayout(parent, [4, 2]);
            row.Layout.Row = 2;
            row.RowHeight = {26, 26, 26, 26};
            row.ColumnWidth = {110, '1x'};
            row.RowSpacing = 4; row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            uilabel(row, 'Text', 'Metric:');
            obj.MetricDropDown = uidropdown(row, 'Items', {''});
            uilabel(row, 'Text', 'Factor 1 (X):');
            obj.Factor1DropDown = uidropdown(row, 'Items', {'<auto session>'}, ...
                'Tooltip', 'Primary grouping on X axis');
            uilabel(row, 'Text', 'Factor 2 (color):');
            obj.Factor2DropDown = uidropdown(row, 'Items', {'<none>'}, ...
                'Tooltip', 'Secondary grouping (color bars); leave <none> for 1-way');
            uilabel(row, 'Text', 'Split plots by:');
            obj.SplitDropDown = uidropdown(row, 'Items', {'<none>'}, ...
                'Tooltip', 'When more than 2 factors: separate plot per level of this factor');
        end

        function buildStylePanel(obj, parent)
            row = uigridlayout(parent, [4, 4]);
            row.Layout.Row = 3;
            row.RowHeight = repmat({26}, 1, 4);
            row.ColumnWidth = {90, '1x', 90, '1x'};
            row.RowSpacing = 4; row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            uilabel(row, 'Text', 'Error bars:');
            obj.ErrBarDropDown = uidropdown(row, ...
                'Items', {'SEM','SD','95CI','none'}, 'Value', 'SEM');
            uilabel(row, 'Text', 'Colormap:');
            obj.ColormapDropDown = uidropdown(row, ...
                'Items', {'parula','jet','hsv','cool','hot','turbo','lines','gray'}, ...
                'Value', 'lines');
            uilabel(row, 'Text', 'Font:');
            obj.FontNameDropDown = uidropdown(row, ...
                'Items', {'Arial','Helvetica','Calibri','Times New Roman','Courier New'}, ...
                'Value', 'Arial');
            uilabel(row, 'Text', 'Font size:');
            obj.FontSizeField = uispinner(row, 'Value', 11, 'Limits', [6 36], 'Step', 1);
            uilabel(row, 'Text', 'Title size:');
            obj.TitleFontField = uispinner(row, 'Value', 13, 'Limits', [6 48], 'Step', 1);
            uilabel(row, 'Text', 'Axis size:');
            obj.AxisFontField = uispinner(row, 'Value', 11, 'Limits', [6 36], 'Step', 1);
            obj.ShowPointsChk = uicheckbox(row, 'Text', 'Show points', 'Value', true);
            % Filler so the grid lines up.
            uilabel(row, 'Text', '');
        end

        function buildStatsPanel(obj, parent)
            row = uigridlayout(parent, [3, 4]);
            row.Layout.Row = 4;
            row.RowHeight = {26, 26, 26};
            row.ColumnWidth = {90, '1x', 90, '1x'};
            row.RowSpacing = 4; row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.AutoStatsChk = uicheckbox(row, 'Text', 'Auto-stats', 'Value', true);
            obj.ShowStarsChk = uicheckbox(row, 'Text', 'Show stars', 'Value', true);
            uilabel(row, 'Text', '');
            uilabel(row, 'Text', '');
            uilabel(row, 'Text', 'Test:');
            obj.TestDropDown = uidropdown(row, ...
                'Items', {'auto','ttest','paired-ttest','anova1','anova2','rm-anova'}, ...
                'Value', 'auto');
            uilabel(row, 'Text', 'Correction:');
            obj.CorrectionDropDown = uidropdown(row, ...
                'Items', {'auto','tukey','bonferroni','holm','none'}, ...
                'Value', 'auto');
        end

        function buildButtonsRow(obj, parent)
            row = uigridlayout(parent, [1, 3]);
            row.Layout.Row = 5;
            row.RowHeight = {32};
            row.ColumnWidth = {'1x', '1x', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.PlotButton = uibutton(row, 'Text', 'Plot', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.makePlot());
            obj.SavePngButton = uibutton(row, 'Text', 'Save PNG', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.savePng());
            obj.SaveAllButton = uibutton(row, 'Text', 'Save all metrics', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.saveAll());
        end

        function buildStatsArea(obj, parent)
            lbl = uilabel(parent, 'Text', 'Stats output:');
            lbl.Layout.Row = 6;
            obj.StatsTextArea = uitextarea(parent, 'Editable', 'off', 'Value', {''});
            obj.StatsTextArea.Layout.Row = 7;
            obj.LogTextArea = obj.StatsTextArea;  % share the area for applog
        end

        function buildRight(obj, parent)
            right = uigridlayout(parent, [1, 1]);
            right.Layout.Column = 2;
            right.Padding = [0 0 0 0];
            obj.Axes = uiaxes(right);
            obj.Axes.Box = 'on';
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

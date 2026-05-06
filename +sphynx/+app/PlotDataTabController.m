classdef PlotDataTabController < handle
% PLOTDATATABCONTROLLER  Quick preliminary plots from a SuperTable.csv —
% bar / box / scatter per act per session, color-coded by group.
%
% MVP scope:
%   * Pick a wide CSV (output of Make Output Table).
%   * Detect mouse / group / line columns + numeric columns.
%   * Choose plot type: bar (mean ± SEM) / box / scatter.
%   * Choose which numeric column to plot.
%   * Group color-coding via a colormap dropdown.
%   * Render in axes; Save PNG button.

    properties
        Tab
        Figure
        ParentApp

        TableField
        ColumnDropDown
        GroupDropDown
        PlotTypeDropDown
        ColormapDropDown
        ShowPointsChk
        ErrorBarsDropDown

        Axes
        LogTextArea

        State
    end

    methods
        function obj = PlotDataTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('table', table.empty);
            obj.buildUI();
        end

        function delete(~)
        end

        function loadTable(obj)
            p = obj.TableField.Value;
            if isempty(p) || ~isfile(p); obj.applog('warn', 'CSV not found'); return; end
            T = readtable(p);
            obj.State.table = T;
            obj.populateColumnDropDowns();
            obj.applog('info', 'Loaded %d rows × %d cols', height(T), width(T));
        end

        function makePlot(obj)
            T = obj.State.table;
            if isempty(T); obj.applog('warn', 'Load a table first'); return; end
            col = obj.ColumnDropDown.Value;
            grp = obj.GroupDropDown.Value;
            if ~ismember(col, T.Properties.VariableNames); return; end
            grouping = ones(height(T), 1);
            grpNames = {'all'};
            if ~strcmp(grp, '<none>') && ismember(grp, T.Properties.VariableNames)
                [grouping, grpNames] = grp2idx(T.(grp));
            end
            cla(obj.Axes);
            cmap = pickColormap(obj.ColormapDropDown.Value, max(2, numel(grpNames)));
            switch obj.PlotTypeDropDown.Value
                case 'bar';     obj.drawBar(T.(col), grouping, grpNames, cmap);
                case 'box';     obj.drawBox(T.(col), grouping, grpNames, cmap);
                case 'scatter'; obj.drawScatter(T.(col), grouping, grpNames, cmap);
            end
            title(obj.Axes, col, 'Interpreter', 'none');
            ylabel(obj.Axes, col, 'Interpreter', 'none');
            grid(obj.Axes, 'on');
        end

        function savePng(obj)
            [f, p] = uiputfile({'*.png'}, 'Save plot as');
            if isequal(f, 0); return; end
            outPath = fullfile(p, f);
            exportgraphics(obj.Axes, outPath);
            obj.applog('info', 'Saved %s', outPath);
        end
    end

    methods (Access = private)
        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {320, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];
            outer.ColumnSpacing = 6;
            obj.buildLeft(outer);
            obj.buildRight(outer);
        end

        function buildLeft(obj, parent)
            left = uigridlayout(parent, [12, 2]);
            left.Layout.Column = 1;
            left.RowHeight = repmat({30}, 1, 12);
            left.ColumnWidth = {110, '1x'};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            uilabel(left, 'Text', 'Wide CSV:');
            obj.TableField = uieditfield(left, 'text', 'Value', '');
            uibutton(left, 'Text', 'Browse', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickTable());
            uibutton(left, 'Text', 'Load', 'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) obj.loadTable());

            uilabel(left, 'Text', 'Plot column:');
            obj.ColumnDropDown = uidropdown(left, 'Items', {''});

            uilabel(left, 'Text', 'Group by:');
            obj.GroupDropDown = uidropdown(left, 'Items', {'<none>'});

            uilabel(left, 'Text', 'Plot type:');
            obj.PlotTypeDropDown = uidropdown(left, ...
                'Items', {'bar', 'box', 'scatter'}, 'Value', 'bar');

            uilabel(left, 'Text', 'Colormap:');
            obj.ColormapDropDown = uidropdown(left, ...
                'Items', {'parula', 'jet', 'hsv', 'cool', 'hot', 'plasma', 'viridis'}, ...
                'Value', 'parula');

            uilabel(left, 'Text', 'Error bars:');
            obj.ErrorBarsDropDown = uidropdown(left, ...
                'Items', {'SEM', 'SD', 'none'}, 'Value', 'SEM');

            obj.ShowPointsChk = uicheckbox(left, 'Text', 'Overlay individual points', 'Value', true);
            uilabel(left, 'Text', '');

            uilabel(left, 'Text', '');
            br = uigridlayout(left, [1, 2]);
            br.RowHeight = {30};
            br.ColumnWidth = {'1x', '1x'};
            br.Padding = [0 0 0 0];
            br.ColumnSpacing = 4;
            uibutton(br, 'Text', 'Plot', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.makePlot());
            uibutton(br, 'Text', 'Save PNG', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.savePng());

            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
        end

        function buildRight(obj, parent)
            right = uigridlayout(parent, [1, 1]);
            right.Layout.Column = 2;
            right.Padding = [0 0 0 0];
            obj.Axes = uiaxes(right);
            obj.Axes.Box = 'on';
        end

        function pickTable(obj)
            startDir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                startDir = obj.ParentApp.State.projectRoot;
            end
            [f, p] = uigetfile({'*.csv'}, 'Pick wide table CSV', startDir);
            if ~isequal(f, 0); obj.TableField.Value = fullfile(p, f); end
        end

        function populateColumnDropDowns(obj)
            T = obj.State.table;
            numCols = T.Properties.VariableNames(varfun(@isnumeric, T, 'OutputFormat', 'uniform'));
            obj.ColumnDropDown.Items = numCols;
            if ~isempty(numCols); obj.ColumnDropDown.Value = numCols{1}; end
            txtCols = T.Properties.VariableNames(~varfun(@isnumeric, T, 'OutputFormat', 'uniform'));
            grpItems = [{'<none>'}, txtCols];
            obj.GroupDropDown.Items = grpItems;
            if ismember('group', txtCols); obj.GroupDropDown.Value = 'group';
            else; obj.GroupDropDown.Value = '<none>';
            end
        end

        function drawBar(obj, vals, grp, names, cmap)
            ng = numel(names);
            means = zeros(1, ng); errs = zeros(1, ng);
            for k = 1:ng
                v = vals(grp == k);
                v = v(~isnan(v));
                if isempty(v); continue; end
                means(k) = mean(v);
                switch obj.ErrorBarsDropDown.Value
                    case 'SEM'; errs(k) = std(v) / sqrt(numel(v));
                    case 'SD';  errs(k) = std(v);
                    case 'none'; errs(k) = 0;
                end
            end
            hold(obj.Axes, 'on');
            for k = 1:ng
                bar(obj.Axes, k, means(k), 'FaceColor', cmap(k, :));
            end
            if any(errs)
                errorbar(obj.Axes, 1:ng, means, errs, 'k', 'LineStyle', 'none', 'LineWidth', 1.2);
            end
            if obj.ShowPointsChk.Value
                for k = 1:ng
                    v = vals(grp == k); v = v(~isnan(v));
                    jit = (rand(numel(v), 1) - 0.5) * 0.3;
                    scatter(obj.Axes, k + jit, v, 30, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
                end
            end
            hold(obj.Axes, 'off');
            obj.Axes.XTick = 1:ng;
            obj.Axes.XTickLabel = names;
        end

        function drawBox(obj, vals, grp, names, ~)
            data = {};
            for k = 1:numel(names); data{end+1} = vals(grp == k); end %#ok<AGROW>
            cla(obj.Axes);
            hold(obj.Axes, 'on');
            for k = 1:numel(names)
                v = data{k}; v = v(~isnan(v));
                if isempty(v); continue; end
                q = quantile(v, [0.25 0.5 0.75]);
                whiskers = [min(v), max(v)];
                rectangle(obj.Axes, 'Position', [k-0.3, q(1), 0.6, q(3)-q(1)], ...
                    'EdgeColor', 'k', 'LineWidth', 1.2);
                plot(obj.Axes, [k-0.3, k+0.3], [q(2), q(2)], 'k', 'LineWidth', 1.5);
                plot(obj.Axes, [k, k], [whiskers(1), q(1)], 'k--');
                plot(obj.Axes, [k, k], [q(3), whiskers(2)], 'k--');
                if obj.ShowPointsChk.Value
                    jit = (rand(numel(v), 1) - 0.5) * 0.3;
                    scatter(obj.Axes, k + jit, v, 30, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
                end
            end
            hold(obj.Axes, 'off');
            obj.Axes.XTick = 1:numel(names);
            obj.Axes.XTickLabel = names;
            obj.Axes.XLim = [0.5 numel(names) + 0.5];
        end

        function drawScatter(obj, vals, grp, names, cmap)
            cla(obj.Axes);
            hold(obj.Axes, 'on');
            for k = 1:numel(names)
                v = vals(grp == k); v = v(~isnan(v));
                jit = (rand(numel(v), 1) - 0.5) * 0.3;
                scatter(obj.Axes, k + jit, v, 50, cmap(k, :), 'filled');
            end
            hold(obj.Axes, 'off');
            obj.Axes.XTick = 1:numel(names);
            obj.Axes.XTickLabel = names;
            obj.Axes.XLim = [0.5 numel(names) + 0.5];
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

function cmap = pickColormap(name, n)
    n = max(2, n);
    try
        switch lower(name)
            case 'parula';  cmap = parula(n);
            case 'jet';     cmap = jet(n);
            case 'hsv';     cmap = hsv(n);
            case 'cool';    cmap = cool(n);
            case 'hot';     cmap = hot(n);
            case 'plasma';  cmap = feval('plasma', n);
            case 'viridis'; cmap = feval('viridis', n);
            otherwise;      cmap = parula(n);
        end
    catch
        cmap = parula(n);
    end
end

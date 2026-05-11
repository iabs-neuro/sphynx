classdef MakeOutputTableTabController < handle
% MAKEOUTPUTTABLETABCONTROLLER  Build a wide Prism-friendly table from
% a folder of analyzeSession-saved .mat files, with a per-act metric
% matrix (rows = acts, cols = metrics, logical checkboxes).
%
% Defaults come from sphynx.acts.actParams (the legacy
% behavior_act_params equivalent). A user-edited set can be saved /
% loaded as a .mat for project-specific defaults.

    properties
        Tab
        Figure
        ParentApp

        % Loader strip (mirrors other tabs)
        RootPathField
        BatchDirField
        MetadataField
        OutCsvField
        RootButton
        BatchDirButton
        MetadataButton
        OutCsvButton

        % Per-act metric matrix
        ActMetricTable
        ScanActsButton
        ApplyDefaultsButton
        LoadDefaultsButton
        SaveDefaultsButton
        SelectAllButton
        ClearAllButton

        % Table options
        NaNDropDown
        SortDropDown

        % Run / save
        BuildButton
        SaveCsvButton

        % Results
        WideTable
        TidyTable

        % Log
        LogTextArea

        % State
        State
    end

    properties (Constant)
        % Columns of the per-act metric matrix (left-to-right).
        MetricColumns = {'ActNumber', 'ActPercent', 'ActDuration', ...
            'ActMeanTime', 'ActMedianTime', 'ActMeanVelocity', ...
            'Distance', 'FirstStartSec', 'FirstEndSec', 'LastEndSec'};
        MetricColumnLabels = {'count', 'percent', 'duration_s', ...
            'mean_dur_s', 'median_dur_s', 'mean_v_cm_s', ...
            'distance_cm', 'first_start_s', 'first_end_s', 'last_end_s'};
    end

    methods
        function obj = MakeOutputTableTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('superTable', [], 'actNames', {{}}, ...
                'metricMatrix', logical([]));
            obj.buildUI();
            obj.inheritRootFromParentApp();
        end

        function delete(~)
        end

        % ---------- Scan + defaults ----------------------------------

        function scanActsInBatchDir(obj)
            % Walk the batch dir, pull act names off every WorkSpace
            % .mat, and populate the metric matrix.
            d = obj.BatchDirField.Value;
            if isempty(d) || ~isfolder(d)
                obj.applog('warn', 'Pick a batch dir first'); return;
            end
            files = dir(fullfile(d, '*_WorkSpace.mat'));
            if isempty(files)
                files = dir(fullfile(d, '**', '*_WorkSpace.mat'));
            end
            if isempty(files)
                obj.applog('warn', 'No *_WorkSpace.mat found in %s', d);
                return;
            end
            names = {};
            for k = 1:numel(files)
                try
                    s = load(fullfile(files(k).folder, files(k).name), 'Acts');
                    if isfield(s, 'Acts') && ~isempty(s.Acts)
                        names = union(names, {s.Acts.ActName});
                    end
                catch
                end
            end
            names = names(:)';
            if isempty(names)
                obj.applog('warn', 'No acts found in any .mat'); return;
            end
            obj.State.actNames = names;
            obj.applyDefaults();
            obj.applog('info', 'Scanned %d sessions -> %d acts', ...
                numel(files), numel(names));
        end

        function applyDefaults(obj)
            % Build the metric matrix from sphynx.acts.actParams. Acts
            % not in actParams get an empty row (user can tick).
            n = numel(obj.State.actNames);
            m = numel(obj.MetricColumns);
            M = false(n, m);
            try
                defaults = sphynx.acts.actParams();
            catch
                defaults = struct();
            end
            for k = 1:n
                nm = obj.State.actNames{k};
                row = false(1, m);
                if isfield(defaults, nm)
                    metrics = defaults.(nm);
                    if isstring(metrics); metrics = cellstr(metrics); end
                    if ischar(metrics); metrics = {metrics}; end
                    for mk = 1:numel(metrics)
                        col = find(strcmpi(obj.MetricColumns, metrics{mk}), 1);
                        if ~isempty(col); row(col) = true; end
                    end
                end
                M(k, :) = row;
            end
            obj.State.metricMatrix = M;
            obj.refreshActMetricTable();
        end

        function loadDefaults(obj)
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mat'}, 'Load metric matrix', startDir);
            if isequal(f, 0); return; end
            try
                s = load(fullfile(p, f));
            catch ME
                obj.applog('error', 'Load failed: %s', ME.message); return;
            end
            if ~isfield(s, 'metrics') || ~isstruct(s.metrics)
                obj.applog('warn', 'File has no `metrics` struct'); return;
            end
            obj.applyMatrixFromStruct(s.metrics);
            obj.applog('info', 'Loaded metric matrix from %s', fullfile(p, f));
        end

        function saveDefaults(obj)
            if isempty(obj.State.actNames)
                obj.applog('warn', 'Scan acts first'); return;
            end
            startDir = obj.resourceStartDir();
            [f, p] = uiputfile({'*.mat'}, 'Save metric matrix', ...
                fullfile(startDir, 'output_table_metrics.mat'));
            if isequal(f, 0); return; end
            metrics = obj.metricMatrixToStruct(); %#ok<NASGU>
            try
                save(fullfile(p, f), 'metrics');
                obj.applog('info', 'Saved metric matrix to %s', fullfile(p, f));
            catch ME
                obj.applog('error', 'Save failed: %s', ME.message);
            end
        end

        function selectAll(obj)
            if isempty(obj.State.actNames); return; end
            obj.State.metricMatrix = true(numel(obj.State.actNames), ...
                numel(obj.MetricColumns));
            obj.refreshActMetricTable();
        end

        function clearAll(obj)
            if isempty(obj.State.actNames); return; end
            obj.State.metricMatrix = false(numel(obj.State.actNames), ...
                numel(obj.MetricColumns));
            obj.refreshActMetricTable();
        end

        function s = metricMatrixToStruct(obj)
            s = struct();
            for k = 1:numel(obj.State.actNames)
                row = obj.State.metricMatrix(k, :);
                if ~any(row); continue; end
                s.(matlab.lang.makeValidName(obj.State.actNames{k})) = ...
                    obj.MetricColumns(row);
            end
        end

        function applyMatrixFromStruct(obj, s)
            % Update the matrix from a saved metrics struct. Acts in
            % the struct but not in the current scan are added to the
            % list. Acts not in the struct keep whatever they had.
            fns = fieldnames(s);
            if isempty(fns); return; end
            % Add any new acts at the bottom of the matrix.
            for k = 1:numel(fns)
                if ~any(strcmpi(obj.State.actNames, fns{k}))
                    obj.State.actNames{end+1} = fns{k};
                    obj.State.metricMatrix(end+1, :) = false; %#ok<AGROW>
                end
            end
            % Re-fill rows.
            for k = 1:numel(obj.State.actNames)
                nm = obj.State.actNames{k};
                idx = find(strcmpi(fns, nm), 1);
                if isempty(idx); continue; end
                metrics = s.(fns{idx});
                if isstring(metrics); metrics = cellstr(metrics); end
                if ischar(metrics); metrics = {metrics}; end
                row = false(1, numel(obj.MetricColumns));
                for mk = 1:numel(metrics)
                    col = find(strcmpi(obj.MetricColumns, metrics{mk}), 1);
                    if ~isempty(col); row(col) = true; end
                end
                obj.State.metricMatrix(k, :) = row;
            end
            obj.refreshActMetricTable();
        end

        % ---------- Build ----------------------------------

        function buildTable(obj)
            d = obj.BatchDirField.Value;
            if isempty(d) || ~isfolder(d)
                obj.applog('warn', 'Pick a batch dir first'); return;
            end
            if isempty(obj.State.actNames)
                obj.scanActsInBatchDir();
            end
            if isempty(obj.State.actNames)
                obj.applog('warn', 'No acts to build the table from'); return;
            end

            files = dir(fullfile(d, '*_WorkSpace.mat'));
            if isempty(files)
                files = dir(fullfile(d, '**', '*_WorkSpace.mat'));
            end
            if isempty(files)
                obj.applog('warn', 'No *_WorkSpace.mat in %s', d); return;
            end
            obj.applog('info', 'Reading %d session files...', numel(files));

            batch = struct('SessionName', {}, 'Acts', {}, ...
                'Distance', {}, 'Velocity', {});
            for k = 1:numel(files)
                p = fullfile(files(k).folder, files(k).name);
                try
                    s = load(p);
                    [~, base, ~] = fileparts(files(k).name);
                    base = regexprep(base, '_WorkSpace$', '');
                    rec.SessionName = base;
                    rec.Acts = getOr(s, 'Acts', []);
                    rec.Distance = NaN; rec.Velocity = NaN;
                    if isfield(s, 'BodyPartsTraces') && ~isempty(s.BodyPartsTraces)
                        bcIdx = find(strcmpi({s.BodyPartsTraces.BodyPartName}, 'bodycenter'), 1);
                        if isempty(bcIdx)
                            bcIdx = find(strcmpi({s.BodyPartsTraces.BodyPartName}, 'tailbase'), 1);
                        end
                        if ~isempty(bcIdx)
                            rec.Distance = getOr(s.BodyPartsTraces(bcIdx), 'AverageDistance', NaN);
                            rec.Velocity = getOr(s.BodyPartsTraces(bcIdx), 'AverageSpeed', NaN);
                        end
                    end
                    batch(end+1) = rec; %#ok<AGROW>
                catch ME
                    obj.applog('warn', 'Skipped %s: %s', files(k).name, ME.message);
                end
            end

            meta = table.empty;
            if ~isempty(obj.MetadataField.Value) && isfile(obj.MetadataField.Value)
                meta = readtable(obj.MetadataField.Value);
            end

            metricsByAct = obj.metricMatrixToStruct();
            ST = sphynx.pipeline.buildSuperTable(batch, ...
                'Metadata', meta, ...
                'MetricsByAct', metricsByAct, ...
                'NaNPolicy', obj.NaNDropDown.Value, ...
                'SortBy', strsplit(obj.SortDropDown.Value, ','));
            obj.State.superTable = ST;
            obj.refreshTables();
            obj.applog('info', 'Built table: %d rows x %d cols (wide), %d rows tidy', ...
                height(ST.Wide), width(ST.Wide), height(ST.Tidy));
        end

        function saveCsv(obj)
            if isempty(obj.State.superTable)
                obj.applog('warn', 'Build the table first'); return;
            end
            outPath = obj.OutCsvField.Value;
            if isempty(outPath)
                obj.applog('warn', 'Pick an output csv'); return;
            end
            writetable(obj.State.superTable.Wide, outPath);
            tidyPath = strrep(outPath, '.csv', '_tidy.csv');
            writetable(obj.State.superTable.Tidy, tidyPath);
            obj.applog('info', 'Saved %s and %s', outPath, tidyPath);
        end
    end

    methods (Access = private)
        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {460, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];
            outer.ColumnSpacing = 6;
            obj.buildLeft(outer);
            obj.buildRight(outer);
        end

        function buildLeft(obj, parent)
            left = uigridlayout(parent, [7, 1]);
            left.Layout.Column = 1;
            % Loader / matrix toolbar / matrix table / options /
            % build+save / log.
            left.RowHeight = {64, 28, '1x', 30, 30, 36, 90};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            obj.buildLoaderStrip(left);
            obj.buildMatrixToolbar(left);
            obj.buildMatrixTable(left);
            obj.buildOptionsRow(left);
            obj.buildSecondaryToolbar(left);
            obj.buildBuildRow(left);
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
            obj.LogTextArea.Layout.Row = 7;
        end

        function buildLoaderStrip(obj, parent)
            row = uigridlayout(parent, [2, 4]);
            row.Layout.Row = 1;
            row.RowHeight = {28, 26};
            row.ColumnWidth = {'1x', '1x', '1x', '1x'};
            row.RowSpacing = 4; row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.RootButton = uibutton(row, 'Text', 'Root', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Project root', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Root'));
            obj.BatchDirButton = uibutton(row, 'Text', 'Batch dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Folder with per-session *_WorkSpace.mat', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Batch'));
            obj.MetadataButton = uibutton(row, 'Text', 'Metadata', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'CSV: session_name, mouse, session, group, line', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Metadata'));
            obj.OutCsvButton = uibutton(row, 'Text', 'Out csv', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Where to write super_table.csv', ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('OutCsv'));

            obj.RootPathField    = uieditfield(row, 'text', 'Value', '');
            obj.BatchDirField    = uieditfield(row, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.scanActsInBatchDir());
            obj.MetadataField    = uieditfield(row, 'text', 'Value', '');
            obj.OutCsvField      = uieditfield(row, 'text', 'Value', '');
        end

        function buildMatrixToolbar(obj, parent)
            row = uigridlayout(parent, [1, 6]);
            row.Layout.Row = 2;
            row.RowHeight = {26};
            row.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.ScanActsButton = uibutton(row, 'Text', 'Scan acts', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Walk batch dir and refresh act list', ...
                'ButtonPushedFcn', @(~,~) obj.scanActsInBatchDir());
            obj.ApplyDefaultsButton = uibutton(row, 'Text', 'Reset to default', ...
                'BackgroundColor', semanticColor('info'), ...
                'Tooltip', 'Built-in defaults from sphynx.acts.actParams', ...
                'ButtonPushedFcn', @(~,~) obj.applyDefaults());
            obj.LoadDefaultsButton = uibutton(row, 'Text', 'Load .mat', ...
                'BackgroundColor', semanticColor('info'), ...
                'Tooltip', 'Load custom metric matrix from .mat', ...
                'ButtonPushedFcn', @(~,~) obj.loadDefaults());
            obj.SaveDefaultsButton = uibutton(row, 'Text', 'Save .mat', ...
                'BackgroundColor', semanticColor('info'), ...
                'Tooltip', 'Save current matrix as default', ...
                'ButtonPushedFcn', @(~,~) obj.saveDefaults());
            obj.SelectAllButton = uibutton(row, 'Text', 'Select all', ...
                'ButtonPushedFcn', @(~,~) obj.selectAll());
            obj.ClearAllButton = uibutton(row, 'Text', 'Clear all', ...
                'ButtonPushedFcn', @(~,~) obj.clearAll());
        end

        function buildMatrixTable(obj, parent)
            % uitable with logical checkboxes per (act, metric).
            obj.ActMetricTable = uitable(parent, ...
                'ColumnName', [{'act'}, obj.MetricColumnLabels], ...
                'ColumnFormat', [{'char'}, repmat({'logical'}, 1, numel(obj.MetricColumns))], ...
                'ColumnEditable', [false, true(1, numel(obj.MetricColumns))], ...
                'ColumnWidth', [{120}, repmat({54}, 1, numel(obj.MetricColumns))], ...
                'CellEditCallback', @(~, evt) obj.onMatrixEdited(evt));
            obj.ActMetricTable.Layout.Row = 3;
        end

        function buildOptionsRow(obj, parent)
            row = uigridlayout(parent, [1, 4]);
            row.Layout.Row = 4;
            row.RowHeight = {26};
            row.ColumnWidth = {'fit', 100, 'fit', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            uilabel(row, 'Text', 'NaN:');
            obj.NaNDropDown = uidropdown(row, 'Items', {'keep', 'zero'}, ...
                'Value', 'keep');
            uilabel(row, 'Text', 'Sort by:');
            obj.SortDropDown = uidropdown(row, ...
                'Items', {'group,line,mouse', 'mouse', 'line,mouse', 'group,mouse'}, ...
                'Value', 'group,line,mouse');
        end

        function buildSecondaryToolbar(~, parent)
            % Reserved for future / placeholder so the row layout
            % stays consistent.
            uilabel(parent, 'Text', '', 'Visible', 'off');
        end

        function buildBuildRow(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 6;
            row.RowHeight = {32};
            row.ColumnWidth = {'1x', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.BuildButton = uibutton(row, 'Text', 'Build table', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.buildTable());
            obj.SaveCsvButton = uibutton(row, 'Text', 'Save CSV', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.saveCsv());
        end

        function buildRight(obj, parent)
            right = uigridlayout(parent, [2, 1]);
            right.Layout.Column = 2;
            right.RowHeight = {'2x', '1x'};
            right.RowSpacing = 4;
            right.Padding = [0 0 0 0];
            obj.WideTable = uitable(right);
            obj.TidyTable = uitable(right);
        end

        function refreshActMetricTable(obj)
            if isempty(obj.State.actNames)
                obj.ActMetricTable.Data = {};
                return;
            end
            n = numel(obj.State.actNames);
            m = numel(obj.MetricColumns);
            data = cell(n, 1 + m);
            for k = 1:n
                data{k, 1} = obj.State.actNames{k};
                for c = 1:m
                    data{k, c + 1} = obj.State.metricMatrix(k, c);
                end
            end
            obj.ActMetricTable.Data = data;
        end

        function onMatrixEdited(obj, evt)
            % evt.Indices = [row, col]
            r = evt.Indices(1); c = evt.Indices(2);
            if c < 2; return; end  % act-name column is read-only
            obj.State.metricMatrix(r, c - 1) = logical(evt.NewData);
        end

        function pickPath(obj, kind)
            startDir = obj.resourceStartDir();
            switch kind
                case 'Root'
                    d = uigetdir(startDir, 'Project root');
                    if ~isequal(d, 0); obj.RootPathField.Value = d; end
                case 'Batch'
                    d = uigetdir(startDir, 'Batch results dir');
                    if ~isequal(d, 0)
                        obj.BatchDirField.Value = d;
                        obj.scanActsInBatchDir();
                    end
                case 'Metadata'
                    [f, p] = uigetfile({'*.csv'}, 'Metadata CSV', startDir);
                    if ~isequal(f, 0); obj.MetadataField.Value = fullfile(p, f); end
                case 'OutCsv'
                    [f, p] = uiputfile({'*.csv'}, 'Output CSV', ...
                        fullfile(startDir, 'super_table.csv'));
                    if ~isequal(f, 0); obj.OutCsvField.Value = fullfile(p, f); end
            end
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
            if ~isempty(obj.BatchDirField) ...
                    && ~isempty(obj.BatchDirField.Value) ...
                    && isfolder(obj.BatchDirField.Value)
                dir = obj.BatchDirField.Value; return;
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

        function refreshTables(obj)
            if isempty(obj.State.superTable); return; end
            ST = obj.State.superTable;
            obj.WideTable.ColumnName = ST.Wide.Properties.VariableNames;
            obj.WideTable.Data = table2cell(ST.Wide);
            obj.TidyTable.ColumnName = ST.Tidy.Properties.VariableNames;
            obj.TidyTable.Data = table2cell(head(ST.Tidy, min(200, height(ST.Tidy))));
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[OutputTbl] ' fmt], varargin{:});
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

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
        DistUnitDropDown
        DistScopeDropDown

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
            % R26: also fall back to a per-family pattern for Barnes-
            % default acts (nose_at_* / body_at_* / mouse_inside_*) so
            % the 60-odd hole variants get sensible default ticks
            % without hard-coding every objectN entry in actParams.
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
                else
                    metrics = obj.barnesActDefaults(nm);
                end
                if isstring(metrics); metrics = cellstr(metrics); end
                if ischar(metrics); metrics = {metrics}; end
                for mk = 1:numel(metrics)
                    col = find(strcmpi(obj.MetricColumns, metrics{mk}), 1);
                    if ~isempty(col); row(col) = true; end
                end
                M(k, :) = row;
            end
            obj.State.metricMatrix = M;
            obj.refreshActMetricTable();
        end

        function metrics = barnesActDefaults(~, actName) %#ok<INUSD>
            % R27: Barnes default-act families ship with NO pre-ticked
            % metrics. Earlier R26 ticked count / percent / duration
            % (and FirstStartSec for nose_at_*) by default, which Mr P
            % preferred to leave unset so the user picks per study.
            % Returning empty here means every Barnes act starts with
            % an empty row in the metric matrix; sphynx.acts.actParams
            % entries (legacy non-Barnes acts) still get their normal
            % default ticks.
            metrics = {};
        end

        function loadDefaults(obj)
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mat'}, 'Load metric matrix', startDir);
            obj.restoreFocus();
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
            obj.restoreFocus();
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

        function names = collectBarnesFieldNames(~, files)
            % R26: union of fieldnames(BarnesMetrics) across every
            % _WorkSpace.mat in the scan. Returns {} when nothing has
            % BarnesMetrics. Used by buildTable to keep the struct
            % array shape uniform across sessions.
            names = {};
            for k = 1:numel(files)
                p = fullfile(files(k).folder, files(k).name);
                try
                    s = load(p, 'BarnesMetrics');
                catch
                    continue;
                end
                if ~isfield(s, 'BarnesMetrics') || ~isstruct(s.BarnesMetrics)
                    continue;
                end
                names = union(names, fieldnames(s.BarnesMetrics));
            end
            names = names(:)';
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

            % R26: pre-discover Barnes field names across the whole
            % batch so every rec carries the same struct shape (struct
            % arrays in MATLAB demand uniform fields). When no session
            % has BarnesMetrics, barnesFieldNames stays empty and
            % nothing is added.
            barnesFieldNames = obj.collectBarnesFieldNames(files);

            % batch struct array needs uniform fieldnames or
            % `batch(end+1) = rec` throws -- pre-include every
            % Barnes_<FieldName> we discovered so each rec has the
            % same shape.
            batchTemplate = struct('SessionName', {}, 'Acts', {}, ...
                'Distance', {}, 'Velocity', {});
            for bfn = 1:numel(barnesFieldNames)
                batchTemplate(1).(['Barnes_' barnesFieldNames{bfn}]) = NaN;
            end
            batch = batchTemplate([]);
            for k = 1:numel(files)
                p = fullfile(files(k).folder, files(k).name);
                try
                    s = load(p);
                    [~, parentName] = fileparts(files(k).folder);
                    [~, batchName]  = fileparts(d);
                    if ~isempty(parentName) && ~strcmp(parentName, batchName)
                        rec.SessionName = parentName;
                    else
                        [~, base, ~] = fileparts(files(k).name);
                        base = regexprep(base, '_WorkSpace$', '');
                        base = regexprep(base, 'DLC_.*$', '');
                        rec.SessionName = base;
                    end
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
                    % R26: flatten BarnesMetrics fields into the rec
                    % so buildSuperTable's addBarnesColumns picks them
                    % up. Sessions without BarnesMetrics still emit
                    % every field (set to NaN) to keep the struct
                    % array shape uniform.
                    bm = getOr(s, 'BarnesMetrics', struct());
                    for bfn = 1:numel(barnesFieldNames)
                        fn = barnesFieldNames{bfn};
                        if isstruct(bm) && isfield(bm, fn)
                            rec.(['Barnes_' fn]) = bm.(fn);
                        else
                            rec.(['Barnes_' fn]) = NaN;
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
            distUnit  = obj.DistUnitDropDown.Value;
            distScope = obj.DistScopeDropDown.Value;
            if strcmp(distScope, 'general only')
                perActUnit = 'cm';
                generalUnit = distUnit;
            else
                perActUnit = distUnit;
                generalUnit = distUnit;
            end
            ST = sphynx.pipeline.buildSuperTable(batch, ...
                'Metadata', meta, ...
                'MetricsByAct', metricsByAct, ...
                'NaNPolicy', obj.NaNDropDown.Value, ...
                'SortBy', strsplit(obj.SortDropDown.Value, ','), ...
                'GeneralDistanceUnit', generalUnit, ...
                'PerActDistanceUnit', perActUnit);
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
                'Tooltip', 'CSV/XLSX: ID_mouse + ID_group/ID_line/any ID_* columns', ...
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
                'Items', {'line,group,mouse', 'group,line,mouse', 'mouse', 'line,mouse', 'group,mouse'}, ...
                'Value', 'line,group,mouse', ...
                'Editable', 'on', ...
                'Tooltip', 'Comma-separated metadata columns to sort by (e.g. sex,drug,mouse)');
        end

        function buildSecondaryToolbar(obj, parent)
            % Distance-unit options.
            row = uigridlayout(parent, [1, 4]);
            row.Layout.Row = 5;
            row.RowHeight = {26};
            row.ColumnWidth = {'fit', 80, 'fit', '1x'};
            row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            uilabel(row, 'Text', 'Dist unit:');
            obj.DistUnitDropDown = uidropdown(row, ...
                'Items', {'cm', 'm'}, ...
                'Value', 'cm', ...
                'Tooltip', 'Distance output unit (rounding: cm->integer, m->2 dec)');
            uilabel(row, 'Text', 'Apply to:');
            obj.DistScopeDropDown = uidropdown(row, ...
                'Items', {'all', 'general only'}, ...
                'Value', 'all', ...
                'Tooltip', 'all = both session-wide and per-act distance; general only = leave per-act distance in cm');
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
                    [f, p] = uigetfile( ...
                        {'*.csv;*.xlsx;*.xls', 'Metadata (*.csv, *.xlsx, *.xls)'; ...
                         '*.*', 'All files'}, ...
                        'Metadata file', startDir);
                    if ~isequal(f, 0); obj.MetadataField.Value = fullfile(p, f); end
                case 'OutCsv'
                    [f, p] = uiputfile({'*.csv'}, 'Output CSV', ...
                        fullfile(startDir, 'super_table.csv'));
                    if ~isequal(f, 0); obj.OutCsvField.Value = fullfile(p, f); end
            end
            obj.restoreFocus();
        end

        function restoreFocus(obj)
            % Bring the main Sphynx window back to front after any
            % modal picker so the user does not get pushed to other
            % apps. R27: drawnow forces the OS to actually swap focus
            % when figure() alone leaves the window in the background
            % (Windows R2020a quirk).
            try
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    figure(obj.Figure);
                    drawnow;
                end
            catch
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

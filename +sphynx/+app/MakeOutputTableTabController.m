classdef MakeOutputTableTabController < handle
% MAKEOUTPUTTABLETABCONTROLLER  Build a wide Prism-friendly table from
% a folder of analyzeSession-saved .mat files.
%
% MVP scope:
%   * Pick a folder of *_WorkSpace.mat (the io.saveSession output).
%   * Optionally pick a metadata.csv (mouse, group, line, session,
%     session_name) — otherwise mouse/session are parsed from filenames.
%   * Pick which metrics to include (ActPercent / ActDuration /
%     ActNumber / ActMeanTime).
%   * Choose NaN policy (keep / zero) and sort key.
%   * Run -> wide table is shown in a uitable + tidy table preview.
%   * Save CSV (Prism-friendly).

    properties
        Tab
        Figure
        ParentApp

        BatchDirField
        MetadataField
        MetricsListBox
        NaNDropDown
        SortDropDown
        OutCsvField

        WideTable
        TidyTable
        LogTextArea

        State
    end

    methods
        function obj = MakeOutputTableTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('superTable', []);
            obj.buildUI();
        end

        function delete(~)
        end

        function buildTable(obj)
            d = obj.BatchDirField.Value;
            if isempty(d) || ~isfolder(d)
                obj.applog('warn', 'Pick a batch dir first'); return;
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
                        % Use tailbase or bodycenter for distance/velocity
                        tIdx = find(strcmpi({s.BodyPartsTraces.BodyPartName}, 'tailbase'), 1);
                        if isempty(tIdx)
                            tIdx = find(strcmpi({s.BodyPartsTraces.BodyPartName}, 'bodycenter'), 1);
                        end
                        if ~isempty(tIdx)
                            rec.Distance = getOr(s.BodyPartsTraces(tIdx), 'AverageDistance', NaN);
                            rec.Velocity = getOr(s.BodyPartsTraces(tIdx), 'AverageSpeed', NaN);
                        end
                    end
                    batch(end+1) = rec; %#ok<AGROW>
                catch ME
                    obj.applog('warn', 'Skipped %s: %s', files(k).name, ME.message);
                end
            end

            % Metadata
            meta = table.empty;
            if ~isempty(obj.MetadataField.Value) && isfile(obj.MetadataField.Value)
                meta = readtable(obj.MetadataField.Value);
            end

            % Metrics
            metrics = obj.MetricsListBox.Value;
            if ischar(metrics); metrics = {metrics}; end
            if isempty(metrics)
                metrics = {'ActPercent', 'ActDuration', 'ActNumber', 'ActMeanTime'};
            end

            ST = sphynx.pipeline.buildSuperTable(batch, ...
                'Metadata', meta, ...
                'Metrics', metrics, ...
                'NaNPolicy', obj.NaNDropDown.Value, ...
                'SortBy', strsplit(obj.SortDropDown.Value, ','));
            obj.State.superTable = ST;
            obj.refreshTables();
            obj.applog('info', 'Built table: %d rows x %d cols (wide), %d rows tidy.', ...
                height(ST.Wide), width(ST.Wide), height(ST.Tidy));
        end

        function saveCsv(obj)
            if isempty(obj.State.superTable); obj.applog('warn', 'Build the table first'); return; end
            outPath = obj.OutCsvField.Value;
            if isempty(outPath); obj.applog('warn', 'Pick an output csv'); return; end
            writetable(obj.State.superTable.Wide, outPath);
            tidyPath = strrep(outPath, '.csv', '_tidy.csv');
            writetable(obj.State.superTable.Tidy, tidyPath);
            obj.applog('info', 'Saved %s and %s', outPath, tidyPath);
        end
    end

    methods (Access = private)
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
            left = uigridlayout(parent, [13, 2]);
            left.Layout.Column = 1;
            left.RowHeight = {30, 30, 30, 30, 100, 30, 30, 30, 30, 30, 30, 30, '1x'};
            left.ColumnWidth = {110, '1x'};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            uilabel(left, 'Text', 'Batch dir:');
            obj.BatchDirField = uieditfield(left, 'text', 'Value', '');
            uibutton(left, 'Text', 'Browse batch dir', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Batch'));
            uilabel(left, 'Text', '');

            uilabel(left, 'Text', 'Metadata CSV:');
            obj.MetadataField = uieditfield(left, 'text', 'Value', '', ...
                'Tooltip', 'columns: session_name, mouse, session, group, line');
            uibutton(left, 'Text', 'Browse metadata', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('Metadata'));
            uilabel(left, 'Text', '');

            uilabel(left, 'Text', 'Metrics:');
            obj.MetricsListBox = uilistbox(left, ...
                'Items', {'ActPercent', 'ActDuration', 'ActNumber', 'ActMeanTime', ...
                          'ActMedianTime', 'Distance', 'ActMeanDistance', 'ActVelocity'}, ...
                'Multiselect', 'on', ...
                'Value', {'ActPercent', 'ActDuration', 'ActNumber', 'ActMeanTime'});

            uilabel(left, 'Text', 'NaN policy:');
            obj.NaNDropDown = uidropdown(left, 'Items', {'keep', 'zero'}, 'Value', 'keep');

            uilabel(left, 'Text', 'Sort by:');
            obj.SortDropDown = uidropdown(left, ...
                'Items', {'group,line,mouse', 'mouse', 'line,mouse', 'group,mouse'}, ...
                'Value', 'group,line,mouse');

            uilabel(left, 'Text', 'Output csv:');
            obj.OutCsvField = uieditfield(left, 'text', 'Value', '');
            uibutton(left, 'Text', 'Browse out csv', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('OutCsv'));
            uilabel(left, 'Text', '');

            br = uigridlayout(left, [1, 2]);
            br.RowHeight = {30};
            br.ColumnWidth = {'1x', '1x'};
            br.Padding = [0 0 0 0];
            br.ColumnSpacing = 4;
            uibutton(br, 'Text', 'Build table', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.buildTable());
            uibutton(br, 'Text', 'Save CSV', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.saveCsv());

            uilabel(left, 'Text', '');
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
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

        function pickPath(obj, kind)
            startDir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                startDir = obj.ParentApp.State.projectRoot;
            end
            switch kind
                case 'Batch'
                    d = uigetdir(startDir, 'Pick batch results dir');
                    if ~isequal(d, 0); obj.BatchDirField.Value = d; end
                case 'Metadata'
                    [f, p] = uigetfile({'*.csv'}, 'Metadata CSV', startDir);
                    if ~isequal(f, 0); obj.MetadataField.Value = fullfile(p, f); end
                case 'OutCsv'
                    [f, p] = uiputfile({'*.csv'}, 'Output CSV', fullfile(startDir, 'super_table.csv'));
                    if ~isequal(f, 0); obj.OutCsvField.Value = fullfile(p, f); end
            end
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

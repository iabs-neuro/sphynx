classdef BatchAnalysisTabController < handle
% BATCHANALYSISTABCONTROLLER  Run analyzeSession across N sessions and
% aggregate the results into tidy + wide tables.
%
% MVP scope:
%   * Add multiple (DLC, Preset) pairs to a list.
%   * Choose output dir (per-session subfolders auto-created).
%   * Toggle: save plots / save per-session mat / build aggregate tables.
%   * Run with progress bar.
%   * Tidy + wide tables shown in two uitable widgets, plus a Save CSV button.

    properties
        Tab
        Figure
        ParentApp

        % Sessions
        SessionsListBox
        OutDirField
        ActsLibraryField
        SavePlotsChk
        SaveMatChk
        AggregateChk

        % Results
        TidyTable
        WideTable

        % Log
        LogTextArea

        % State
        State
    end

    methods
        function obj = BatchAnalysisTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('sessions', struct('dlc', {}, 'preset', {}), ...
                               'tidy', table(), 'wide', table());
            obj.buildUI();
        end

        function delete(~)
        end

        function addSession(obj)
            startDir = obj.guessStartDir();
            [fDLC, pDLC] = uigetfile({'*.csv'}, 'Pick DLC csv', startDir);
            if isequal(fDLC, 0); return; end
            [fP, pP] = uigetfile({'*.mat'}, 'Pick preset', pDLC);
            if isequal(fP, 0); return; end
            s.dlc = fullfile(pDLC, fDLC);
            s.preset = fullfile(pP, fP);
            obj.State.sessions(end+1) = s;
            obj.refreshSessionsListBox();
            obj.applog('info', 'Added session: %s', fDLC);
        end

        function removeSelectedSession(obj)
            sel = obj.SessionsListBox.Value;
            if isempty(sel); return; end
            idx = find(strcmp(obj.SessionsListBox.Items, sel), 1);
            if isempty(idx); return; end
            obj.State.sessions(idx) = [];
            obj.refreshSessionsListBox();
        end

        function clearSessions(obj)
            obj.State.sessions = struct('dlc', {}, 'preset', {});
            obj.refreshSessionsListBox();
        end

        function runBatch(obj)
            if isempty(obj.State.sessions)
                obj.applog('warn', 'No sessions in the list');
                return;
            end
            outDir = obj.OutDirField.Value;
            if isempty(outDir)
                obj.applog('warn', 'Pick an output dir first');
                return;
            end
            if ~isfolder(outDir); mkdir(outDir); end

            n = numel(obj.State.sessions);
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Batch analyze', ...
                'Message', sprintf('0 / %d', n), 'Cancelable', 'on');
            cleaner = onCleanup(@() closeIfValid(dlg));

            tidyRows = {};
            for k = 1:n
                if dlg.CancelRequested; break; end
                dlg.Value = (k - 1) / n;
                dlg.Message = sprintf('%d / %d: %s', k, n, ...
                    char(strtrim(string(obj.basename(obj.State.sessions(k).dlc)))));
                cfg = sphynx.pipeline.defaultConfig();
                cfg.paths.dlc    = obj.State.sessions(k).dlc;
                cfg.paths.preset = obj.State.sessions(k).preset;
                cfg.paths.outDir = outDir;
                cfg.io.saveWorkspace = obj.SaveMatChk.Value;
                cfg.viz.headless = true;
                cfg.verbose = 'warn';
                if ~isempty(obj.ActsLibraryField) && ~isempty(obj.ActsLibraryField.Value)
                    cfg.acts.libraryPath = obj.ActsLibraryField.Value;
                end
                try
                    res = sphynx.pipeline.analyzeSession(cfg);
                    obj.applog('info', 'OK: %s (%d acts)', ...
                        obj.basename(cfg.paths.dlc), numel(res.Acts));
                    if obj.AggregateChk.Value
                        rows = obj.actsToTidyRows(res, cfg.paths.dlc);
                        tidyRows = [tidyRows; rows]; %#ok<AGROW>
                    end
                catch ME
                    obj.applog('error', 'FAIL %s: %s', ...
                        obj.basename(cfg.paths.dlc), ME.message);
                end
            end
            dlg.Value = 1;

            if ~isempty(tidyRows) && obj.AggregateChk.Value
                obj.State.tidy = cell2table(tidyRows, ...
                    'VariableNames', {'session', 'act', 'percent', ...
                                      'duration_s', 'count', 'mean_dur_s'});
                obj.State.wide = obj.tidyToWide(obj.State.tidy);
                obj.refreshTables();
            end
            obj.applog('info', 'Batch done.');
        end

        function saveTablesCsv(obj)
            outDir = obj.OutDirField.Value;
            if isempty(outDir) || isempty(obj.State.tidy); return; end
            tidyPath = fullfile(outDir, 'batch_tidy.csv');
            widePath = fullfile(outDir, 'batch_wide.csv');
            writetable(obj.State.tidy, tidyPath);
            writetable(obj.State.wide, widePath);
            obj.applog('info', 'Saved %s and %s', tidyPath, widePath);
        end
    end

    methods (Access = private)
        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {380, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];
            outer.ColumnSpacing = 6;

            obj.buildLeft(outer);
            obj.buildRight(outer);
        end

        function buildLeft(obj, parent)
            left = uigridlayout(parent, [11, 1]);
            left.Layout.Column = 1;
            left.RowHeight = {28, '1x', 28, 28, 28, 28, 28, 28, 28, 30, 100};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            % Toolbar add / remove / clear
            tb = uigridlayout(left, [1, 3]);
            tb.Layout.Row = 1;
            tb.RowHeight = {28};
            tb.ColumnWidth = {'1x', '1x', '1x'};
            tb.Padding = [0 0 0 0];
            tb.ColumnSpacing = 4;
            uibutton(tb, 'Text', '+ Session', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.addSession());
            uibutton(tb, 'Text', 'Remove', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.removeSelectedSession());
            uibutton(tb, 'Text', 'Clear', 'BackgroundColor', [0.92 0.55 0.55], ...
                'ButtonPushedFcn', @(~,~) obj.clearSessions());

            % Sessions list
            obj.SessionsListBox = uilistbox(left, 'Items', {});
            obj.SessionsListBox.Layout.Row = 2;

            % Out dir
            uilabel(left, 'Text', 'Output dir:');
            obj.OutDirField = uieditfield(left, 'text', 'Value', '');
            uibutton(left, 'Text', 'Browse out dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickOutDir());

            % Acts library (optional)
            uilabel(left, 'Text', 'Acts library:');
            obj.ActsLibraryField = uieditfield(left, 'text', 'Value', '', ...
                'Tooltip', 'optional .mat from Define Acts; empty = built-in defaults');
            uibutton(left, 'Text', 'Browse acts library', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickActsLibrary());

            % Toggles
            obj.SavePlotsChk = uicheckbox(left, 'Text', 'Save per-zone plots', 'Value', false);
            obj.SaveMatChk   = uicheckbox(left, 'Text', 'Save per-session .mat', 'Value', true);
            obj.AggregateChk = uicheckbox(left, 'Text', 'Build aggregate tables', 'Value', true);

            % Run button
            uibutton(left, 'Text', 'Run batch', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.runBatch());

            % Log
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
        end

        function buildRight(obj, parent)
            right = uigridlayout(parent, [3, 1]);
            right.Layout.Column = 2;
            right.RowHeight = {'1x', '1x', 28};
            right.RowSpacing = 4;
            right.Padding = [0 0 0 0];

            obj.TidyTable = uitable(right, 'ColumnName', ...
                {'session', 'act', 'percent', 'duration_s', 'count', 'mean_dur_s'});
            obj.WideTable = uitable(right);

            uibutton(right, 'Text', 'Save tables to CSV', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.saveTablesCsv());
        end

        function pickOutDir(obj)
            d = uigetdir(obj.guessStartDir(), 'Output dir');
            if isequal(d, 0); return; end
            obj.OutDirField.Value = d;
        end

        function pickActsLibrary(obj)
            [f, p] = uigetfile({'*.mat', 'Acts library .mat'}, ...
                'Pick acts library', obj.guessStartDir());
            if isequal(f, 0); return; end
            obj.ActsLibraryField.Value = fullfile(p, f);
        end

        function dir = guessStartDir(obj)
            dir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                dir = obj.ParentApp.State.projectRoot;
            end
        end

        function refreshSessionsListBox(obj)
            n = numel(obj.State.sessions);
            items = cell(1, n);
            for k = 1:n
                items{k} = sprintf('%d: %s', k, obj.basename(obj.State.sessions(k).dlc));
            end
            obj.SessionsListBox.Items = items;
        end

        function refreshTables(obj)
            if ~isempty(obj.State.tidy)
                obj.TidyTable.ColumnName = obj.State.tidy.Properties.VariableNames;
                obj.TidyTable.Data = table2cell(obj.State.tidy);
            end
            if ~isempty(obj.State.wide)
                obj.WideTable.ColumnName = obj.State.wide.Properties.VariableNames;
                obj.WideTable.Data = table2cell(obj.State.wide);
            end
        end

        function rows = actsToTidyRows(~, res, dlcPath)
            [~, base, ~] = fileparts(dlcPath);
            n = numel(res.Acts);
            rows = cell(n, 6);
            for k = 1:n
                a = res.Acts(k);
                rows{k, 1} = base;
                rows{k, 2} = a.ActName;
                rows{k, 3} = getfield2(a, 'ActPercent', NaN);
                rows{k, 4} = getfield2(a, 'ActDuration', NaN);
                rows{k, 5} = getfield2(a, 'ActNumber', 0);
                rows{k, 6} = getfield2(a, 'ActMeanTime', NaN);
            end
        end

        function W = tidyToWide(~, T)
            % Pivot tidy (session, act, percent, ...) -> wide (session, ...)
            sessions = unique(T.session, 'stable');
            acts = unique(T.act, 'stable');
            W = table();
            W.session = sessions;
            for k = 1:numel(acts)
                col = nan(numel(sessions), 1);
                for s = 1:numel(sessions)
                    mask = strcmp(T.session, sessions{s}) & strcmp(T.act, acts{k});
                    if any(mask); col(s) = T.percent(find(mask, 1)); end
                end
                W.(['percent_' matlab.lang.makeValidName(acts{k})]) = col;
            end
        end

        function s = basename(~, p)
            [~, b, e] = fileparts(p);
            s = [b e];
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[Batch] ' fmt], varargin{:});
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

function v = getfield2(s, name, fallback)
    if isfield(s, name); v = s.(name); else; v = fallback; end
end

function closeIfValid(h)
    if ~isempty(h) && isvalid(h)
        try; close(h); catch; end
    end
end

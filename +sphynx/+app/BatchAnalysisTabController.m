classdef BatchAnalysisTabController < handle
% BATCHANALYSISTABCONTROLLER  Run analyzeSession across N sessions
% with shared options (rendering, plots) and aggregate results.
%
% Layout (matches Define Acts / Analyze):
%   * Loader row 1 — folders: Root | DLC dir | Video dir | Preset dir
%                              | Out dir.
%   * Loader row 2 — setting files: Preprocess settings .mat |
%                                    Acts library .mat |
%                                    Analysis settings .mat.
%   * Sessions auto-paired by ID prefix: foreach DLC csv, find a
%     same-prefix video and preset; show how many full triples found.
%   * Options panel mirrors Analyze (Main video / Acts videos / Plot
%     bodyparts / Heatmap bin). Loaded via "Load settings", overridable
%     in the UI.
%   * Run -> per-session subfolder <outDir>/<sessionId>/, save acts
%     library output, render main / acts / plots per options, append
%     to tidy + wide aggregate tables.

    properties
        Tab
        Figure
        ParentApp

        % Loader row 1: folders
        RootPathField
        DLCDirField
        VideoDirField
        PresetDirField
        OutDirField
        RootButton
        DLCDirButton
        VideoDirButton
        PresetDirButton
        OutDirButton

        % Loader row 2: setting files
        PreprocessSettingsField
        ActsLibraryField
        AnalysisSettingsField
        PreprocessSettingsButton
        ActsLibraryButton
        AnalysisSettingsButton

        % Sessions
        SessionsLabel
        SessionsListBox
        RefreshSessionsButton

        % Options — main video
        MainVideoEnableCheckbox
        MainVideoStartField
        MainVideoDurationField
        MainVideoTrajectoryCheckbox
        MainVideoVelocityCheckbox
        MainVideoActsListCheckbox
        MainVideoZonesCheckbox

        % Options — per-act videos
        ActsVideoListBox
        ActsVideoDurationField

        % Options — session/bodyparts plots + heatmap bin
        PlotSessionCheckbox
        PlotBodypartsCheckbox
        HeatmapBinField

        % Save/Load + Run + Save CSV
        SaveSettingsButton
        LoadSettingsButton
        RunBatchButton
        SaveCsvButton
        SaveMatChk
        AggregateChk

        % Results
        TidyTable
        WideTable
        BarnesTable

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
            obj.State = struct( ...
                'sessions', struct('id', {}, 'dlc', {}, ...
                                   'video', {}, 'preset', {}, ...
                                   'status', {}), ...
                'tidy', table(), 'wide', table(), ...
                'barnes', table());
            obj.buildUI();
            obj.inheritRootFromParentApp();
        end

        function delete(~)
        end

        % ---------- Auto-pairing ----------------------------------

        function refreshSessions(obj)
            dlcDir    = obj.DLCDirField.Value;
            videoDir  = obj.VideoDirField.Value;
            presetDir = obj.PresetDirField.Value;
            obj.State.sessions = struct( ...
                'id', {}, 'dlc', {}, 'video', {}, 'preset', {}, 'status', {});
            if isempty(dlcDir) || ~isfolder(dlcDir)
                obj.applog('warn', 'Pick a DLC folder first');
                obj.refreshSessionsListBox();
                return;
            end
            csvs = dir(fullfile(dlcDir, '*.csv'));
            for k = 1:numel(csvs)
                name = csvs(k).name;
                id = sessionIdFromDlcName(name);
                if isempty(id); continue; end
                s = struct();
                s.id = id;
                s.dlc = fullfile(dlcDir, name);
                s.video  = findFirstMatch(videoDir,  id, ...
                    {'.mp4', '.avi', '.mov', '.mkv'});
                s.preset = findFirstMatch(presetDir, id, ...
                    {'_Preset.mat', '.mat'});
                s.status = sessionStatus(s);
                obj.State.sessions(end+1) = s; %#ok<AGROW>
            end
            obj.refreshSessionsListBox();
            n = numel(obj.State.sessions);
            full = sum(strcmp({obj.State.sessions.status}, 'full'));
            obj.SessionsLabel.Text = sprintf( ...
                'Sessions: %d found, %d full triples, %d incomplete', ...
                n, full, n - full);
            obj.applog('info', 'Auto-paired %d sessions (%d full)', n, full);
        end

        function refreshSessionsListBox(obj)
            n = numel(obj.State.sessions);
            items = cell(1, n);
            for k = 1:n
                s = obj.State.sessions(k);
                items{k} = sprintf('%s [%s]', s.id, s.status);
            end
            obj.SessionsListBox.Items = items;
            obj.SessionsListBox.Value = items;  % select all by default
        end

        % ---------- Run -------------------------------------------

        function runBatch(obj)
            if isempty(obj.State.sessions)
                obj.applog('warn', 'No sessions — refresh first'); return;
            end
            outRoot = obj.OutDirField.Value;
            if isempty(outRoot)
                obj.applog('warn', 'Pick output dir first'); return;
            end
            if ~isfolder(outRoot); mkdir(outRoot); end

            sel = obj.SessionsListBox.Value;
            if ischar(sel); sel = {sel}; end
            selIds = cellfun(@(s) regexprep(s, ' \[.*$', ''), sel, ...
                'UniformOutput', false);
            keep = ismember({obj.State.sessions.id}, selIds) & ...
                strcmp({obj.State.sessions.status}, 'full');
            sessions = obj.State.sessions(keep);
            n = numel(sessions);
            if n == 0
                obj.applog('warn', ['No selectable full-triple sessions ' ...
                    '(need DLC + video + preset)']); return;
            end

            cfg0 = sphynx.pipeline.defaultConfig();
            cfg0.viz.headless = true;
            cfg0.verbose = 'warn';
            if ~isempty(obj.ActsLibraryField.Value) ...
                    && isfile(obj.ActsLibraryField.Value)
                cfg0.acts.libraryPath = obj.ActsLibraryField.Value;
            end

            saveMat       = obj.SaveMatChk.Value;
            aggregate     = obj.AggregateChk.Value;
            saveMain      = obj.MainVideoEnableCheckbox.Value;
            actsSel       = obj.ActsVideoListBox.Value;
            if ischar(actsSel); actsSel = {actsSel}; end
            % Filter out the placeholder when no acts library was loaded.
            actsSel = actsSel(~startsWith(actsSel, '('));
            saveActs      = ~isempty(actsSel);
            savePlotsBP   = obj.PlotBodypartsCheckbox.Value;
            savePlotsSes  = obj.PlotSessionCheckbox.Value;

            dlg = uiprogressdlg(obj.Figure, 'Title', 'Batch analyze', ...
                'Message', sprintf('0 / %d', n), 'Cancelable', 'on');
            cleaner = onCleanup(@() closeIfValid(dlg)); %#ok<NASGU>

            tidyRows = {};
            barnesRows = {};   % R26: one row per session that has BarnesMetrics
            for k = 1:n
                if dlg.CancelRequested; break; end
                s = sessions(k);
                sessDir = fullfile(outRoot, s.id);
                if ~isfolder(sessDir); mkdir(sessDir); end
                dlg.Value = (k - 1) / n;
                dlg.Message = sprintf('%d / %d: %s', k, n, s.id);

                cfg = cfg0;
                cfg.paths.dlc    = s.dlc;
                cfg.paths.preset = s.preset;
                cfg.paths.outDir = sessDir;
                cfg.io.saveWorkspace = saveMat;

                try
                    res = sphynx.pipeline.analyzeSession(cfg);
                    obj.applog('info', '[%d/%d] %s OK (%d acts)', ...
                        k, n, s.id, numel(res.Acts));
                catch ME
                    obj.applog('error', '[%d/%d] FAIL %s: %s', ...
                        k, n, s.id, ME.message);
                    continue;
                end

                if aggregate
                    tidyRows = [tidyRows; obj.actsToTidyRows(res, s)]; %#ok<AGROW>
                    if isfield(res, 'BarnesMetrics') && ~isempty(res.BarnesMetrics)
                        barnesRows = [barnesRows; obj.barnesMetricsToRow(res, s)]; %#ok<AGROW>
                    end
                end

                % Renders + plots
                if saveMain
                    obj.renderMainForSession(res, s, sessDir);
                end
                if saveActs
                    obj.renderActsForSession(res, s, sessDir, actsSel);
                end
                if savePlotsSes
                    try
                        sphynx.pipeline.saveSessionPlots(res, sessDir, ...
                            'HeatmapBinCm', obj.HeatmapBinField.Value);
                        obj.applog('info', '  session plots saved');
                    catch ME
                        obj.applog('warn', '  session plots failed: %s', ME.message);
                    end
                end
                if savePlotsBP
                    obj.savePlotsForSession(res, sessDir);
                end
            end
            dlg.Value = 1;

            if ~isempty(tidyRows) && aggregate
                obj.State.tidy = cell2table(tidyRows, ...
                    'VariableNames', {'session', 'act', ...
                                      'percent', 'duration_s', ...
                                      'count', 'mean_dur_s', ...
                                      'mean_v_cm_s', 'distance_cm', ...
                                      'first_start_s', 'first_end_s'});
                obj.State.wide = obj.tidyToWide(obj.State.tidy);
                if ~isempty(barnesRows)
                    obj.State.barnes = cell2table(barnesRows, ...
                        'VariableNames', {'session', ...
                            'TargetHoleVisitOrder', 'PrimaryErrors', ...
                            'TotalNoseHoleVisits', 'TotalBodyHoleVisits', ...
                            'NumCheckedHoles', 'FirstCheckedHoleNumber', ...
                            'FirstCheckedHoleErrorDeg', 'MeanCheckedHoleErrorDeg'});
                else
                    obj.State.barnes = table();
                end
                obj.refreshTables();
            end
            obj.applog('info', 'Batch done.');
        end

        function saveTablesCsv(obj)
            outDir = obj.OutDirField.Value;
            if isempty(outDir) || isempty(obj.State.tidy)
                obj.applog('warn', 'Nothing to save (need tidy + outDir)');
                return;
            end
            tidyPath = fullfile(outDir, 'batch_tidy.csv');
            widePath = fullfile(outDir, 'batch_wide.csv');
            writetable(obj.State.tidy, tidyPath);
            writetable(obj.State.wide, widePath);
            % R26: write batch_barnes.csv only when at least one
            % session in this batch carried BarnesMetrics. Mirrors how
            % the BarnesTable in the right pane stays empty otherwise.
            if isfield(obj.State, 'barnes') && ~isempty(obj.State.barnes) ...
                    && height(obj.State.barnes) > 0
                barnesPath = fullfile(outDir, 'batch_barnes.csv');
                writetable(obj.State.barnes, barnesPath);
                obj.applog('info', 'Saved %s, %s, %s', tidyPath, widePath, barnesPath);
                return;
            end
            obj.applog('info', 'Saved %s and %s', tidyPath, widePath);
        end

        % ---------- Settings save/load (mirrors Analyze) ----------

        function s = collectSettings(obj)
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
            s.plotSession   = obj.PlotSessionCheckbox.Value;
            s.heatmapBinCm  = obj.HeatmapBinField.Value;
        end

        function applySettings(obj, s)
            if isfield(s, 'mainVideo')
                m = s.mainVideo;
                if isfield(m,'enabled');    obj.MainVideoEnableCheckbox.Value     = m.enabled; end
                if isfield(m,'startSec');   obj.MainVideoStartField.Value         = m.startSec; end
                if isfield(m,'durationSec');obj.MainVideoDurationField.Value      = m.durationSec; end
                if isfield(m,'trajectory'); obj.MainVideoTrajectoryCheckbox.Value = m.trajectory; end
                if isfield(m,'velocity');   obj.MainVideoVelocityCheckbox.Value   = m.velocity; end
                if isfield(m,'actsList');   obj.MainVideoActsListCheckbox.Value   = m.actsList; end
                if isfield(m,'zones');      obj.MainVideoZonesCheckbox.Value      = m.zones; end
            end
            if isfield(s, 'actsVideo')
                a = s.actsVideo;
                if isfield(a,'durationSec'); obj.ActsVideoDurationField.Value = a.durationSec; end
                if isfield(a,'selected') && ~isempty(a.selected)
                    items = obj.ActsVideoListBox.Items;
                    if isempty(items) || isequal(items, {'(refresh sessions first)'})
                        items = a.selected; obj.ActsVideoListBox.Items = items;
                    end
                    keep = a.selected(ismember(a.selected, items));
                    if ~isempty(keep); obj.ActsVideoListBox.Value = keep; end
                end
            end
            if isfield(s,'plotBodyparts'); obj.PlotBodypartsCheckbox.Value = s.plotBodyparts; end
            if isfield(s,'plotSession');   obj.PlotSessionCheckbox.Value   = s.plotSession;   end
            if isfield(s,'heatmapBinCm');  obj.HeatmapBinField.Value      = s.heatmapBinCm;  end
        end

        function saveSettings(obj)
            startDir = obj.resourceStartDir();
            [f, p] = uiputfile({'*.mat'}, ...
                'Save analysis settings', fullfile(startDir, 'analysis_settings.mat'));
            obj.restoreFocus();
            if isequal(f, 0); return; end
            settings = obj.collectSettings(); %#ok<NASGU>
            try
                save(fullfile(p, f), '-struct', 'settings');
                obj.applog('info', 'Settings saved: %s', fullfile(p, f));
            catch ME
                obj.applog('error', 'Save failed: %s', ME.message);
            end
        end

        function loadSettings(obj, path)
            if nargin < 2 || isempty(path)
                startDir = obj.resourceStartDir();
                [f, p] = uigetfile({'*.mat'}, 'Load analysis settings', startDir);
                obj.restoreFocus();
                if isequal(f, 0); return; end
                path = fullfile(p, f);
            end
            try
                s = load(path);
                obj.applySettings(s);
                obj.AnalysisSettingsField.Value = path;
                obj.applog('info', 'Settings loaded: %s', path);
            catch ME
                obj.applog('error', 'Load failed: %s', ME.message);
            end
        end
    end

    methods (Access = private)

        % ---------- UI build --------------------------------------

        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {420, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];
            outer.ColumnSpacing = 6;
            obj.buildLeft(outer);
            obj.buildRight(outer);
        end

        function buildLeft(obj, parent)
            % Sessions list is the only flex row; everything else has
            % a fixed height so the Acts-videos listbox can't collapse.
            left = uigridlayout(parent, [11, 1]);
            left.Layout.Column = 1;
            % Rows: loader1 / loader2 / sessions header / sessions list /
            %       main video / acts videos / plot tail / settings /
            %       toggles / run / log
            left.RowHeight = {64, 64, 24, '1x', 90, 170, 28, 30, 24, 36, 80};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            obj.buildLoaderFolders(left);
            obj.buildLoaderSettings(left);
            obj.buildSessionsHeader(left);
            obj.buildSessionsListBox(left);
            obj.buildMainVideoPanel(left);
            obj.buildActsVideosPanel(left);
            obj.buildPlotTailRow(left);
            obj.buildSettingsRow(left);
            obj.buildToggleRow(left);
            obj.buildRunRow(left);
            obj.LogTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
            obj.LogTextArea.Layout.Row = 11;
        end

        function buildLoaderFolders(obj, parent)
            row = uigridlayout(parent, [2, 5]);
            row.Layout.Row = 1;
            row.RowHeight = {28, 26};
            row.ColumnWidth = repmat({'1x'}, 1, 5);
            row.RowSpacing = 4; row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.RootButton = uibutton(row, 'Text', 'Root', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Project root', ...
                'ButtonPushedFcn', @(~,~) obj.pickFolder('Root'));
            obj.DLCDirButton = uibutton(row, 'Text', 'DLC dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Folder with DLC csv files', ...
                'ButtonPushedFcn', @(~,~) obj.pickFolder('DLCDir'));
            obj.VideoDirButton = uibutton(row, 'Text', 'Video dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickFolder('VideoDir'));
            obj.PresetDirButton = uibutton(row, 'Text', 'Preset dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickFolder('PresetDir'));
            obj.OutDirButton = uibutton(row, 'Text', 'Out dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickFolder('OutDir'));

            obj.RootPathField    = uieditfield(row, 'text', 'Value', '');
            obj.DLCDirField      = uieditfield(row, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.refreshSessions());
            obj.VideoDirField    = uieditfield(row, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.refreshSessions());
            obj.PresetDirField   = uieditfield(row, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.refreshSessions());
            obj.OutDirField      = uieditfield(row, 'text', 'Value', '');
        end

        function buildLoaderSettings(obj, parent)
            row = uigridlayout(parent, [2, 3]);
            row.Layout.Row = 2;
            row.RowHeight = {28, 26};
            row.ColumnWidth = repmat({'1x'}, 1, 3);
            row.RowSpacing = 4; row.ColumnSpacing = 4;
            row.Padding = [0 0 0 0];
            obj.PreprocessSettingsButton = uibutton(row, ...
                'Text', 'Preproc settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', '<exp>_PreprocessSettings.mat from Preprocess Track', ...
                'ButtonPushedFcn', @(~,~) obj.pickSettingFile('Preprocess'));
            obj.ActsLibraryButton = uibutton(row, 'Text', 'Acts library', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Acts library .mat from Define Acts (built-ins if empty)', ...
                'ButtonPushedFcn', @(~,~) obj.pickSettingFile('ActsLibrary'));
            obj.AnalysisSettingsButton = uibutton(row, 'Text', 'Analysis settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'analysis_settings.mat from Analyze Session', ...
                'ButtonPushedFcn', @(~,~) obj.pickSettingFile('Analysis'));

            obj.PreprocessSettingsField = uieditfield(row, 'text', 'Value', '');
            obj.ActsLibraryField        = uieditfield(row, 'text', 'Value', '');
            obj.AnalysisSettingsField   = uieditfield(row, 'text', 'Value', '', ...
                'ValueChangedFcn', @(s,~) obj.onAnalysisSettingsEdited(s.Value));
        end

        function buildSessionsHeader(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 3;
            row.RowHeight = {26};
            row.ColumnWidth = {'1x', 'fit'};
            row.Padding = [0 0 0 0]; row.ColumnSpacing = 4;
            obj.SessionsLabel = uilabel(row, ...
                'Text', 'Sessions: pick DLC dir to start', ...
                'FontWeight', 'bold');
            obj.RefreshSessionsButton = uibutton(row, ...
                'Text', 'Refresh sessions', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.refreshSessions());
        end

        function buildSessionsListBox(obj, parent)
            obj.SessionsListBox = uilistbox(parent, 'Items', {}, ...
                'Multiselect', 'on', ...
                'Tooltip', 'Highlight rows to include in batch (Ctrl/Shift-click)');
            obj.SessionsListBox.Layout.Row = 4;
        end

        function buildMainVideoPanel(obj, parent)
            % Compact 2-row layout so the Acts videos listbox below
            % gets real room.
            mvPanel = uipanel(parent, 'Title', 'Main video');
            mvPanel.Layout.Row = 5;
            g = uigridlayout(mvPanel, [2, 5]);
            g.RowHeight = {26, 26};
            g.ColumnWidth = {'fit', 50, 'fit', 50, '1x'};
            g.RowSpacing = 3; g.ColumnSpacing = 4;
            g.Padding = [4 4 4 4];
            obj.MainVideoEnableCheckbox = uicheckbox(g, ...
                'Text', 'Render', 'Value', false);
            uilabel(g, 'Text', 'Start, s:');
            obj.MainVideoStartField = uieditfield(g, 'numeric', ...
                'Value', 0, 'Limits', [0 100000]);
            uilabel(g, 'Text', 'Duration, s:');
            obj.MainVideoDurationField = uieditfield(g, 'numeric', ...
                'Value', 30, 'Limits', [0.1 36000]);

            obj.MainVideoTrajectoryCheckbox = uicheckbox(g, ...
                'Text', 'Trajectory', 'Value', true);
            obj.MainVideoVelocityCheckbox = uicheckbox(g, ...
                'Text', 'Velocity', 'Value', true);
            obj.MainVideoActsListCheckbox = uicheckbox(g, ...
                'Text', 'Acts list', 'Value', true);
            obj.MainVideoZonesCheckbox = uicheckbox(g, ...
                'Text', 'Zones', 'Value', true);
            uilabel(g, 'Text', '');  % spacer
        end

        function buildActsVideosPanel(obj, parent)
            avPanel = uipanel(parent, 'Title', 'Acts videos (per-act)');
            avPanel.Layout.Row = 6;
            g = uigridlayout(avPanel, [2, 1]);
            g.RowHeight = {'1x', 28};
            g.RowSpacing = 4;
            g.Padding = [4 4 4 4];
            obj.ActsVideoListBox = uilistbox(g, ...
                'Items', {'(load Acts library to populate)'}, ...
                'Multiselect', 'on', ...
                'Tooltip', ['Acts to render per session. Click "Acts ' ...
                            'library" in loader row 2 first; this list ' ...
                            'will fill with act names. Then Ctrl/Shift-' ...
                            'click to pick which acts to render.']);
            durRow = uigridlayout(g, [1, 2]);
            durRow.Layout.Row = 2;
            durRow.RowHeight = {28};
            durRow.ColumnWidth = {110, 70};
            durRow.Padding = [0 0 0 0];
            uilabel(durRow, 'Text', 'Duration, s:');
            obj.ActsVideoDurationField = uieditfield(durRow, 'numeric', ...
                'Value', 5, 'Limits', [0.1 600]);
        end

        function buildPlotTailRow(obj, parent)
            tail = uigridlayout(parent, [1, 4]);
            tail.Layout.Row = 7;
            tail.RowHeight = {26};
            tail.ColumnWidth = {'fit', '1x', 110, 70};
            tail.ColumnSpacing = 4;
            tail.Padding = [0 0 0 0];
            obj.PlotSessionCheckbox = uicheckbox(tail, ...
                'Text', 'Session plots', 'Value', true, ...
                'Tooltip', 'Save trajectory/heatmap/speed PNG+FIG per session');
            obj.PlotBodypartsCheckbox = uicheckbox(tail, ...
                'Text', 'Bodyparts plots', 'Value', false, ...
                'Tooltip', 'Per body-part 4-tile PNG+FIG (heavier)');
            uilabel(tail, 'Text', 'Heatmap bin, cm:');
            obj.HeatmapBinField = uieditfield(tail, 'numeric', ...
                'Value', 4, 'Limits', [0.1 100]);
        end

        function buildSettingsRow(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 8;
            row.RowHeight = {28};
            row.ColumnWidth = {'1x', '1x'};
            row.Padding = [0 0 0 0]; row.ColumnSpacing = 4;
            obj.SaveSettingsButton = uibutton(row, 'Text', 'Save settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.saveSettings());
            obj.LoadSettingsButton = uibutton(row, 'Text', 'Load settings', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadSettings());
        end

        function buildToggleRow(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 9;
            row.RowHeight = {26};
            row.ColumnWidth = {'1x', '1x'};
            row.Padding = [0 0 0 0]; row.ColumnSpacing = 4;
            obj.SaveMatChk   = uicheckbox(row, ...
                'Text', 'Save per-session .mat', 'Value', true);
            obj.AggregateChk = uicheckbox(row, ...
                'Text', 'Build aggregate tables', 'Value', true);
        end

        function buildRunRow(obj, parent)
            row = uigridlayout(parent, [1, 2]);
            row.Layout.Row = 10;
            row.RowHeight = {32};
            row.ColumnWidth = {'1x', '1x'};
            row.Padding = [0 0 0 0]; row.ColumnSpacing = 4;
            obj.RunBatchButton = uibutton(row, 'Text', 'Run batch', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.runBatch());
            obj.SaveCsvButton = uibutton(row, 'Text', 'Save tables CSV', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.saveTablesCsv());
        end

        function buildRight(obj, parent)
            % R26: three stacked tables -- tidy / wide / barnes. The
            % Barnes table appears at the bottom; rows are sessions and
            % columns are the 8 fields from barnesSessionMetrics. Stays
            % empty (and is not saved) when no session has BarnesMetrics
            % attached.
            right = uigridlayout(parent, [3, 1]);
            right.Layout.Column = 2;
            right.RowHeight = {'1x', '1x', '1x'};
            right.RowSpacing = 4;
            right.Padding = [0 0 0 0];
            obj.TidyTable = uitable(right, 'ColumnName', ...
                {'session', 'act', 'percent', 'duration_s', 'count', ...
                 'mean_dur_s', 'mean_v_cm_s', 'distance_cm', ...
                 'first_start_s', 'first_end_s'});
            obj.WideTable = uitable(right);
            obj.BarnesTable = uitable(right, 'ColumnName', ...
                {'session', 'TargetHoleVisitOrder', 'PrimaryErrors', ...
                 'TotalNoseHoleVisits', 'TotalBodyHoleVisits', ...
                 'NumCheckedHoles', 'FirstCheckedHoleNumber', ...
                 'FirstCheckedHoleErrorDeg', 'MeanCheckedHoleErrorDeg'});
        end

        % ---------- Folder / file pickers --------------------------

        function pickFolder(obj, kind)
            startDir = obj.resourceStartDir();
            d = uigetdir(startDir, ['Pick ' kind]);
            obj.restoreFocus();
            if isequal(d, 0); return; end
            switch kind
                case 'Root';      obj.RootPathField.Value = d;
                case 'DLCDir';    obj.DLCDirField.Value   = d;
                                  obj.refreshSessions();
                case 'VideoDir';  obj.VideoDirField.Value = d;
                                  obj.refreshSessions();
                case 'PresetDir'; obj.PresetDirField.Value = d;
                                  obj.refreshSessions();
                case 'OutDir';    obj.OutDirField.Value   = d;
            end
        end

        function restoreFocus(obj)
            % R27: pull the main Sphynx window back to front after any
            % modal picker so keyboard input + Tab navigation keep
            % working. drawnow forces Windows to actually swap focus.
            try
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    figure(obj.Figure);
                    drawnow;
                end
            catch
            end
        end

        function pickSettingFile(obj, kind)
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mat'}, ['Pick ' kind ' .mat'], startDir);
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            switch kind
                case 'Preprocess'
                    obj.PreprocessSettingsField.Value = path;
                case 'ActsLibrary'
                    obj.ActsLibraryField.Value = path;
                    obj.populateActsListFromLibrary(path);
                case 'Analysis'
                    obj.AnalysisSettingsField.Value = path;
                    obj.loadSettings(path);
            end
        end

        function onAnalysisSettingsEdited(obj, val)
            if ~isempty(val) && isfile(val); obj.loadSettings(val); end
        end

        function populateActsListFromLibrary(obj, path)
            % Read the acts library and seed the per-act listbox so
            % the user can tick which acts to render in batch.
            try
                acts = sphynx.io.loadActsSet(path);
            catch ME
                obj.applog('warn', 'Cannot read acts library: %s', ME.message);
                return;
            end
            if isempty(acts); return; end
            names = {acts.name};
            obj.ActsVideoListBox.Items = names;
            obj.ActsVideoListBox.Value = {};
            obj.applog('info', 'Acts library loaded: %d acts', numel(names));
        end

        % ---------- Render helpers --------------------------------

        function feat = collectMainVideoFeatures(obj)
            feat = struct( ...
                'trajectory', obj.MainVideoTrajectoryCheckbox.Value, ...
                'velocity',   obj.MainVideoVelocityCheckbox.Value, ...
                'actsList',   obj.MainVideoActsListCheckbox.Value, ...
                'zones',      obj.MainVideoZonesCheckbox.Value);
        end

        function renderMainForSession(obj, res, s, sessDir)
            if isempty(s.video) || ~isfile(s.video); return; end
            fps = res.Options.FrameRate;
            startSec = obj.MainVideoStartField.Value;
            durSec   = obj.MainVideoDurationField.Value;
            startF = max(1, round(startSec * fps) + 1);
            endF   = startF + max(1, round(durSec * fps)) - 1;
            try
                outPath = sphynx.pipeline.renderActsVideo(res, ...
                    s.video, sessDir, ...
                    'Range', [startF endF], ...
                    'Features', obj.collectMainVideoFeatures(), ...
                    'OutputName', [s.id '_main.mp4']);
                obj.applog('info', '  main: %s', outPath);
            catch ME
                obj.applog('warn', '  main render failed: %s', ME.message);
            end
        end

        function renderActsForSession(obj, res, s, sessDir, actsSel)
            if isempty(s.video) || ~isfile(s.video); return; end
            actsDir = fullfile(sessDir, 'Acts_video');
            if ~isfolder(actsDir); mkdir(actsDir); end
            presetData = [];
            try; presetData = sphynx.io.readPreset(s.preset); catch; end
            videoOffset = 0;
            try; videoOffset = res.config.range.startFrame - 1; catch; end
            durSec = obj.ActsVideoDurationField.Value;
            for k = 1:numel(actsSel)
                try
                    sphynx.pipeline.renderActStitched(res, s.video, actsDir, ...
                        actsSel{k}, ...
                        'DurationSec', durSec, ...
                        'PresetData', presetData, ...
                        'VideoOffset', videoOffset);
                catch ME
                    obj.applog('warn', '  acts "%s" failed: %s', ...
                        actsSel{k}, ME.message);
                end
            end
            obj.applog('info', '  acts videos in %s', actsDir);
        end

        function savePlotsForSession(obj, res, sessDir)
            plotsDir = fullfile(sessDir, 'bodyparts_trajectory');
            if ~isfolder(plotsDir); mkdir(plotsDir); end
            bps = res.BodyPartsTraces;
            pxlPerCm = 1;
            if isfield(res.Options, 'pxl2sm'); pxlPerCm = res.Options.pxl2sm; end
            frame = [];
            for fld = {'GoodVideoFrame', 'GoodVideoFrameGray'}
                if isfield(res.Options, fld{1}) && ~isempty(res.Options.(fld{1}))
                    frame = res.Options.(fld{1}); break;
                end
            end
            fps = 30;
            if isfield(res.Options, 'FrameRate'); fps = res.Options.FrameRate; end
            saved = 0;
            for i = 1:numel(bps)
                bp = bps(i);
                if ~isfield(bp, 'TraceSmoothed') || isempty(bp.TraceSmoothed); continue; end
                X = bp.TraceSmoothed.X(:); Y = bp.TraceSmoothed.Y(:);
                if isempty(X); continue; end
                t = (0:numel(X)-1)' / fps;
                lk = [];
                if isfield(bp,'TraceLikelihood') && ~isempty(bp.TraceLikelihood)
                    lk = bp.TraceLikelihood(:);
                end
                fig = figure('Visible','off','Position',[100 100 1000 1000]);
                tl = tiledlayout(fig, 4, 1, 'Padding', 'compact', ...
                    'TileSpacing', 'compact');
                axT = nexttile(tl, 1);
                if ~isempty(frame)
                    imshow(frame, 'Parent', axT, ...
                        'XData', [0 size(frame,2)/pxlPerCm], ...
                        'YData', [0 size(frame,1)/pxlPerCm]);
                    hold(axT, 'on');
                end
                plot(axT, X/pxlPerCm, Y/pxlPerCm, '-', ...
                    'Color', [0.10 0.50 0.90], 'LineWidth', 1.2);
                axT.DataAspectRatio = [1 1 1]; axT.YDir = 'reverse';
                xlabel(axT, 'X, cm'); ylabel(axT, 'Y, cm');
                title(axT, sprintf('Trajectory — %s', bp.BodyPartName), ...
                    'Interpreter', 'none');
                axX = nexttile(tl, 2);
                plot(axX, t, X/pxlPerCm, '-', 'Color', [0.85 0.40 0.20]);
                ylabel(axX, 'X, cm');
                axY = nexttile(tl, 3);
                plot(axY, t, Y/pxlPerCm, '-', 'Color', [0.20 0.65 0.30]);
                ylabel(axY, 'Y, cm');
                axL = nexttile(tl, 4);
                if ~isempty(lk)
                    plot(axL, t(1:numel(lk)), lk, '-', 'Color', [0.40 0.40 0.40]);
                    ylim(axL, [0 1]);
                end
                ylabel(axL, 'likelihood'); xlabel(axL, 'time, s');
                linkaxes([axX, axY, axL], 'x');
                base = fullfile(plotsDir, sprintf('trajectory_%s', bp.BodyPartName));
                try
                    saveas(fig, [base '.png']); saveas(fig, [base '.fig']);
                    saved = saved + 1;
                catch
                end
                close(fig);
            end
            obj.applog('info', '  bodyparts plots: %d -> %s', saved, plotsDir);
        end

        % ---------- Aggregate -------------------------------------

        function rows = actsToTidyRows(~, res, s)
            n = numel(res.Acts);
            rows = cell(n, 10);
            for k = 1:n
                a = res.Acts(k);
                rows{k, 1} = s.id;
                rows{k, 2} = a.ActName;
                rows{k, 3} = getfield2(a, 'ActPercent', NaN);
                rows{k, 4} = getfield2(a, 'ActDuration', NaN);
                rows{k, 5} = getfield2(a, 'ActNumber', 0);
                rows{k, 6} = getfield2(a, 'ActMeanTime', NaN);
                rows{k, 7} = getfield2(a, 'ActMeanVelocity', NaN);
                rows{k, 8} = getfield2(a, 'Distance', NaN);
                rows{k, 9} = getfield2(a, 'FirstStartSec', NaN);
                rows{k,10} = getfield2(a, 'FirstEndSec', NaN);
            end
        end

        function W = tidyToWide(~, T)
            sessions = unique(T.session, 'stable');
            acts = unique(T.act, 'stable');
            W = table();
            W.session = sessions;
            for k = 1:numel(acts)
                col = nan(numel(sessions), 1);
                for sIx = 1:numel(sessions)
                    mask = strcmp(T.session, sessions{sIx}) ...
                        & strcmp(T.act, acts{k});
                    if any(mask); col(sIx) = T.percent(find(mask, 1)); end
                end
                W.(['percent_' matlab.lang.makeValidName(acts{k})]) = col;
            end
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
            if isfield(obj.State, 'barnes') && ~isempty(obj.State.barnes) ...
                    && height(obj.State.barnes) > 0
                obj.BarnesTable.ColumnName = obj.State.barnes.Properties.VariableNames;
                obj.BarnesTable.Data = table2cell(obj.State.barnes);
            else
                obj.BarnesTable.Data = {};
            end
        end

        function row = barnesMetricsToRow(~, res, s)
            % R26: serialise one BarnesMetrics struct to a row vector
            % matching the 9-column session table (id + 8 metrics).
            bm = res.BarnesMetrics;
            row = {s.id, ...
                getfield2(bm, 'TargetHoleVisitOrder', NaN), ...
                getfield2(bm, 'PrimaryErrors', NaN), ...
                getfield2(bm, 'TotalNoseHoleVisits', 0), ...
                getfield2(bm, 'TotalBodyHoleVisits', 0), ...
                getfield2(bm, 'NumCheckedHoles', 0), ...
                getfield2(bm, 'FirstCheckedHoleNumber', NaN), ...
                getfield2(bm, 'FirstCheckedHoleErrorDeg', NaN), ...
                getfield2(bm, 'MeanCheckedHoleErrorDeg', NaN)};
        end

        % ---------- Misc ------------------------------------------

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

% ---------- File-scope helpers ----------------------------------

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

function id = sessionIdFromDlcName(name)
    % Recover the session id from a DLC csv filename. R24 widens the
    % marker set so we handle BOTH:
    %   * Legacy DeepLabCut: '<id>DLC_<network>_...<iter>.csv'
    %     e.g. 'NOF_H01_3DDLC_resnet152_MiceUniversal152Oct23shuffle1
    %           _1000000.csv' -> 'NOF_H01_3D'
    %   * SuperAnimal-topviewmouse:
    %     '<id>_superanimal_topviewmouse_snapshot-...csv'
    %     e.g. 'Barnes_m183_5d_0t_26102024_120726_superanimal_..._snapshot-
    %           hrnet_w32-004.csv' -> 'Barnes_m183_5d_0t_26102024_120726'
    % Session ids in the wild may include:
    %   * lowercase / mixed-case prefix ('barnes' / 'Barnes' / 'BARNES')
    %   * multi-digit mouse id (m23 / m183 / m5718)
    %   * multi-digit day / trial counters (0d_0t / 12d_3t)
    % All of those are captured automatically by "strip from the first
    % model-suffix marker"; we do not encode the id structure itself.
    [~, stem, ~] = fileparts(name);
    markers = {'_superanimal', 'DLC_resnet', 'DLC_mobilenet', ...
        'DLC_efficientnet', 'DLC_', '_DeepCut_'};
    cutAt = numel(stem) + 1;
    for k = 1:numel(markers)
        idx = strfind(stem, markers{k});
        if ~isempty(idx); cutAt = min(cutAt, idx(1)); end
    end
    id = stem(1:cutAt - 1);
    id = regexprep(id, '_el$', '');  % drop multi-animal extension tag
    id = char(strtrim(string(id)));
end

function p = findFirstMatch(folder, id, suffixes)
    % Locate '<id><suffix>' for each requested suffix. R24: also
    % accept a per-session subfolder layout where the preset (or any
    % matched artefact) sits at '<folder>/<id>/<id><suffix>' --
    % CreatePreset writes both copies and Mr P's BARNES_v2 export
    % keeps both side by side.
    p = '';
    if isempty(folder) || ~isfolder(folder); return; end
    for k = 1:numel(suffixes)
        cand = fullfile(folder, [id suffixes{k}]);
        if isfile(cand); p = cand; return; end
        cand2 = fullfile(folder, id, [id suffixes{k}]);
        if isfile(cand2); p = cand2; return; end
    end
    hits = dir(fullfile(folder, [id '*']));
    hits = hits(~[hits.isdir]);
    if ~isempty(hits)
        p = fullfile(hits(1).folder, hits(1).name);
    end
end

function st = sessionStatus(s)
    okV = ~isempty(s.video)  && isfile(s.video);
    okP = ~isempty(s.preset) && isfile(s.preset);
    if okV && okP; st = 'full';
    elseif ~okV && ~okP; st = 'no-both';
    elseif ~okV; st = 'no-video';
    else; st = 'no-preset';
    end
end

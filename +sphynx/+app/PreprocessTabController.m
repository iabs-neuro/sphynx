classdef PreprocessTabController < handle
% PREPROCESSTABCONTROLLER  Controller for the "Preprocess Tracking" tab.
%
%   sphynx.app.PreprocessTabController(parentTab, parentApp) builds and
%   manages the second tab of CreatePresetApp: per-bodypart preprocess
%   settings, outlier filters, manual regions, and Save.
%
%   Slice 1 scope: Loading + Preview canvas only. Other blocks render
%   as placeholders and will be wired in later slices.
%
%   The controller is intentionally a separate handle class — keeps
%   CreatePresetApp focused on preset state.

    properties
        Tab                     % parent uitab
        Figure                  % parent uifigure (for refocus)
        ParentApp               % handle to CreatePresetApp (for shared state like project root)

        % Layout containers
        OuterGrid
        LeftPanel
        RightGrid

        % Block 1: Loading
        RootField
        DLCField
        VideoField
        PresetField

        % Block 2-4 placeholders (real content wired in later slices)
        PerPartPanel
        OutlierPanel
        RegionsPanel
        SavePanel

        % Preview
        AxX                     % X(t) trace
        AxY                     % Y(t) trace
        AxLk                    % likelihood histogram
        BodyPartDropDown
        PrevButton
        NextButton
        FrameLabel
        FrameSlider

        % Log
        LogTextArea

        % State
        State
    end

    methods
        function obj = PreprocessTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = sphynx.app.PreprocessTabController.emptyState();
            obj.buildUI();
            obj.applog('info', 'Preprocess Tracking tab initialized');
        end

        function delete(obj)  %#ok<INUSD>
            % uifigure cleanup is handled by CreatePresetApp.delete
        end

        % --- Programmatic API (stable for tests) ---------------------------
        function setPaths(obj, paths)
            % SETPATHS  paths is a struct with fields root, dlc, video, preset.
            fields = {'root', 'dlc', 'video', 'preset'};
            for k = 1:numel(fields)
                f = fields{k};
                if isfield(paths, f) && ~isempty(paths.(f))
                    obj.State.paths.(f) = paths.(f);
                end
            end
            obj.syncPathFields();
        end

        function loadAll(obj)
            % LOADALL  Validate paths and load DLC + preset frame.
            obj.collectPathsFromFields();
            if isempty(obj.State.paths.dlc)
                obj.applog('warn', 'DLC csv path is empty');
                return;
            end
            if ~isfile(obj.State.paths.dlc)
                obj.applog('error', 'DLC csv not found: %s', obj.State.paths.dlc);
                return;
            end
            try
                obj.State.dlc = sphynx.io.readDLC(obj.State.paths.dlc);
                obj.applog('info', 'Loaded DLC: %d frames, %d body parts', ...
                    obj.State.dlc.nFrames, numel(obj.State.dlc.bodyPartsNames));
            catch ME
                obj.applog('error', 'readDLC failed: %s', ME.message);
                return;
            end

            % Optional: load preset for frame + pxl2sm (used in Slice 4+)
            if ~isempty(obj.State.paths.preset) && isfile(obj.State.paths.preset)
                try
                    pd = sphynx.io.readPreset(obj.State.paths.preset);
                    obj.State.presetData = pd;
                    if isfield(pd, 'Options') && isfield(pd.Options, 'GoodVideoFrame')
                        obj.State.frame = pd.Options.GoodVideoFrame;
                    end
                    obj.applog('info', 'Loaded preset: %s', obj.State.paths.preset);
                catch ME
                    obj.applog('warn', 'readPreset failed: %s', ME.message);
                end
            end

            % Populate body-part dropdown
            obj.populateBodyPartDropDown();
            obj.State.currentBodyPart = 1;
            obj.State.currentFrame = 1;
            obj.refreshPreview();
        end

        function setCurrentBodyPart(obj, idx)
            if isempty(obj.State.dlc); return; end
            n = numel(obj.State.dlc.bodyPartsNames);
            idx = max(1, min(n, idx));
            obj.State.currentBodyPart = idx;
            if ~isempty(obj.BodyPartDropDown)
                obj.BodyPartDropDown.Value = obj.BodyPartDropDown.Items{idx};
            end
            obj.refreshPreview();
        end

        function nextBodyPart(obj)
            obj.setCurrentBodyPart(obj.State.currentBodyPart + 1);
        end

        function prevBodyPart(obj)
            obj.setCurrentBodyPart(obj.State.currentBodyPart - 1);
        end

        function refreshPreview(obj)
            if isempty(obj.State.dlc); return; end
            i = obj.State.currentBodyPart;
            n = obj.State.dlc.nFrames;
            X = obj.State.dlc.X(i, :);
            Y = obj.State.dlc.Y(i, :);
            Lk = obj.State.dlc.likelihood(i, :);
            partName = obj.State.dlc.bodyPartsNames{i};
            t = (1:n);

            cla(obj.AxX); cla(obj.AxY); cla(obj.AxLk);

            % X(t)
            plot(obj.AxX, t, X, 'Color', [0.1 0.4 0.8], 'LineWidth', 1);
            title(obj.AxX, sprintf('%s — X (px)', partName), 'Interpreter', 'none');
            xlabel(obj.AxX, 'frame'); ylabel(obj.AxX, 'X, px');
            xlim(obj.AxX, [1 n]); grid(obj.AxX, 'on');

            % Y(t)
            plot(obj.AxY, t, Y, 'Color', [0.8 0.3 0.1], 'LineWidth', 1);
            title(obj.AxY, sprintf('%s — Y (px)', partName), 'Interpreter', 'none');
            xlabel(obj.AxY, 'frame'); ylabel(obj.AxY, 'Y, px');
            xlim(obj.AxY, [1 n]); grid(obj.AxY, 'on');

            % Likelihood histogram
            histogram(obj.AxLk, Lk, 50, 'FaceColor', [0.3 0.6 0.3]);
            title(obj.AxLk, sprintf('%s — likelihood histogram', partName), 'Interpreter', 'none');
            xlabel(obj.AxLk, 'likelihood'); ylabel(obj.AxLk, 'count');
            xlim(obj.AxLk, [0 1]); grid(obj.AxLk, 'on');

            % Frame label
            obj.FrameLabel.Text = sprintf('Frame %d / %d', obj.State.currentFrame, n);
        end
    end

    methods (Static)
        function s = emptyState()
            s.paths.root = '';
            s.paths.dlc = '';
            s.paths.video = '';
            s.paths.preset = '';
            s.dlc = [];
            s.presetData = [];
            s.frame = [];
            s.currentBodyPart = 1;
            s.currentFrame = 1;
        end
    end

    methods (Access = private)
        % ===== UI ===========================================================
        function buildUI(obj)
            obj.OuterGrid = uigridlayout(obj.Tab, [1, 2]);
            obj.OuterGrid.ColumnWidth = {380, '1x'};
            obj.OuterGrid.RowHeight = {'1x'};
            obj.OuterGrid.Padding = [4 4 4 4];
            obj.OuterGrid.ColumnSpacing = 6;

            obj.buildLeft();
            obj.buildRight();
        end

        function buildLeft(obj)
            % Scrollable container so all panels stay visible on shorter windows
            obj.LeftPanel = uigridlayout(obj.OuterGrid, [4, 1]);
            obj.LeftPanel.Layout.Column = 1;
            obj.LeftPanel.Scrollable = 'on';
            obj.LeftPanel.RowHeight = {110, 220, 140, 100};
            obj.LeftPanel.RowSpacing = 6;
            obj.LeftPanel.Padding = [2 2 2 2];

            obj.buildLoadingPanel();
            obj.buildPerPartPanelPlaceholder();
            obj.buildOutlierPanelPlaceholder();
            obj.buildSavePanelPlaceholder();
        end

        function buildLoadingPanel(obj)
            p = uipanel(obj.LeftPanel, 'Title', '1. Loading');
            p.Layout.Row = 1;
            g = uigridlayout(p, [2, 4]);
            g.RowHeight = {26, 26};
            g.ColumnWidth = {'1x', '1x', '1x', '1x'};
            g.ColumnSpacing = 4;
            g.Padding = [4 4 4 4];

            % Top row buttons
            btnRoot   = uibutton(g, 'Text', 'Root',   'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('root', 'dir'));
            btnRoot.Layout.Row = 1;   btnRoot.Layout.Column = 1;

            btnDLC    = uibutton(g, 'Text', 'DLC',    'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('dlc', 'file', '*.csv'));
            btnDLC.Layout.Row = 1;    btnDLC.Layout.Column = 2;

            btnVideo  = uibutton(g, 'Text', 'Video',  'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('video', 'file', '*.*'));
            btnVideo.Layout.Row = 1;  btnVideo.Layout.Column = 3;

            btnPreset = uibutton(g, 'Text', 'Preset', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPath('preset', 'file', '*.mat'));
            btnPreset.Layout.Row = 1; btnPreset.Layout.Column = 4;

            % Bottom row text fields
            obj.RootField   = uieditfield(g, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.collectPathsFromFields());
            obj.RootField.Layout.Row = 2;   obj.RootField.Layout.Column = 1;

            obj.DLCField    = uieditfield(g, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.collectPathsFromFields());
            obj.DLCField.Layout.Row = 2;    obj.DLCField.Layout.Column = 2;

            obj.VideoField  = uieditfield(g, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.collectPathsFromFields());
            obj.VideoField.Layout.Row = 2;  obj.VideoField.Layout.Column = 3;

            obj.PresetField = uieditfield(g, 'text', 'Value', '', ...
                'ValueChangedFcn', @(~,~) obj.collectPathsFromFields());
            obj.PresetField.Layout.Row = 2; obj.PresetField.Layout.Column = 4;

            % Try to inherit project root from sibling Preset tab
            obj.inheritRootFromParentApp();
        end

        function buildPerPartPanelPlaceholder(obj)
            obj.PerPartPanel = uipanel(obj.LeftPanel, 'Title', '2. Per-part settings');
            obj.PerPartPanel.Layout.Row = 2;
            g = uigridlayout(obj.PerPartPanel, [1, 1]);
            lbl = uilabel(g, 'Text', sprintf(['(Slice 2): per-bodypart settings table\n' ...
                'thr / window / interp / smooth / NotFound%% per row.\n' ...
                'Default this/all + Compute this/all + Auto thresholds.']), ...
                'HorizontalAlignment', 'center');
            lbl.Layout.Row = 1; lbl.Layout.Column = 1; %#ok<NASGU>
        end

        function buildOutlierPanelPlaceholder(obj)
            obj.OutlierPanel = uipanel(obj.LeftPanel, 'Title', '3. Outlier filter');
            obj.OutlierPanel.Layout.Row = 3;
            g = uigridlayout(obj.OutlierPanel, [1, 1]);
            lbl = uilabel(g, 'Text', sprintf(['(Slice 4): velocity-jump (default ON) +\n' ...
                'Hampel + Kalman (optional). Max velocity field: 50 cm/s.']), ...
                'HorizontalAlignment', 'center');
            lbl.Layout.Row = 1; lbl.Layout.Column = 1; %#ok<NASGU>
        end

        function buildSavePanelPlaceholder(obj)
            obj.SavePanel = uipanel(obj.LeftPanel, 'Title', '4. Save');
            obj.SavePanel.Layout.Row = 4;
            g = uigridlayout(obj.SavePanel, [1, 1]);
            lbl = uilabel(g, 'Text', sprintf(['(Slice 7): write per-experiment\n' ...
                'PreprocessSettings.mat + per-session Preprocessed.mat + plots.']), ...
                'HorizontalAlignment', 'center');
            lbl.Layout.Row = 1; lbl.Layout.Column = 1; %#ok<NASGU>
        end

        function buildRight(obj)
            obj.RightGrid = uigridlayout(obj.OuterGrid, [6, 1]);
            obj.RightGrid.Layout.Column = 2;
            obj.RightGrid.RowHeight = {'1x', '1x', '1x', 36, 100, 110};
            obj.RightGrid.RowSpacing = 4;
            obj.RightGrid.Padding = [2 2 2 2];

            % Three plot axes
            obj.AxX  = uiaxes(obj.RightGrid);  obj.AxX.Layout.Row  = 1;
            obj.AxY  = uiaxes(obj.RightGrid);  obj.AxY.Layout.Row  = 2;
            obj.AxLk = uiaxes(obj.RightGrid);  obj.AxLk.Layout.Row = 3;
            for ax = [obj.AxX, obj.AxY, obj.AxLk]
                ax.Box = 'on';
            end

            % Bodypart switcher row
            switcher = uigridlayout(obj.RightGrid, [1, 5]);
            switcher.Layout.Row = 4;
            switcher.RowHeight = {30};
            switcher.ColumnWidth = {40, '1x', 40, 200, 140};
            switcher.Padding = [0 0 0 0];
            switcher.ColumnSpacing = 4;

            obj.PrevButton = uibutton(switcher, 'Text', '<', ...
                'BackgroundColor', semanticColor('geometry'), ...
                'ButtonPushedFcn', @(~,~) obj.prevBodyPart());
            obj.PrevButton.Layout.Column = 1;

            obj.BodyPartDropDown = uidropdown(switcher, 'Items', {'(no DLC loaded)'}, ...
                'Value', '(no DLC loaded)', ...
                'ValueChangedFcn', @(s,~) obj.onDropDownChanged(s.Value));
            obj.BodyPartDropDown.Layout.Column = 2;

            obj.NextButton = uibutton(switcher, 'Text', '>', ...
                'BackgroundColor', semanticColor('geometry'), ...
                'ButtonPushedFcn', @(~,~) obj.nextBodyPart());
            obj.NextButton.Layout.Column = 3;

            btnLoad = uibutton(switcher, 'Text', 'Load all', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadAll());
            btnLoad.Layout.Column = 4;

            obj.FrameLabel = uilabel(switcher, 'Text', 'Frame -/-', ...
                'HorizontalAlignment', 'right');
            obj.FrameLabel.Layout.Column = 5;

            % Manual regions placeholder (Slice 5)
            obj.RegionsPanel = uipanel(obj.RightGrid, 'Title', 'Manual exclusion regions');
            obj.RegionsPanel.Layout.Row = 5;
            rg = uigridlayout(obj.RegionsPanel, [1, 1]);
            lbl = uilabel(rg, 'Text', '(Slice 5): Add region on frame, attach to bodypart.', ...
                'HorizontalAlignment', 'center');
            lbl.Layout.Row = 1; lbl.Layout.Column = 1; %#ok<NASGU>

            % Log
            obj.LogTextArea = uitextarea(obj.RightGrid, 'Editable', 'off', ...
                'Value', {''});
            obj.LogTextArea.Layout.Row = 6;
        end

        % ===== Helpers ======================================================
        function pickPath(obj, kind, mode, mask)
            startDir = obj.guessStartDir(kind);
            switch mode
                case 'dir'
                    sel = uigetdir(startDir, sprintf('Select %s', kind));
                    if isequal(sel, 0); obj.refocus(); return; end
                    obj.State.paths.(kind) = sel;
                case 'file'
                    if nargin < 4; mask = '*.*'; end
                    [fn, fp] = uigetfile(mask, sprintf('Select %s', kind), startDir);
                    if isequal(fn, 0); obj.refocus(); return; end
                    obj.State.paths.(kind) = fullfile(fp, fn);
            end
            obj.syncPathFields();
            obj.refocus();
        end

        function dir = guessStartDir(obj, kind)
            % Walk fallbacks: own root → DLC dir → preset dir → repo Demo
            if ~isempty(obj.State.paths.root); dir = obj.State.paths.root; return; end
            if ~isempty(obj.State.paths.(kind)); dir = fileparts(obj.State.paths.(kind)); return; end
            try
                dir = fullfile(sphynx.util.repoRoot(), 'Demo');
            catch
                dir = pwd;
            end
        end

        function inheritRootFromParentApp(obj)
            if isempty(obj.ParentApp); return; end
            try
                if ~isempty(obj.ParentApp.State.projectRoot)
                    obj.State.paths.root = obj.ParentApp.State.projectRoot;
                end
            catch
                % parent app state may not be initialized yet; ignore
            end
            obj.syncPathFields();
        end

        function syncPathFields(obj)
            % State -> fields
            if ~isempty(obj.RootField);   obj.RootField.Value   = obj.State.paths.root;   end
            if ~isempty(obj.DLCField);    obj.DLCField.Value    = obj.State.paths.dlc;    end
            if ~isempty(obj.VideoField);  obj.VideoField.Value  = obj.State.paths.video;  end
            if ~isempty(obj.PresetField); obj.PresetField.Value = obj.State.paths.preset; end
        end

        function collectPathsFromFields(obj)
            % Fields -> state
            if ~isempty(obj.RootField);   obj.State.paths.root   = obj.RootField.Value;   end
            if ~isempty(obj.DLCField);    obj.State.paths.dlc    = obj.DLCField.Value;    end
            if ~isempty(obj.VideoField);  obj.State.paths.video  = obj.VideoField.Value;  end
            if ~isempty(obj.PresetField); obj.State.paths.preset = obj.PresetField.Value; end
        end

        function populateBodyPartDropDown(obj)
            if isempty(obj.State.dlc); return; end
            names = obj.State.dlc.bodyPartsNames;
            obj.BodyPartDropDown.Items = names;
            obj.BodyPartDropDown.Value = names{1};
        end

        function onDropDownChanged(obj, name)
            idx = find(strcmp(obj.BodyPartDropDown.Items, name), 1);
            if isempty(idx); return; end
            obj.setCurrentBodyPart(idx);
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[Preprocess] ' fmt], varargin{:});
            if isempty(obj.LogTextArea) || ~isvalid(obj.LogTextArea); return; end
            line = sprintf(['[' upper(level) '] ' fmt], varargin{:});
            current = obj.LogTextArea.Value;
            if isempty(current); current = {}; end
            if ~iscell(current); current = cellstr(current); end
            current{end+1} = line;
            if numel(current) > 500
                current = current(end-499:end);
            end
            obj.LogTextArea.Value = current;
            try
                scroll(obj.LogTextArea, 'bottom');
            catch
                % R2020a: no scroll API
            end
        end

        function refocus(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                figure(obj.Figure);
            end
        end
    end
end

% ===== Local helpers =======================================================

function rgb = semanticColor(kind)
    switch kind
        case 'action';   rgb = [1.00 0.85 0.85];   % pale rose
        case 'geometry'; rgb = [1.00 0.96 0.78];   % pale yellow
        case 'info';     rgb = [0.78 0.95 0.95];   % pale teal
        otherwise;       rgb = [0.94 0.94 0.94];
    end
end

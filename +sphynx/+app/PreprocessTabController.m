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

        % Block 2: per-part settings
        PerPartPanel
        PerPartTable
        AutoMethodDropDown
        AutoParamField

        % Block 3: outlier filters
        OutlierPanel
        VJEnabledChk
        VJMaxField
        HampelEnabledChk
        HampelWindowField
        HampelSigmaField
        KalmanQField
        KalmanRField

        % Block 4 placeholder (Slice 7)
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
        LogScaleButton          % toggle linear/log Y on likelihood histogram

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

            % Populate body-part dropdown + default per-part settings
            obj.populateBodyPartDropDown();
            obj.populateDefaultPerPart();
            obj.refreshPerPartTable();
            obj.State.currentBodyPart = 1;
            obj.State.currentFrame = 1;
            obj.refreshPreview();
        end

        % --- Compute API -----------------------------------------------------
        function computePart(obj, idx)
            % COMPUTEPART  Run the pipeline for a single body part.
            if isempty(obj.State.dlc); return; end
            if idx < 1 || idx > numel(obj.State.dlc.bodyPartsNames); return; end
            settings = obj.State.perPart(idx);
            if ~settings.use
                obj.applog('info', 'Skipped %s (use=false)', settings.name);
                return;
            end
            ctx = obj.computeContext();
            rawX = obj.State.dlc.X(idx, :)';
            rawY = obj.State.dlc.Y(idx, :)';
            lk   = obj.State.dlc.likelihood(idx, :)';
            try
                out = sphynx.preprocess.applyPerPartSettings(rawX, rawY, lk, settings, ctx);
            catch ME
                obj.applog('error', 'Compute %s failed: %s', settings.name, ME.message);
                return;
            end
            obj.storeProcessed(idx, out);
            obj.refreshPerPartTable();
            if idx == obj.State.currentBodyPart
                obj.refreshPreview();
            end
            obj.applog('info', 'Computed %s: status=%s, NaN=%.2f%%, lowLk=%.2f%%', ...
                settings.name, out.status, out.percentNaN, out.percentLowLikelihood);
        end

        function computeAll(obj)
            if isempty(obj.State.dlc); return; end
            for k = 1:numel(obj.State.perPart)
                obj.computePart(k);
            end
        end

        function defaultPart(obj, idx)
            if isempty(obj.State.dlc); return; end
            cfg = sphynx.pipeline.defaultConfig();
            name = obj.State.dlc.bodyPartsNames{idx};
            d = sphynx.preprocess.perPartDefault(name, cfg);
            obj.State.perPart(idx).likelihoodThreshold  = d.likelihoodThreshold;
            obj.State.perPart(idx).smoothWindowSec      = d.smoothWindowSec;
            obj.State.perPart(idx).interpolationMethod  = d.interpolationMethod;
            obj.State.perPart(idx).smoothingMethod      = d.smoothingMethod;
            obj.State.perPart(idx).smoothingPolyOrder   = d.smoothingPolyOrder;
            obj.State.perPart(idx).notFoundThresholdPct = d.notFoundThresholdPct;
            obj.State.perPart(idx).use = true;
            obj.refreshPerPartTable();
        end

        function defaultAll(obj)
            for k = 1:numel(obj.State.perPart)
                obj.defaultPart(k);
            end
        end

        function autoThresholdPart(obj, idx)
            if isempty(obj.State.dlc); return; end
            if idx < 1 || idx > numel(obj.State.perPart); return; end
            method = obj.AutoMethodDropDown.Value;
            param = obj.parseAutoParam(method, obj.AutoParamField.Value);
            Lk = obj.State.dlc.likelihood(idx, :)';
            try
                thr = sphynx.preprocess.autoThreshold(Lk, method, param);
            catch ME
                obj.applog('error', 'Auto[%s] failed for %s: %s', ...
                    method, obj.State.perPart(idx).name, ME.message);
                return;
            end
            obj.State.perPart(idx).likelihoodThreshold = thr;
            obj.refreshPerPartTable();
            if idx == obj.State.currentBodyPart
                obj.refreshPreview();
            end
            obj.applog('info', 'Auto[%s]: %s -> thr=%.3f', ...
                method, obj.State.perPart(idx).name, thr);
        end

        function autoThresholdAll(obj)
            if isempty(obj.State.dlc); return; end
            for k = 1:numel(obj.State.perPart)
                obj.autoThresholdPart(k);
            end
        end

        function p = parseAutoParam(~, method, raw)
            % Decide param based on method; raw is whatever the user typed.
            raw = strtrim(raw);
            switch lower(method)
                case 'quantile'
                    if isempty(raw); p = 0.05; return; end
                    val = str2double(raw);
                    if isnan(val); p = 0.05; else; p = max(0.001, min(0.999, val)); end
                case 'preset'
                    if isempty(raw); p = 'moderate'; return; end
                    p = lower(raw);
                otherwise
                    p = [];
            end
        end

        function onAutoMethodChanged(obj, method)
            switch lower(method)
                case 'quantile'; obj.AutoParamField.Value = '0.05';
                case 'preset';   obj.AutoParamField.Value = 'moderate';
                otherwise;       obj.AutoParamField.Value = '';
            end
        end

        function ctx = computeContext(obj)
            % Frame size + frame rate from preset if loaded, else fall back
            % to plausible defaults that don't crash bounds checks.
            ctx.frameWidth  = 1e9;
            ctx.frameHeight = 1e9;
            ctx.frameRate   = 30;
            ctx.pixelsPerCm = [];
            if ~isempty(obj.State.presetData) && isfield(obj.State.presetData, 'Options')
                opt = obj.State.presetData.Options;
                if isfield(opt, 'Width');     ctx.frameWidth  = opt.Width;     end
                if isfield(opt, 'Height');    ctx.frameHeight = opt.Height;    end
                if isfield(opt, 'FrameRate'); ctx.frameRate   = opt.FrameRate; end
                if isfield(opt, 'pxl2sm');    ctx.pixelsPerCm = opt.pxl2sm;    end
            end
            ctx.outlier = obj.State.outlier;
        end

        function storeProcessed(obj, idx, out)
            % Lazily extend the processed array as needed
            while numel(obj.State.processed) < idx
                obj.State.processed(end+1) = struct('X_clean', [], 'Y_clean', [], ...
                    'X_interp', [], 'Y_interp', [], 'X_smooth', [], 'Y_smooth', [], ...
                    'percentNaN', NaN, 'percentLowLikelihood', NaN, ...
                    'percentBadCombined', NaN, 'percentOutliers', NaN, ...
                    'status', '');
            end
            obj.State.processed(idx) = out;
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

            % Likelihood histogram — fine bins (0.01 wide) for thresholding
            histogram(obj.AxLk, Lk, 'BinWidth', 0.01, ...
                'FaceColor', [0.3 0.6 0.3], 'EdgeColor', 'none');
            title(obj.AxLk, sprintf('%s — likelihood histogram', partName), 'Interpreter', 'none');
            xlabel(obj.AxLk, 'likelihood'); ylabel(obj.AxLk, 'count');
            xlim(obj.AxLk, [0 1]); grid(obj.AxLk, 'on');
            if ~isempty(obj.LogScaleButton) && obj.LogScaleButton.Value
                obj.AxLk.YScale = 'log';
                ylabel(obj.AxLk, 'count (log)');
            else
                obj.AxLk.YScale = 'linear';
            end
            % Threshold marker (vertical line) for the current part
            if i <= numel(obj.State.perPart)
                thr = obj.State.perPart(i).likelihoodThreshold;
                hold(obj.AxLk, 'on');
                yLim = obj.AxLk.YLim;
                plot(obj.AxLk, [thr thr], yLim, '-', ...
                    'Color', [0.85 0.10 0.10], 'LineWidth', 1.5);
                hold(obj.AxLk, 'off');
            end

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
            % Outlier filter defaults (global per experiment, not per-part)
            s.outlier.velocityJump.enabled = true;
            s.outlier.velocityJump.maxVelocityCmS = 50;
            s.outlier.hampel.enabled = false;
            s.outlier.hampel.windowSize = 7;
            s.outlier.hampel.nSigma = 3;
            s.outlier.kalman.processNoise = 1e-2;
            s.outlier.kalman.measNoiseScale = 1.0;
            % Per-part settings (1xK struct, populated on Load)
            s.perPart = sphynx.app.PreprocessTabController.emptyPerPartArray();
            % Per-part processed traces (1xK struct, populated on Compute)
            s.processed = struct('X_clean', {}, 'Y_clean', {}, ...
                'X_interp', {}, 'Y_interp', {}, ...
                'X_smooth', {}, 'Y_smooth', {}, ...
                'percentNaN', {}, 'percentLowLikelihood', {}, ...
                'percentBadCombined', {}, 'percentOutliers', {}, ...
                'status', {});
        end

        function arr = emptyPerPartArray()
            arr = struct('name', {}, 'use', {}, 'likelihoodThreshold', {}, ...
                'smoothWindowSec', {}, 'interpolationMethod', {}, ...
                'smoothingMethod', {}, 'smoothingPolyOrder', {}, ...
                'notFoundThresholdPct', {});
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
            obj.LeftPanel.RowHeight = {110, 360, 140, 100};
            obj.LeftPanel.RowSpacing = 6;
            obj.LeftPanel.Padding = [2 2 2 2];

            obj.buildLoadingPanel();
            obj.buildPerPartPanel();
            obj.buildOutlierPanel();
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

        function buildPerPartPanel(obj)
            obj.PerPartPanel = uipanel(obj.LeftPanel, 'Title', '2. Per-part settings');
            obj.PerPartPanel.Layout.Row = 2;
            g = uigridlayout(obj.PerPartPanel, [3, 1]);
            g.RowHeight = {'1x', 32, 32};
            g.RowSpacing = 4;
            g.Padding = [4 4 4 4];

            % uitable with per-part settings
            obj.PerPartTable = uitable(g, ...
                'ColumnName', {'use', 'name', 'thr', 'win,s', 'interp', 'smooth', 'NF%', '%NaN', '%lowL', 'status'}, ...
                'ColumnFormat', {'logical', 'char', 'numeric', 'numeric', ...
                    {'pchip', 'linear', 'spline', 'makima'}, ...
                    {'sgolay', 'movmean', 'movmedian', 'gaussian', 'kalman'}, ...
                    'numeric', 'char', 'char', 'char'}, ...
                'ColumnEditable', [true false true true true true true false false false], ...
                'ColumnWidth', {38, 90, 44, 50, 60, 70, 40, 50, 50, 60}, ...
                'RowName', {}, ...
                'CellEditCallback', @(~, evt) obj.onPerPartTableEdited(evt), ...
                'CellSelectionCallback', @(~, evt) obj.onPerPartTableSelected(evt));
            obj.PerPartTable.Layout.Row = 1; obj.PerPartTable.Layout.Column = 1;

            % Default/Compute row
            btnRow = uigridlayout(g, [1, 4]);
            btnRow.Layout.Row = 2; btnRow.Layout.Column = 1;
            btnRow.RowHeight = {28};
            btnRow.ColumnWidth = {'1x', '1x', '1x', '1x'};
            btnRow.Padding = [0 0 0 0];
            btnRow.ColumnSpacing = 4;

            b1 = uibutton(btnRow, 'Text', 'Default this', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.defaultSelected());
            b1.Layout.Column = 1;
            b2 = uibutton(btnRow, 'Text', 'Default all', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.defaultAll());
            b2.Layout.Column = 2;
            b3 = uibutton(btnRow, 'Text', 'Compute this', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.computeSelected());
            b3.Layout.Column = 3;
            b4 = uibutton(btnRow, 'Text', 'Compute all', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.computeAll());
            b4.Layout.Column = 4;

            % Auto-threshold row
            autoRow = uigridlayout(g, [1, 5]);
            autoRow.Layout.Row = 3; autoRow.Layout.Column = 1;
            autoRow.RowHeight = {28};
            autoRow.ColumnWidth = {44, 100, 80, '1x', '1x'};
            autoRow.Padding = [0 0 0 0];
            autoRow.ColumnSpacing = 4;

            lblAuto = uilabel(autoRow, 'Text', 'Auto:', ...
                'HorizontalAlignment', 'right');
            lblAuto.Layout.Column = 1; %#ok<NASGU>

            obj.AutoMethodDropDown = uidropdown(autoRow, ...
                'Items', {'otsu', 'knee', 'quantile', 'preset'}, ...
                'Value', 'otsu', ...
                'ValueChangedFcn', @(s, ~) obj.onAutoMethodChanged(s.Value));
            obj.AutoMethodDropDown.Layout.Column = 2;

            obj.AutoParamField = uieditfield(autoRow, 'text', ...
                'Value', '', ...
                'Tooltip', 'param: quantile=0.05 / preset=aggressive|moderate|lax');
            obj.AutoParamField.Layout.Column = 3;

            bA1 = uibutton(autoRow, 'Text', 'Auto this', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.autoThresholdPart(obj.State.currentBodyPart));
            bA1.Layout.Column = 4;
            bA2 = uibutton(autoRow, 'Text', 'Auto all', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.autoThresholdAll());
            bA2.Layout.Column = 5;
        end

        function buildOutlierPanel(obj)
            obj.OutlierPanel = uipanel(obj.LeftPanel, 'Title', '3. Outlier filter');
            obj.OutlierPanel.Layout.Row = 3;
            g = uigridlayout(obj.OutlierPanel, [3, 4]);
            g.RowHeight = {26, 26, 26};
            g.ColumnWidth = {120, 80, '1x', 80};
            g.RowSpacing = 4;
            g.ColumnSpacing = 4;
            g.Padding = [4 4 4 4];

            % Row 1: velocity-jump
            obj.VJEnabledChk = uicheckbox(g, 'Text', 'velocity-jump', ...
                'Value', obj.State.outlier.velocityJump.enabled, ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('vj_enabled', s.Value));
            obj.VJEnabledChk.Layout.Row = 1; obj.VJEnabledChk.Layout.Column = 1;

            lbl1 = uilabel(g, 'Text', 'max cm/s:', 'HorizontalAlignment', 'right');
            lbl1.Layout.Row = 1; lbl1.Layout.Column = 2;

            obj.VJMaxField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.velocityJump.maxVelocityCmS, ...
                'Limits', [1 1000], ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('vj_max', s.Value));
            obj.VJMaxField.Layout.Row = 1; obj.VJMaxField.Layout.Column = 3;

            % Row 2: Hampel
            obj.HampelEnabledChk = uicheckbox(g, 'Text', 'Hampel', ...
                'Value', obj.State.outlier.hampel.enabled, ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('hp_enabled', s.Value));
            obj.HampelEnabledChk.Layout.Row = 2; obj.HampelEnabledChk.Layout.Column = 1;

            lbl2 = uilabel(g, 'Text', 'win:', 'HorizontalAlignment', 'right');
            lbl2.Layout.Row = 2; lbl2.Layout.Column = 2;

            obj.HampelWindowField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.hampel.windowSize, ...
                'Limits', [1 1000], 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('hp_win', s.Value));
            obj.HampelWindowField.Layout.Row = 2; obj.HampelWindowField.Layout.Column = 3;

            obj.HampelSigmaField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.hampel.nSigma, ...
                'Limits', [0.1 10], 'Tooltip', 'k (sigma)', ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('hp_sig', s.Value));
            obj.HampelSigmaField.Layout.Row = 2; obj.HampelSigmaField.Layout.Column = 4;

            % Row 3: Kalman params (used when smoothing=kalman per part)
            lblK = uilabel(g, 'Text', 'Kalman:', 'HorizontalAlignment', 'left');
            lblK.Layout.Row = 3; lblK.Layout.Column = 1;

            lblK1 = uilabel(g, 'Text', 'Q:', 'HorizontalAlignment', 'right');
            lblK1.Layout.Row = 3; lblK1.Layout.Column = 2;

            obj.KalmanQField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.kalman.processNoise, ...
                'Limits', [1e-6 100], ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('kf_q', s.Value));
            obj.KalmanQField.Layout.Row = 3; obj.KalmanQField.Layout.Column = 3;

            obj.KalmanRField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.kalman.measNoiseScale, ...
                'Limits', [1e-6 1000], 'Tooltip', 'measurement noise scale', ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('kf_r', s.Value));
            obj.KalmanRField.Layout.Row = 3; obj.KalmanRField.Layout.Column = 4;
        end

        function onOutlierFlagChanged(obj, key, val)
            switch key
                case 'vj_enabled'; obj.State.outlier.velocityJump.enabled = logical(val);
                case 'vj_max';     obj.State.outlier.velocityJump.maxVelocityCmS = val;
                case 'hp_enabled'; obj.State.outlier.hampel.enabled = logical(val);
                case 'hp_win';     obj.State.outlier.hampel.windowSize = max(1, round(val));
                case 'hp_sig';     obj.State.outlier.hampel.nSigma = val;
                case 'kf_q';       obj.State.outlier.kalman.processNoise = val;
                case 'kf_r';       obj.State.outlier.kalman.measNoiseScale = val;
            end
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

            % Bodypart switcher row — compact buttons, dropdown takes the rest
            switcher = uigridlayout(obj.RightGrid, [1, 6]);
            switcher.Layout.Row = 4;
            switcher.RowHeight = {28};
            switcher.ColumnWidth = {28, 160, 28, 80, 80, '1x'};
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

            btnLoad = uibutton(switcher, 'Text', 'Load', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadAll());
            btnLoad.Layout.Column = 4;

            obj.LogScaleButton = uibutton(switcher, 'state', 'Text', 'log Y', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.LogScaleButton.Layout.Column = 5;

            obj.FrameLabel = uilabel(switcher, 'Text', 'Frame -/-', ...
                'HorizontalAlignment', 'right');
            obj.FrameLabel.Layout.Column = 6;

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

        function populateDefaultPerPart(obj)
            if isempty(obj.State.dlc); return; end
            names = obj.State.dlc.bodyPartsNames;
            cfg = sphynx.pipeline.defaultConfig();
            arr = sphynx.app.PreprocessTabController.emptyPerPartArray();
            for k = 1:numel(names)
                d = sphynx.preprocess.perPartDefault(names{k}, cfg);
                arr(k).name                  = names{k};
                arr(k).use                   = true;
                arr(k).likelihoodThreshold   = d.likelihoodThreshold;
                arr(k).smoothWindowSec       = d.smoothWindowSec;
                arr(k).interpolationMethod   = d.interpolationMethod;
                arr(k).smoothingMethod       = d.smoothingMethod;
                arr(k).smoothingPolyOrder    = d.smoothingPolyOrder;
                arr(k).notFoundThresholdPct  = d.notFoundThresholdPct;
            end
            obj.State.perPart = arr;
            % Reset processed cache
            obj.State.processed = struct('X_clean', {}, 'Y_clean', {}, ...
                'X_interp', {}, 'Y_interp', {}, ...
                'X_smooth', {}, 'Y_smooth', {}, ...
                'percentNaN', {}, 'percentLowLikelihood', {}, ...
                'percentBadCombined', {}, 'percentOutliers', {}, ...
                'status', {});
        end

        function refreshPerPartTable(obj)
            if isempty(obj.PerPartTable) || ~isvalid(obj.PerPartTable); return; end
            arr = obj.State.perPart;
            n = numel(arr);
            if n == 0
                obj.PerPartTable.Data = {};
                return;
            end
            data = cell(n, 10);
            for k = 1:n
                if k <= numel(obj.State.processed) && ~isempty(obj.State.processed(k).status)
                    pct = obj.State.processed(k);
                    pNaN = sprintf('%.1f', pct.percentNaN);
                    pLow = sprintf('%.1f', pct.percentLowLikelihood);
                    pOut = sprintf('%.1f', pct.percentOutliers);
                    status = pct.status;
                else
                    pNaN = '-'; pLow = '-'; pOut = '-'; status = '-';
                end
                data{k, 1}  = arr(k).use;
                data{k, 2}  = arr(k).name;
                data{k, 3}  = arr(k).likelihoodThreshold;
                data{k, 4}  = arr(k).smoothWindowSec;
                data{k, 5}  = arr(k).interpolationMethod;
                data{k, 6}  = arr(k).smoothingMethod;
                data{k, 7}  = arr(k).notFoundThresholdPct;
                data{k, 8}  = pNaN;
                data{k, 9}  = pLow;
                data{k, 10} = status;
            end
            obj.PerPartTable.Data = data;
        end

        function onPerPartTableEdited(obj, evt)
            % Update the per-part struct in response to a uitable edit.
            row = evt.Indices(1);
            col = evt.Indices(2);
            if row < 1 || row > numel(obj.State.perPart); return; end
            newVal = evt.NewData;
            switch col
                case 1; obj.State.perPart(row).use                  = logical(newVal);
                case 3; obj.State.perPart(row).likelihoodThreshold  = clampScalar(newVal, 0, 1);
                case 4; obj.State.perPart(row).smoothWindowSec      = max(0.01, newVal);
                case 5; obj.State.perPart(row).interpolationMethod  = newVal;
                case 6; obj.State.perPart(row).smoothingMethod      = newVal;
                case 7; obj.State.perPart(row).notFoundThresholdPct = clampScalar(newVal, 0, 100);
                otherwise
                    return;  % read-only columns
            end
            obj.refreshPerPartTable();
        end

        function onPerPartTableSelected(obj, evt)
            % Single-click on a row -> switch the preview to that part.
            if isempty(evt.Indices); return; end
            row = evt.Indices(1);
            if row < 1; return; end
            obj.setCurrentBodyPart(row);
        end

        function selectedPartIndex(obj)
            % Helper: for "Compute this" / "Default this" use the current
            % preview part. Returns [] if nothing loaded.
            if isempty(obj.State.dlc); return; end
            obj.applog('debug', 'Selected part: %d', obj.State.currentBodyPart);
        end

        function computeSelected(obj)
            if isempty(obj.State.dlc); return; end
            obj.computePart(obj.State.currentBodyPart);
        end

        function defaultSelected(obj)
            if isempty(obj.State.dlc); return; end
            obj.defaultPart(obj.State.currentBodyPart);
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

function v = clampScalar(x, lo, hi)
    v = max(lo, min(hi, x));
end

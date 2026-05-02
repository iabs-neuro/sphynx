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

        % Manual exclusion regions (right column)
        RegionsPanel
        RegionsListBox
        RegionsAppliesDropDown
        RegionsScopeDropDown    % per-region scope (experiment | session)

        % Embedded video viewer
        VideoPanel
        VideoAxes
        VideoSlider
        VideoLabel
        ShowVideoButton
        VideoReader_           % VideoReader handle (trailing underscore: avoid name clash)
        VideoWindow            % standalone PreprocessVideoWindow (Slice E)

        % Block 4: Save
        SavePanel
        OutputDirField
        SavePlotsCheckbox

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
        XUnitsDropDown          % 'frame' | 'sec' | 'min'
        FromFrameField
        ToFrameField
        GoToFrameField          % video panel
        ShowRawChk              % toggle raw curve overlay
        ShowInterpChk
        ShowSmoothChk
        RefreshTimer            % debounce timer for viewport edits

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

        function loadSynthetic(obj)
            % LOADSYNTHETIC  Generate a default synthetic DLC scenario in
            % a temp file and load it as if it were a real csv. Useful
            % for poking at the preprocess pipeline without a real session.
            try
                tmp = tempname();
                csvPath = [tmp '.csv'];
                synth = sphynx.preprocess.makeSyntheticDLC( ...
                    'CsvPath', csvPath, 'OutlierMode', 'mixed');
                obj.State.paths.dlc = csvPath;
                obj.State.paths.preset = '';
                obj.State.paths.video = '';
                obj.syncPathFields();
                obj.applog('info', 'Synthetic DLC generated: %d frames, %d parts (mixed outliers)', ...
                    synth.nFrames, numel(synth.bodyPartsNames));
                % Stash a minimal preset-like struct so velocity-jump and
                % bounds work without requiring an actual preset file.
                pd.Options.Width = synth.frameWidth;
                pd.Options.Height = synth.frameHeight;
                pd.Options.FrameRate = synth.frameRate;
                pd.Options.pxl2sm = synth.pixelsPerCm;
                pd.Options.GoodVideoFrame = uint8(zeros(synth.frameHeight, synth.frameWidth, 3) + 64);
                obj.State.presetData = pd;
                obj.State.frame = pd.Options.GoodVideoFrame;
                obj.loadAll();
            catch ME
                obj.applog('error', 'loadSynthetic failed: %s', ME.message);
            end
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
            obj.refreshAppliesDropDown();
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
            ctx.partName = settings.name;
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
                if obj.State.perPart(k).use
                    obj.autoThresholdPart(k);
                end
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
            ctx.manualRegions = obj.State.manualRegions;
        end

        function storeProcessed(obj, idx, out)
            % Lazily extend the processed array as needed.
            % Field order MUST match the struct returned by
            % sphynx.preprocess.applyPerPartSettings (otherwise MATLAB
            % errors with heterogeneousStrucAssignment).
            placeholder = struct( ...
                'X_clean', [], 'Y_clean', [], ...
                'X_interp', [], 'Y_interp', [], ...
                'X_smooth', [], 'Y_smooth', [], ...
                'percentNaN', NaN, 'percentLowLikelihood', NaN, ...
                'percentBadCombined', NaN, 'percentOutliers', NaN, ...
                'percentManual', NaN, 'status', '');
            while numel(obj.State.processed) < idx
                obj.State.processed(end+1) = placeholder;
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

        function pickOutputDir(obj)
            startDir = obj.guessStartDir('root');
            sel = uigetdir(startDir, 'Select output dir');
            if isequal(sel, 0); obj.refocus(); return; end
            obj.OutputDirField.Value = sel;
            obj.refocus();
        end

        function pathsOut = savePreprocessed(obj)
            % SAVEPREPROCESSED  Persist settings + per-session traces (+ plots).
            pathsOut = struct();
            if isempty(obj.State.dlc)
                obj.applog('warn', 'Save: no DLC loaded');
                return;
            end
            outDir = '';
            if ~isempty(obj.OutputDirField); outDir = obj.OutputDirField.Value; end
            if isempty(outDir)
                obj.applog('warn', 'Save: output directory is empty');
                return;
            end

            % Stale check: if any 'use' part has no processed entry, recompute
            staleParts = false;
            for k = 1:numel(obj.State.perPart)
                if ~obj.State.perPart(k).use; continue; end
                if k > numel(obj.State.processed) || isempty(obj.State.processed(k).status)
                    staleParts = true; break;
                end
            end
            if staleParts
                obj.applog('info', 'Save: some parts not yet computed — running Compute all');
                obj.computeAll();
            end

            opts = struct( ...
                'outputDir',      outDir, ...
                'savePlots',      ~isempty(obj.SavePlotsCheckbox) && obj.SavePlotsCheckbox.Value, ...
                'experimentName', '');
            try
                pathsOut = sphynx.preprocess.exportTracks(obj.State, opts);
                obj.applog('info', 'Saved settings -> %s', pathsOut.settings);
                obj.applog('info', 'Saved session  -> %s', pathsOut.session);
                if ~isempty(pathsOut.plotsDir)
                    obj.applog('info', 'Saved plots    -> %s', pathsOut.plotsDir);
                end
            catch ME
                obj.applog('error', 'Save failed: %s', ME.message);
            end
        end

        function setCurrentFrame(obj, frameIdx)
            % SETCURRENTFRAME  Move the playhead, refresh video + sync line.
            if isempty(obj.State.dlc); return; end
            n = obj.State.dlc.nFrames;
            frameIdx = max(1, min(n, round(frameIdx)));
            obj.State.currentFrame = frameIdx;
            obj.refreshVideoFrame();
            obj.refreshPlayheadOnPlots();
            if ~isempty(obj.FrameLabel)
                obj.FrameLabel.Text = sprintf('Frame %d / %d', frameIdx, n);
            end
            if ~isempty(obj.VideoSlider) && isvalid(obj.VideoSlider)
                % Embedded slider remains hidden in Slice E but we still
                % bound-check before setting Value or MATLAB throws.
                lim = obj.VideoSlider.Limits;
                if frameIdx >= lim(1) && frameIdx <= lim(2)
                    obj.VideoSlider.Value = frameIdx;
                end
            end
            % Sync the standalone video window if open
            if ~isempty(obj.VideoWindow) && isvalid(obj.VideoWindow)
                obj.VideoWindow.refreshFrame();
            end
        end

        function toggleVideoPanel(obj, enabled)
            % TOGGLEVIDEOPANEL  Open/close the standalone video window.
            % (Slice E: standalone uifigure; Slice DD: embedded panel
            % removed entirely from the layout.)
            if enabled
                obj.openVideoReader();
                if isempty(obj.VideoReader_); return; end
                if isempty(obj.VideoWindow) || ~isvalid(obj.VideoWindow)
                    obj.VideoWindow = sphynx.app.PreprocessVideoWindow(obj);
                end
                obj.setCurrentFrame(obj.State.currentFrame);
            else
                if ~isempty(obj.VideoWindow) && isvalid(obj.VideoWindow)
                    delete(obj.VideoWindow);
                    obj.VideoWindow = [];
                end
            end
        end

        function clearAll(obj)
            % CLEARALL  Wipe loaded DLC / preset / settings / regions and
            % the table; keep the path fields so the user can re-Load.
            obj.State.dlc = [];
            obj.State.presetData = [];
            obj.State.frame = [];
            obj.State.currentBodyPart = 1;
            obj.State.currentFrame = 1;
            obj.State.lastDrawnBodyPart = [];
            obj.State.perPart = sphynx.app.PreprocessTabController.emptyPerPartArray();
            obj.State.processed = struct('X_clean', {}, 'Y_clean', {}, ...
                'X_interp', {}, 'Y_interp', {}, ...
                'X_smooth', {}, 'Y_smooth', {}, ...
                'percentNaN', {}, 'percentLowLikelihood', {}, ...
                'percentBadCombined', {}, 'percentOutliers', {}, ...
                'percentManual', {}, 'status', {});
            obj.State.manualRegions = struct('vertices', {}, 'appliesTo', {}, 'scope', {});
            obj.refreshPerPartTable();
            obj.refreshRegionsListBox();
            obj.refreshAppliesDropDown();
            if ~isempty(obj.AxX) && isvalid(obj.AxX); cla(obj.AxX); end
            if ~isempty(obj.AxY) && isvalid(obj.AxY); cla(obj.AxY); end
            if ~isempty(obj.AxLk) && isvalid(obj.AxLk); cla(obj.AxLk); end
            if ~isempty(obj.BodyPartDropDown) && isvalid(obj.BodyPartDropDown)
                obj.BodyPartDropDown.Items = {'(no DLC loaded)'};
                obj.BodyPartDropDown.Value = '(no DLC loaded)';
            end
            % Close standalone video window if open
            if ~isempty(obj.VideoWindow) && isvalid(obj.VideoWindow)
                delete(obj.VideoWindow);
                obj.VideoWindow = [];
            end
            obj.VideoReader_ = [];
            obj.applog('info', 'Cleared all (paths kept)');
        end

        function setManualRegions(obj, regs)
            % SETMANUALREGIONS  Replace the whole region list + refresh UI.
            obj.State.manualRegions = regs;
            obj.refreshRegionsListBox();
        end

        function clearManualRegions(obj)
            obj.clearAllRegions();
        end

        function deleteManualRegion(obj, idx)
            n = numel(obj.State.manualRegions);
            if idx < 1 || idx > n; return; end
            obj.State.manualRegions(idx) = [];
            obj.refreshRegionsListBox();
        end

        function scheduleRefresh(obj)
            % Debounce viewport edits (~500ms). Each keystroke restarts the
            % timer; only the last edit fires refreshPreview.
            if ~isempty(obj.RefreshTimer) && isvalid(obj.RefreshTimer)
                try; stop(obj.RefreshTimer); catch; end
                try; delete(obj.RefreshTimer); catch; end
            end
            obj.RefreshTimer = timer( ...
                'ExecutionMode', 'singleShot', ...
                'StartDelay', 0.5, ...
                'TimerFcn', @(~,~) obj.refreshPreview());
            start(obj.RefreshTimer);
        end

        function refreshPreview(obj)
            if isempty(obj.State.dlc); return; end
            i = obj.State.currentBodyPart;
            n = obj.State.dlc.nFrames;
            X = obj.State.dlc.X(i, :);
            Y = obj.State.dlc.Y(i, :);
            Lk = obj.State.dlc.likelihood(i, :);
            partName = obj.State.dlc.bodyPartsNames{i};

            % Compute viewport (from/to frame). 0 = last.
            fromF = 1; toF = n;
            if ~isempty(obj.FromFrameField); fromF = max(1, min(n, obj.FromFrameField.Value)); end
            if ~isempty(obj.ToFrameField)
                v = obj.ToFrameField.Value;
                if v == 0; toF = n; else; toF = max(fromF, min(n, v)); end
            end

            % Pick X-axis units
            xUnits = 'frame'; xLabel = 'frame'; xScale = 1;
            if ~isempty(obj.XUnitsDropDown); xUnits = obj.XUnitsDropDown.Value; end
            fps = pickFrameRate(obj);
            switch xUnits
                case 'sec'; xLabel = 'time, s';   xScale = 1/fps;
                case 'min'; xLabel = 'time, min'; xScale = 1/(fps*60);
                otherwise;  xLabel = 'frame';     xScale = 1;
            end
            t = (1:n) * xScale;

            % Pick Y units (cm if pxlPerCm available, else px)
            ppc = pickPxlPerCm(obj);
            if ~isempty(ppc) && ppc > 0
                yScale = 1/ppc; yUnitX = 'X, cm'; yUnitY = 'Y, cm';
            else
                yScale = 1; yUnitX = 'X, px'; yUnitY = 'Y, px';
            end

            % Capture current zoom so it survives recompute (only on same part
            % AND same units). Otherwise reset to viewport.
            sameView = ~isempty(obj.State.lastDrawnBodyPart) && ...
                obj.State.lastDrawnBodyPart == i && ...
                strcmp(obj.State.lastDrawnUnits, xUnits) && ...
                obj.State.lastDrawnYUnit == (yScale ~= 1);
            if sameView
                xlimX = obj.AxX.XLim; ylimX = obj.AxX.YLim;
                xlimY = obj.AxY.XLim; ylimY = obj.AxY.YLim;
            end

            cla(obj.AxX); cla(obj.AxY); cla(obj.AxLk);

            % Decide which curves to overlay
            showRaw    = isempty(obj.ShowRawChk)    || obj.ShowRawChk.Value;
            showInterp = isempty(obj.ShowInterpChk) || obj.ShowInterpChk.Value;
            showSmooth = isempty(obj.ShowSmoothChk) || obj.ShowSmoothChk.Value;

            % Pull processed traces if available
            hasProcessed = i <= numel(obj.State.processed) && ...
                ~isempty(obj.State.processed) && ...
                ~isempty(obj.State.processed(i).status) && ...
                strcmp(obj.State.processed(i).status, 'Good');
            if hasProcessed
                p = obj.State.processed(i);
                Xint = p.X_interp(:)' * yScale;
                Yint = p.Y_interp(:)' * yScale;
                Xsm  = p.X_smooth(:)' * yScale;
                Ysm  = p.Y_smooth(:)' * yScale;
            else
                Xint = []; Yint = []; Xsm = []; Ysm = [];
            end

            % Highlight frames flagged as bad in cleaned trace (manual or
            % outlier filters) with a gray translucent band on each X/Y plot.
            badMask = [];
            if hasProcessed
                badMask = isnan(p.X_clean) | isnan(p.Y_clean);
            end

            % X(t)
            cla(obj.AxX);
            hold(obj.AxX, 'on');
            obj.shadeBadFrames(obj.AxX, badMask, t);
            if showRaw
                plot(obj.AxX, t, X * yScale, 'Color', [0.10 0.40 0.80], 'LineWidth', 1.0);
            end
            if showInterp && ~isempty(Xint)
                plot(obj.AxX, t, Xint, 'Color', [0.95 0.55 0.10], 'LineWidth', 0.9);
            end
            if showSmooth && ~isempty(Xsm)
                plot(obj.AxX, t, Xsm, 'Color', [0.10 0.65 0.20], 'LineWidth', 0.9);
            end
            hold(obj.AxX, 'off');
            title(obj.AxX, sprintf('%s — X', partName), 'Interpreter', 'none');
            xlabel(obj.AxX, xLabel); ylabel(obj.AxX, yUnitX);
            if sameView
                obj.AxX.XLim = xlimX; obj.AxX.YLim = ylimX;
            else
                xlim(obj.AxX, [fromF toF] * xScale);
            end
            grid(obj.AxX, 'on');

            % Y(t)
            cla(obj.AxY);
            hold(obj.AxY, 'on');
            obj.shadeBadFrames(obj.AxY, badMask, t);
            if showRaw
                plot(obj.AxY, t, Y * yScale, 'Color', [0.10 0.40 0.80], 'LineWidth', 1.0);
            end
            if showInterp && ~isempty(Yint)
                plot(obj.AxY, t, Yint, 'Color', [0.95 0.55 0.10], 'LineWidth', 0.9);
            end
            if showSmooth && ~isempty(Ysm)
                plot(obj.AxY, t, Ysm, 'Color', [0.10 0.65 0.20], 'LineWidth', 0.9);
            end
            hold(obj.AxY, 'off');
            title(obj.AxY, sprintf('%s — Y', partName), 'Interpreter', 'none');
            xlabel(obj.AxY, xLabel); ylabel(obj.AxY, yUnitY);
            if sameView
                obj.AxY.XLim = xlimY; obj.AxY.YLim = ylimY;
            else
                xlim(obj.AxY, [fromF toF] * xScale);
            end
            grid(obj.AxY, 'on');

            obj.State.lastDrawnBodyPart = i;
            obj.State.lastDrawnUnits = xUnits;
            obj.State.lastDrawnYUnit = (yScale ~= 1);

            % Likelihood histogram — fine bins (0.01 wide) for thresholding
            cla(obj.AxLk);
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
            % Threshold marker (red vertical line) for the current part
            if i <= numel(obj.State.perPart)
                thr = obj.State.perPart(i).likelihoodThreshold;
                hold(obj.AxLk, 'on');
                yLim = obj.AxLk.YLim;
                plot(obj.AxLk, [thr thr], yLim, '-', ...
                    'Color', [0.85 0.10 0.10], 'LineWidth', 2.5);
                hold(obj.AxLk, 'off');
            end

            % Round-5 #12: X axis must show full integers, never 2*10^4 form.
            try
                obj.AxX.XAxis.Exponent = 0;
                obj.AxY.XAxis.Exponent = 0;
                obj.AxX.XAxis.TickLabelFormat = '%g';
                obj.AxY.XAxis.TickLabelFormat = '%g';
            catch
                % uiaxes XAxis may not expose Exponent in some R2020 builds
            end

            % FrameLabel hidden in round-5 (frame info in video window only).
            if ~isempty(obj.FrameLabel) && isvalid(obj.FrameLabel)
                obj.FrameLabel.Text = sprintf('Frame %d / %d', obj.State.currentFrame, n);
            end
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
            s.lastDrawnBodyPart = [];   % for zoom-preservation across recompute
            s.lastDrawnUnits = 'sec';
            s.lastDrawnYUnit = false;   % false=px, true=cm
            % Outlier filter defaults (global per experiment, not per-part)
            s.outlier.velocityJump.enabled = true;
            s.outlier.velocityJump.maxVelocityCmS = 50;
            s.outlier.hampel.enabled = false;
            s.outlier.hampel.windowSec = 0.25;   % new — preferred unit
            s.outlier.hampel.windowSize = 7;     % legacy fallback (samples)
            s.outlier.hampel.nSigma = 3;
            s.outlier.kalman.processNoise = 1e-2;
            s.outlier.kalman.measNoiseScale = 1.0;
            % Manual exclusion regions (each region has its own scope:
            % 'experiment' (default) = applies on every session;
            % 'session' = stays only in this session's _Preprocessed.mat).
            s.manualRegions = struct('vertices', {}, 'appliesTo', {}, 'scope', {});
            % Per-part settings (1xK struct, populated on Load)
            s.perPart = sphynx.app.PreprocessTabController.emptyPerPartArray();
            % Per-part processed traces (1xK struct, populated on Compute)
            s.processed = struct('X_clean', {}, 'Y_clean', {}, ...
                'X_interp', {}, 'Y_interp', {}, ...
                'X_smooth', {}, 'Y_smooth', {}, ...
                'percentNaN', {}, 'percentLowLikelihood', {}, ...
                'percentBadCombined', {}, 'percentOutliers', {}, ...
                'percentManual', {}, 'status', {});
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
            % Round-5 layout:
            %   row 1: TopBar (Output dir + Save + Clear All)
            %   row 2: Blocks 1+2+3 stacked in 380px left column | Plots full
            %          width on the right (X(t) + Y(t) + tall histogram)
            %   row 3: Bottom bar (viewport / switcher / regions / log)
            % Block heights: 1 = ~130 (3 input rows + Load), 2 = ~140
            % (4 rows incl. INFO+velocity-jump on the same line),
            % 3 = ~270 (= B1 + B2 per user request).
            obj.OuterGrid = uigridlayout(obj.Tab, [3, 2]);
            obj.OuterGrid.RowHeight = {36, 540, '1x'};
            obj.OuterGrid.ColumnWidth = {380, '1x'};
            obj.OuterGrid.Padding = [4 4 4 4];
            obj.OuterGrid.RowSpacing = 4;
            obj.OuterGrid.ColumnSpacing = 6;

            obj.buildTopBar();          % row 1, cols [1 2]
            obj.buildBlocksLeftCol();   % row 2 col 1 (Block1 + Block2 + Block3)
            obj.buildPerPartPanel();    % parented to LeftPanel as row 3
            obj.buildPlots();           % row 2 col 2 (X+Y stacked, hist column)
            obj.buildBottomBar();       % row 3, cols [1 2]
        end

        function buildTopBar(obj)
            tb = uigridlayout(obj.OuterGrid, [1, 5]);
            tb.Layout.Row = 1; tb.Layout.Column = [1 2];
            tb.RowHeight = {30};
            tb.ColumnWidth = {80, '1x', 60, 130, 90};
            tb.Padding = [0 0 0 0];
            tb.ColumnSpacing = 4;

            btnOut = uibutton(tb, 'Text', 'Output dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickOutputDir());
            btnOut.Layout.Column = 1;
            obj.OutputDirField = uieditfield(tb, 'text', 'Value', '');
            obj.OutputDirField.Layout.Column = 2;
            obj.SavePlotsCheckbox = uicheckbox(tb, 'Text', 'plots', ...
                'Tooltip', 'save per-part PNG plots when saving', 'Value', true);
            obj.SavePlotsCheckbox.Layout.Column = 3;
            bSave = uibutton(tb, 'Text', 'Save preprocessed', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.savePreprocessed());
            bSave.Layout.Column = 4;
            bClearAll = uibutton(tb, 'Text', 'Clear All', ...
                'BackgroundColor', [0.92 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'Tooltip', 'Wipe DLC, settings, regions; keep paths', ...
                'ButtonPushedFcn', @(~,~) obj.clearAll());
            bClearAll.Layout.Column = 5;
        end

        function buildBlocksLeftCol(obj)
            % Round-5: stack Block 1 + Block 2 + Block 3 vertically in
            % the 380px left column. Heights add up exactly: B1=130,
            % B2=140 (so they only take what their content needs),
            % B3 = '1x' = remaining = 270 (= B1 + B2 per user request).
            obj.LeftPanel = uigridlayout(obj.OuterGrid, [3, 1]);
            obj.LeftPanel.Layout.Row = 2; obj.LeftPanel.Layout.Column = 1;
            obj.LeftPanel.RowHeight = {130, 140, '1x'};
            obj.LeftPanel.RowSpacing = 4;
            obj.LeftPanel.Padding = [0 0 0 0];

            obj.buildLoadingPanel();   % parent = LeftPanel, Row 1
            obj.buildOutlierPanel();   % parent = LeftPanel, Row 2
            % buildPerPartPanel called separately from buildUI; it parents
            % to LeftPanel via Layout.Row = 3.
        end

        function buildPlots(obj)
            % Round-5: row 2 col 2. X(t) + Y(t) stacked, histogram on the
            % right (twice as wide as before — 440 vs 220).
            plotsGrid = uigridlayout(obj.OuterGrid, [2, 2]);
            plotsGrid.Layout.Row = 2; plotsGrid.Layout.Column = 2;
            plotsGrid.RowHeight = {'1x', '1x'};
            plotsGrid.ColumnWidth = {'1x', 440};
            plotsGrid.RowSpacing = 4;
            plotsGrid.ColumnSpacing = 6;
            plotsGrid.Padding = [0 0 0 0];

            obj.AxX = uiaxes(plotsGrid);
            obj.AxX.Layout.Row = 1; obj.AxX.Layout.Column = 1;
            obj.AxX.Box = 'on';

            obj.AxY = uiaxes(plotsGrid);
            obj.AxY.Layout.Row = 2; obj.AxY.Layout.Column = 1;
            obj.AxY.Box = 'on';

            % Histogram spans both rows on the right
            obj.AxLk = uiaxes(plotsGrid);
            obj.AxLk.Layout.Row = [1 2]; obj.AxLk.Layout.Column = 2;
            obj.AxLk.Box = 'on';
        end

        function buildBottomBar(obj)
            % Round-5 row 3: viewport (with bodyparts switcher merged in) +
            % regions + log. FrameLabel removed (frame info shows in video).
            bb = uigridlayout(obj.OuterGrid, [3, 1]);
            bb.Layout.Row = 3; bb.Layout.Column = [1 2];
            bb.RowHeight = {32, 100, '1x'};
            bb.RowSpacing = 4;
            bb.Padding = [0 0 0 0];

            obj.buildViewportRow(bb);   % row 1 — merged viewport+switcher
            obj.buildRegionsPanelInline(bb); % row 2
            obj.buildLogInline(bb);     % row 3
            % buildSwitcherRow no longer used — merged into viewport.

            obj.RightGrid = bb;   % alias for backward compat
        end

        function buildLoadingPanel(obj)
            p = uipanel(obj.LeftPanel, 'Title', '1. Loading');
            p.Layout.Row = 1;
            g = uigridlayout(p, [3, 4]);
            g.RowHeight = {26, 26, 32};
            g.ColumnWidth = {'1x', '1x', '1x', '1x'};
            g.ColumnSpacing = 4;
            g.RowSpacing = 4;
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

            % Middle row text fields
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

            % Bottom row: full-width Load button + Load synthetic button
            btnLoad = uibutton(g, 'Text', 'Load', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadAll());
            btnLoad.Layout.Row = 3; btnLoad.Layout.Column = [1 3];

            btnSynth = uibutton(g, 'Text', 'Load synthetic', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.loadSynthetic());
            btnSynth.Layout.Row = 3; btnSynth.Layout.Column = 4;

            % Try to inherit project root from sibling Preset tab
            obj.inheritRootFromParentApp();
        end

        function buildPerPartPanel(obj)
            obj.PerPartPanel = uipanel(obj.LeftPanel, 'Title', '3. Per-part settings');
            obj.PerPartPanel.Layout.Row = 3;
            g = uigridlayout(obj.PerPartPanel, [4, 1]);
            g.RowHeight = {24, '1x', 32, 32};
            g.RowSpacing = 4;
            g.Padding = [4 4 4 4];

            % INFO row
            infoRow = uigridlayout(g, [1, 2]);
            infoRow.Layout.Row = 1;
            infoRow.RowHeight = {22};
            infoRow.ColumnWidth = {'1x', 60};
            infoRow.Padding = [0 0 0 0];
            infoRow.ColumnSpacing = 0;
            uilabel(infoRow, 'Text', '');
            bInfo = uibutton(infoRow, 'Text', 'INFO', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.showHelpDialog('perpart'));
            bInfo.Layout.Column = 2;

            % uitable with per-part settings
            obj.PerPartTable = uitable(g, ...
                'ColumnName', {'use', 'name', 'thr', 'win,s', 'interp', 'smooth', 'NF%', '%NaN', '%lowL', '%out', '%manual', 'status'}, ...
                'ColumnFormat', {'logical', 'char', 'numeric', 'numeric', ...
                    {'pchip', 'linear', 'spline', 'makima'}, ...
                    {'sgolay', 'movmean', 'movmedian', 'gaussian', 'kalman'}, ...
                    'numeric', 'char', 'char', 'char', 'char', 'char'}, ...
                'ColumnEditable', [true false true true true true true false false false false false], ...
                'ColumnWidth', {38, 90, 44, 50, 60, 70, 40, 50, 50, 50, 55, 60}, ...
                'RowName', {}, ...
                'CellEditCallback', @(~, evt) obj.onPerPartTableEdited(evt), ...
                'CellSelectionCallback', @(~, evt) obj.onPerPartTableSelected(evt));
            obj.PerPartTable.Layout.Row = 2; obj.PerPartTable.Layout.Column = 1;

            % Default/Compute row
            btnRow = uigridlayout(g, [1, 4]);
            btnRow.Layout.Row = 3; btnRow.Layout.Column = 1;
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
            % Compute all is the primary action — brighter rose, bold
            b4 = uibutton(btnRow, 'Text', 'Compute all', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.computeAll());
            b4.Layout.Column = 4;

            % Auto-threshold row
            autoRow = uigridlayout(g, [1, 5]);
            autoRow.Layout.Row = 4; autoRow.Layout.Column = 1;
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
            % Auto all — primary action, brighter
            bA2 = uibutton(autoRow, 'Text', 'Auto all', ...
                'BackgroundColor', [0.55 0.85 1.00], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.autoThresholdAll());
            bA2.Layout.Column = 5;
        end

        function buildOutlierPanel(obj)
            obj.OutlierPanel = uipanel(obj.LeftPanel, 'Title', '2. Outlier filter');
            obj.OutlierPanel.Layout.Row = 2;
            % Round-5: 3 rows total (no separate INFO row); INFO sits on
            % row 1 next to velocity-jump.
            g = uigridlayout(obj.OutlierPanel, [3, 5]);
            g.RowHeight = {26, 26, 26};
            g.ColumnWidth = {110, 60, 60, '1x', 50};
            g.RowSpacing = 4;
            g.ColumnSpacing = 4;
            g.Padding = [4 4 4 4];

            % Row 1: velocity-jump | label | val | (flex) | INFO
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
            bInfo = uibutton(g, 'Text', 'INFO', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.showHelpDialog('outlier'));
            bInfo.Layout.Row = 1; bInfo.Layout.Column = 5;

            % Row 2: Hampel | win,s | val | sigma val | (flex)
            obj.HampelEnabledChk = uicheckbox(g, 'Text', 'Hampel', ...
                'Value', obj.State.outlier.hampel.enabled, ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('hp_enabled', s.Value));
            obj.HampelEnabledChk.Layout.Row = 2; obj.HampelEnabledChk.Layout.Column = 1;
            lbl2 = uilabel(g, 'Text', 'win,s:', 'HorizontalAlignment', 'right');
            lbl2.Layout.Row = 2; lbl2.Layout.Column = 2;
            obj.HampelWindowField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.hampel.windowSec, ...
                'Limits', [0.01 60], ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('hp_win_sec', s.Value));
            obj.HampelWindowField.Layout.Row = 2; obj.HampelWindowField.Layout.Column = 3;
            obj.HampelSigmaField = uieditfield(g, 'numeric', ...
                'Value', obj.State.outlier.hampel.nSigma, ...
                'Limits', [0.1 10], 'Tooltip', 'k (sigma)', ...
                'ValueChangedFcn', @(s, ~) obj.onOutlierFlagChanged('hp_sig', s.Value));
            obj.HampelSigmaField.Layout.Row = 2; obj.HampelSigmaField.Layout.Column = 5;

            % Row 3: Kalman: Q | val | scale val
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
            obj.KalmanRField.Layout.Row = 3; obj.KalmanRField.Layout.Column = 5;
        end

        function onOutlierFlagChanged(obj, key, val)
            switch key
                case 'vj_enabled'; obj.State.outlier.velocityJump.enabled = logical(val);
                case 'vj_max';     obj.State.outlier.velocityJump.maxVelocityCmS = val;
                case 'hp_enabled'; obj.State.outlier.hampel.enabled = logical(val);
                case 'hp_win';     obj.State.outlier.hampel.windowSize = max(1, round(val));
                case 'hp_win_sec'; obj.State.outlier.hampel.windowSec = max(0.01, val);
                case 'hp_sig';     obj.State.outlier.hampel.nSigma = val;
                case 'kf_q';       obj.State.outlier.kalman.processNoise = val;
                case 'kf_r';       obj.State.outlier.kalman.measNoiseScale = val;
            end
        end

        function buildViewportRow(obj, parent)
            % Round-5: merged switcher into the viewport row.
            % Layout: [<] [bodyparts dropdown] [>] [Video] | from / to /
            % X units / [raw] [interp] [smoothed] | (flex) | [log Y]
            viewport = uigridlayout(parent, [1, 13]);
            viewport.Layout.Row = 1;
            viewport.RowHeight = {28};
            viewport.ColumnWidth = {28, 160, 28, 70, ...
                                    50, 60, 30, 60, 50, 70, ...
                                    60, 70, 60};
            viewport.Padding = [0 0 0 0];
            viewport.ColumnSpacing = 4;

            % Bodyparts switcher (cols 1-3) + Video toggle (col 4)
            obj.PrevButton = uibutton(viewport, 'Text', '<', ...
                'BackgroundColor', semanticColor('geometry'), ...
                'ButtonPushedFcn', @(~,~) obj.prevBodyPart());
            obj.PrevButton.Layout.Column = 1;
            obj.BodyPartDropDown = uidropdown(viewport, 'Items', {'(no DLC loaded)'}, ...
                'Value', '(no DLC loaded)', ...
                'ValueChangedFcn', @(s,~) obj.onDropDownChanged(s.Value));
            obj.BodyPartDropDown.Layout.Column = 2;
            obj.NextButton = uibutton(viewport, 'Text', '>', ...
                'BackgroundColor', semanticColor('geometry'), ...
                'ButtonPushedFcn', @(~,~) obj.nextBodyPart());
            obj.NextButton.Layout.Column = 3;
            obj.ShowVideoButton = uibutton(viewport, 'state', 'Text', 'Video', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(s, ~) obj.toggleVideoPanel(s.Value));
            obj.ShowVideoButton.Layout.Column = 4;

            % Viewport edits with debounce (500ms)
            uilabel(viewport, 'Text', 'from:', 'HorizontalAlignment', 'right');
            obj.FromFrameField = uieditfield(viewport, 'numeric', ...
                'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~,~) obj.scheduleRefresh());
            uilabel(viewport, 'Text', 'to:', 'HorizontalAlignment', 'right');
            obj.ToFrameField = uieditfield(viewport, 'numeric', ...
                'Value', 0, 'Limits', [0 Inf], 'RoundFractionalValues', 'on', ...
                'Tooltip', '0 = last frame', ...
                'ValueChangedFcn', @(~,~) obj.scheduleRefresh());
            uilabel(viewport, 'Text', 'X:', 'HorizontalAlignment', 'right');
            obj.XUnitsDropDown = uidropdown(viewport, ...
                'Items', {'frame', 'sec', 'min'}, 'Value', 'sec', ...
                'ValueChangedFcn', @(~,~) obj.scheduleRefresh());

            % Curve overlays
            obj.ShowRawChk = uicheckbox(viewport, 'Text', 'raw', 'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.scheduleRefresh());
            obj.ShowInterpChk = uicheckbox(viewport, 'Text', 'interp', 'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.scheduleRefresh());
            obj.ShowSmoothChk = uicheckbox(viewport, 'Text', 'smoothed', 'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.scheduleRefresh());

            % log Y at the right edge (under the histogram)
            obj.LogScaleButton = uibutton(viewport, 'state', 'Text', 'log Y', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.LogScaleButton.Layout.Column = 13;

            % FrameLabel removed in round-5 — frame info lives in video window.
            obj.FrameLabel = uilabel(viewport, 'Text', '', 'Visible', 'off');
        end

        function buildSwitcherRow(obj, parent)
            switcher = uigridlayout(parent, [1, 6]);
            switcher.Layout.Row = 2;
            switcher.RowHeight = {28};
            switcher.ColumnWidth = {28, 200, 28, 80, 80, '1x'};
            switcher.Padding = [0 0 0 0];
            switcher.ColumnSpacing = 4;

            obj.PrevButton = uibutton(switcher, 'Text', '<', ...
                'BackgroundColor', semanticColor('geometry'), ...
                'ButtonPushedFcn', @(~,~) obj.prevBodyPart());
            obj.BodyPartDropDown = uidropdown(switcher, 'Items', {'(no DLC loaded)'}, ...
                'Value', '(no DLC loaded)', ...
                'ValueChangedFcn', @(s,~) obj.onDropDownChanged(s.Value));
            obj.NextButton = uibutton(switcher, 'Text', '>', ...
                'BackgroundColor', semanticColor('geometry'), ...
                'ButtonPushedFcn', @(~,~) obj.nextBodyPart());
            obj.LogScaleButton = uibutton(switcher, 'state', 'Text', 'log Y', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.ShowVideoButton = uibutton(switcher, 'state', 'Text', 'Video', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(s, ~) obj.toggleVideoPanel(s.Value));
            obj.FrameLabel = uilabel(switcher, 'Text', 'Frame -/-', ...
                'HorizontalAlignment', 'right');
        end

        function buildRegionsPanelInline(obj, parent)
            obj.RegionsPanel = uipanel(parent, 'Title', 'Manual exclusion regions');
            obj.RegionsPanel.Layout.Row = 3;
            rg = uigridlayout(obj.RegionsPanel, [2, 6]);
            rg.RowHeight = {28, '1x'};
            rg.ColumnWidth = {110, 130, 100, 70, 70, '1x'};
            rg.Padding = [4 4 4 4];
            rg.RowSpacing = 4;
            rg.ColumnSpacing = 4;

            uibutton(rg, 'Text', 'Add region', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.addManualRegion());
            obj.RegionsAppliesDropDown = uidropdown(rg, ...
                'Items', {'all'}, 'Value', 'all');
            obj.RegionsScopeDropDown = uidropdown(rg, ...
                'Items', {'experiment', 'session'}, 'Value', 'experiment');
            uibutton(rg, 'Text', 'Delete', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelectedRegion());
            uibutton(rg, 'Text', 'Clear', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.clearAllRegions());
            uilabel(rg, 'Text', '');

            obj.RegionsListBox = uilistbox(rg, 'Items', {});
            obj.RegionsListBox.Layout.Row = 2;
            obj.RegionsListBox.Layout.Column = [1 6];
        end

        function buildLogInline(obj, parent)
            obj.LogTextArea = uitextarea(parent, 'Editable', 'off', ...
                'Value', {''});
            obj.LogTextArea.Layout.Row = 4;
        end

        function buildRight_DEPRECATED(obj)   %#ok<DEFNU>
            % Kept for reference only — replaced by buildPlots/buildBottomBar
            % in the Slice DD layout. NOT called from buildUI anymore.
            obj.RightGrid = uigridlayout(obj.OuterGrid, [8, 1]);
            obj.RightGrid.Layout.Column = 2;
            obj.RightGrid.RowHeight = {'1x', '1x', '1x', 32, 36, 100, 110, 0};
            obj.RightGrid.RowSpacing = 4;
            obj.RightGrid.Padding = [2 2 2 2];

            % Three plot axes
            obj.AxX  = uiaxes(obj.RightGrid);  obj.AxX.Layout.Row  = 1;
            obj.AxY  = uiaxes(obj.RightGrid);  obj.AxY.Layout.Row  = 2;
            obj.AxLk = uiaxes(obj.RightGrid);  obj.AxLk.Layout.Row = 3;
            for ax = [obj.AxX, obj.AxY, obj.AxLk]
                ax.Box = 'on';
            end

            % Viewport controls row: from / to / X units / curve toggles
            viewport = uigridlayout(obj.RightGrid, [1, 9]);
            viewport.Layout.Row = 4;
            viewport.RowHeight = {28};
            viewport.ColumnWidth = {60, 70, 30, 70, 50, 80, 70, 75, 80};
            viewport.Padding = [0 0 0 0];
            viewport.ColumnSpacing = 4;

            lblFrom = uilabel(viewport, 'Text', 'from:', 'HorizontalAlignment', 'right');
            lblFrom.Layout.Column = 1;
            obj.FromFrameField = uieditfield(viewport, 'numeric', ...
                'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.FromFrameField.Layout.Column = 2;
            lblTo = uilabel(viewport, 'Text', 'to:', 'HorizontalAlignment', 'right');
            lblTo.Layout.Column = 3;
            obj.ToFrameField = uieditfield(viewport, 'numeric', ...
                'Value', 0, 'Limits', [0 Inf], 'RoundFractionalValues', 'on', ...
                'Tooltip', '0 = last frame', ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.ToFrameField.Layout.Column = 4;

            lblUnits = uilabel(viewport, 'Text', 'X:', ...
                'HorizontalAlignment', 'right');
            lblUnits.Layout.Column = 5;
            obj.XUnitsDropDown = uidropdown(viewport, ...
                'Items', {'frame', 'sec', 'min'}, 'Value', 'sec', ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.XUnitsDropDown.Layout.Column = 6;

            % Curve overlay toggles
            obj.ShowRawChk = uicheckbox(viewport, 'Text', 'raw', 'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.ShowRawChk.Layout.Column = 7;
            obj.ShowInterpChk = uicheckbox(viewport, 'Text', 'interp', 'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.ShowInterpChk.Layout.Column = 8;
            obj.ShowSmoothChk = uicheckbox(viewport, 'Text', 'smoothed', 'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.ShowSmoothChk.Layout.Column = 9;

            % Bodypart switcher row — Load moved to Block 1, freeing space here.
            switcher = uigridlayout(obj.RightGrid, [1, 6]);
            switcher.Layout.Row = 5;
            switcher.RowHeight = {28};
            switcher.ColumnWidth = {28, 200, 28, 80, 80, '1x'};
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

            obj.LogScaleButton = uibutton(switcher, 'state', 'Text', 'log Y', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());
            obj.LogScaleButton.Layout.Column = 4;

            obj.ShowVideoButton = uibutton(switcher, 'state', 'Text', 'Video', ...
                'BackgroundColor', semanticColor('info'), ...
                'ValueChangedFcn', @(s, ~) obj.toggleVideoPanel(s.Value));
            obj.ShowVideoButton.Layout.Column = 5;

            obj.FrameLabel = uilabel(switcher, 'Text', 'Frame -/-', ...
                'HorizontalAlignment', 'right');
            obj.FrameLabel.Layout.Column = 6;

            % Manual regions panel
            obj.RegionsPanel = uipanel(obj.RightGrid, 'Title', 'Manual exclusion regions');
            obj.RegionsPanel.Layout.Row = 6;
            rg = uigridlayout(obj.RegionsPanel, [2, 6]);
            rg.RowHeight = {28, '1x'};
            rg.ColumnWidth = {110, 130, 100, 70, 70, '1x'};
            rg.Padding = [4 4 4 4];
            rg.RowSpacing = 4;
            rg.ColumnSpacing = 4;

            bAdd = uibutton(rg, 'Text', 'Add region', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.addManualRegion());
            bAdd.Layout.Row = 1; bAdd.Layout.Column = 1;

            obj.RegionsAppliesDropDown = uidropdown(rg, ...
                'Items', {'all'}, 'Value', 'all', ...
                'Tooltip', 'apply this new region to which body part');
            obj.RegionsAppliesDropDown.Layout.Row = 1;
            obj.RegionsAppliesDropDown.Layout.Column = 2;

            obj.RegionsScopeDropDown = uidropdown(rg, ...
                'Items', {'experiment', 'session'}, 'Value', 'experiment', ...
                'Tooltip', 'experiment = applies on every session of this experiment');
            obj.RegionsScopeDropDown.Layout.Row = 1;
            obj.RegionsScopeDropDown.Layout.Column = 3;

            bDel = uibutton(rg, 'Text', 'Delete', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelectedRegion());
            bDel.Layout.Row = 1; bDel.Layout.Column = 4;

            bClear = uibutton(rg, 'Text', 'Clear', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.clearAllRegions());
            bClear.Layout.Row = 1; bClear.Layout.Column = 5;

            obj.RegionsListBox = uilistbox(rg, 'Items', {});
            obj.RegionsListBox.Layout.Row = 2;
            obj.RegionsListBox.Layout.Column = [1 6];

            % Log
            obj.LogTextArea = uitextarea(obj.RightGrid, 'Editable', 'off', ...
                'Value', {''});
            obj.LogTextArea.Layout.Row = 7;

            % Embedded video panel (hidden by default; toggled by Show video)
            obj.VideoPanel = uipanel(obj.RightGrid, 'Title', 'Video');
            obj.VideoPanel.Layout.Row = 8;
            vg = uigridlayout(obj.VideoPanel, [2, 7]);
            vg.RowHeight = {'1x', 30};
            vg.ColumnWidth = {30, 30, '1x', 30, 30, 70, 50};
            vg.Padding = [4 4 4 4];
            vg.RowSpacing = 4;
            vg.ColumnSpacing = 4;

            obj.VideoAxes = uiaxes(vg);
            obj.VideoAxes.Layout.Row = 1;
            obj.VideoAxes.Layout.Column = [1 7];
            obj.VideoAxes.XTick = []; obj.VideoAxes.YTick = [];
            obj.VideoAxes.Box = 'on';

            bL2 = uibutton(vg, 'Text', '<<', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.State.currentFrame - 10));
            bL2.Layout.Row = 2; bL2.Layout.Column = 1;

            bL1 = uibutton(vg, 'Text', '<', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.State.currentFrame - 1));
            bL1.Layout.Row = 2; bL1.Layout.Column = 2;

            obj.VideoSlider = uislider(vg, 'Limits', [1 2], 'Value', 1, ...
                'ValueChangedFcn', @(s, ~) obj.setCurrentFrame(round(s.Value)));
            obj.VideoSlider.Layout.Row = 2; obj.VideoSlider.Layout.Column = 3;

            bR1 = uibutton(vg, 'Text', '>', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.State.currentFrame + 1));
            bR1.Layout.Row = 2; bR1.Layout.Column = 4;

            bR2 = uibutton(vg, 'Text', '>>', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.State.currentFrame + 10));
            bR2.Layout.Row = 2; bR2.Layout.Column = 5;

            obj.GoToFrameField = uieditfield(vg, 'numeric', ...
                'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
            obj.GoToFrameField.Layout.Row = 2; obj.GoToFrameField.Layout.Column = 6;

            bGo = uibutton(vg, 'Text', 'Go', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.GoToFrameField.Value));
            bGo.Layout.Row = 2; bGo.Layout.Column = 7;
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
            % Reset processed cache (field order must match emptyState +
            % storeProcessed placeholder + applyPerPartSettings out)
            obj.State.processed = struct('X_clean', {}, 'Y_clean', {}, ...
                'X_interp', {}, 'Y_interp', {}, ...
                'X_smooth', {}, 'Y_smooth', {}, ...
                'percentNaN', {}, 'percentLowLikelihood', {}, ...
                'percentBadCombined', {}, 'percentOutliers', {}, ...
                'percentManual', {}, 'status', {});
        end

        function refreshPerPartTable(obj)
            if isempty(obj.PerPartTable) || ~isvalid(obj.PerPartTable); return; end
            arr = obj.State.perPart;
            n = numel(arr);
            if n == 0
                obj.PerPartTable.Data = {};
                return;
            end
            data = cell(n, 12);
            for k = 1:n
                if k <= numel(obj.State.processed) && ~isempty(obj.State.processed(k).status)
                    pct = obj.State.processed(k);
                    pNaN = sprintf('%.1f', pct.percentNaN);
                    pLow = sprintf('%.1f', pct.percentLowLikelihood);
                    pOut = sprintf('%.1f', pct.percentOutliers);
                    if isfield(pct, 'percentManual')
                        pMan = sprintf('%.1f', pct.percentManual);
                    else
                        pMan = '0.0';
                    end
                    status = pct.status;
                else
                    pNaN = '-'; pLow = '-'; pOut = '-'; pMan = '-'; status = '-';
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
                data{k, 10} = pOut;
                data{k, 11} = pMan;
                data{k, 12} = status;
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
            % Live recompute the affected row (cheap; ~0.1s on 18k frames).
            % The 'use' toggle just enables/disables — no recompute needed.
            if col ~= 1 && obj.State.perPart(row).use
                obj.computePart(row);
            end
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

        % --- Manual exclusion regions ----------------------------------------
        function addManualRegion(obj)
            if isempty(obj.State.frame)
                obj.applog('warn', 'Add region needs a frame — load a Preset with GoodVideoFrame first');
                return;
            end
            applies = obj.RegionsAppliesDropDown.Value;
            scope = 'experiment';
            if ~isempty(obj.RegionsScopeDropDown)
                scope = obj.RegionsScopeDropDown.Value;
            end
            % Open a temporary figure to draw the polygon.
            fig = figure('Name', sprintf('Draw exclusion region (applies to: %s, scope: %s)', applies, scope), ...
                'NumberTitle', 'off');
            cleaner = onCleanup(@() safeClose(fig));
            ax = axes(fig); %#ok<LAXES>
            imshow(obj.State.frame, 'Parent', ax);
            title(ax, sprintf('Click to add vertices, double-click to finish'), ...
                'Interpreter', 'none');
            % Render existing experiment-scope regions semi-transparent so
            % the user notices alignment problems.
            obj.drawExistingRegionsOn(ax);
            try
                h = drawpolygon(ax);
            catch ME
                obj.applog('error', 'drawpolygon failed: %s', ME.message);
                return;
            end
            wait(h);  % blocks until the user double-clicks
            if ~isvalid(h); return; end
            verts = h.Position;
            if isempty(verts) || size(verts, 1) < 3
                obj.applog('warn', 'Region needs >= 3 vertices');
                return;
            end
            % Build the struct with all fields the array expects (avoid
            % heterogeneousStrucAssignment by matching field order).
            reg = struct('vertices', verts, 'appliesTo', applies, 'scope', scope);
            obj.State.manualRegions(end+1) = reg;
            obj.refreshRegionsListBox();
            obj.refocus();
            obj.applog('info', 'Added region #%d (applies: %s, scope: %s, %d vertices)', ...
                numel(obj.State.manualRegions), applies, scope, size(verts, 1));
            obj.refreshPreview();   % so the new region's frame highlights show up
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                uialert(obj.Figure, ...
                    sprintf('Region added (%d vertices, applies: %s, scope: %s).', ...
                    size(verts, 1), applies, scope), ...
                    'Region added', 'Icon', 'success');
            end
        end

        function drawExistingRegionsOn(obj, ax)
            % Overlay existing 'experiment'-scope regions semi-transparent
            % so the user can see if their geometry doesn't line up with
            % the current camera view.
            hold(ax, 'on');
            for k = 1:numel(obj.State.manualRegions)
                r = obj.State.manualRegions(k);
                if isfield(r, 'scope') && ~strcmp(r.scope, 'experiment'); continue; end
                v = r.vertices;
                if isempty(v); continue; end
                fill(ax, v(:, 1), v(:, 2), [0.85 0.10 0.10], ...
                    'FaceAlpha', 0.20, 'EdgeColor', [0.85 0.10 0.10], ...
                    'EdgeAlpha', 0.7, 'LineWidth', 1);
            end
            hold(ax, 'off');
        end

        function deleteSelectedRegion(obj)
            if isempty(obj.RegionsListBox); return; end
            idx = find(strcmp(obj.RegionsListBox.Items, obj.RegionsListBox.Value), 1);
            if isempty(idx); return; end
            obj.State.manualRegions(idx) = [];
            obj.refreshRegionsListBox();
            obj.applog('info', 'Deleted region #%d', idx);
        end

        function clearAllRegions(obj)
            if isempty(obj.State.manualRegions); return; end
            obj.State.manualRegions = struct('vertices', {}, 'appliesTo', {});
            obj.refreshRegionsListBox();
            obj.applog('info', 'Cleared all regions');
        end

        function refreshRegionsListBox(obj)
            if isempty(obj.RegionsListBox); return; end
            n = numel(obj.State.manualRegions);
            if n == 0
                obj.RegionsListBox.Items = {};
                return;
            end
            items = cell(1, n);
            for k = 1:n
                r = obj.State.manualRegions(k);
                if isfield(r, 'scope'); sc = r.scope; else; sc = 'experiment'; end
                items{k} = sprintf('region %d (applies: %s, scope: %s, %d vertices)', ...
                    k, r.appliesTo, sc, size(r.vertices, 1));
            end
            obj.RegionsListBox.Items = items;
        end

        function openVideoReader(obj)
            % Lazy: open VideoReader only when the user toggles Video on.
            if ~isempty(obj.VideoReader_); return; end  % already open
            vp = obj.State.paths.video;
            if isempty(vp) || ~isfile(vp)
                obj.applog('warn', 'Video path empty or not found — frame display disabled');
                return;
            end
            try
                obj.VideoReader_ = VideoReader(vp);
                obj.applog('info', 'Opened video: %s (%d frames @ %.2f fps)', ...
                    vp, obj.VideoReader_.NumFrames, obj.VideoReader_.FrameRate);
            catch ME
                obj.applog('error', 'VideoReader failed: %s', ME.message);
                obj.VideoReader_ = [];
            end
        end

        function refreshVideoFrame(obj)
            if isempty(obj.VideoAxes) || ~isvalid(obj.VideoAxes); return; end
            if isempty(obj.ShowVideoButton) || ~obj.ShowVideoButton.Value; return; end
            if isempty(obj.VideoReader_); return; end
            f = obj.State.currentFrame;
            try
                img = read(obj.VideoReader_, f);
            catch ME
                obj.applog('warn', 'Failed to read frame %d: %s', f, ME.message);
                return;
            end
            cla(obj.VideoAxes);
            imshow(img, 'Parent', obj.VideoAxes);
            % Overlay the current part's (x, y) — prefer smoothed if computed
            i = obj.State.currentBodyPart;
            if i <= numel(obj.State.processed) && ~isempty(obj.State.processed(i).X_smooth)
                xy = [obj.State.processed(i).X_smooth(f), obj.State.processed(i).Y_smooth(f)];
            elseif ~isempty(obj.State.dlc)
                xy = [obj.State.dlc.X(i, f), obj.State.dlc.Y(i, f)];
            else
                xy = [];
            end
            if ~isempty(xy) && all(isfinite(xy))
                hold(obj.VideoAxes, 'on');
                plot(obj.VideoAxes, xy(1), xy(2), 'r+', ...
                    'MarkerSize', 14, 'LineWidth', 2);
                hold(obj.VideoAxes, 'off');
            end
            title(obj.VideoAxes, sprintf('Frame %d', f));
        end

        function refreshPlayheadOnPlots(obj)
            % Draw a vertical playhead line on X(t) and Y(t) at currentFrame.
            % Re-runs refreshPreview to clear old lines, then redraws.
            obj.refreshPreview();
            f = obj.State.currentFrame;
            if isempty(obj.AxX) || isempty(obj.AxY); return; end
            for ax = [obj.AxX, obj.AxY]
                yLim = ax.YLim;
                hold(ax, 'on');
                plot(ax, [f f], yLim, '-', 'Color', [0.85 0.10 0.10], ...
                    'LineWidth', 1);
                hold(ax, 'off');
            end
        end

        function refreshAppliesDropDown(obj)
            if isempty(obj.RegionsAppliesDropDown); return; end
            if isempty(obj.State.dlc)
                obj.RegionsAppliesDropDown.Items = {'all'};
                obj.RegionsAppliesDropDown.Value = 'all';
                return;
            end
            obj.RegionsAppliesDropDown.Items = ...
                [{'all'}, obj.State.dlc.bodyPartsNames];
            obj.RegionsAppliesDropDown.Value = 'all';
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
            % Newest line at the TOP so the latest message is always visible
            % without scrolling. Workaround for R2020a uitextarea (no scroll API).
            current = [{line}; current(:)];
            if numel(current) > 500
                current = current(1:500);
            end
            obj.LogTextArea.Value = current;
        end

        function refocus(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                figure(obj.Figure);
            end
        end

        function shadeBadFrames(~, ax, badMask, tVec)
            % Draw a thin gray semi-transparent band along the X-axis at
            % every frame whose cleaned trace is NaN (likelihood / bounds /
            % outlier filter / manual region all converge here).
            if isempty(badMask) || ~any(badMask); return; end
            yLim = ax.YLim;
            % Compress consecutive bad frames into runs to keep the patch count low
            runs = findRuns(badMask(:)');
            for k = 1:size(runs, 1)
                a = runs(k, 1); b = runs(k, 2);
                if a > numel(tVec) || b > numel(tVec); continue; end
                xa = tVec(a); xb = tVec(b);
                patch(ax, [xa xb xb xa], [yLim(1) yLim(1) yLim(2) yLim(2)], ...
                    [0.6 0.6 0.6], 'FaceAlpha', 0.20, 'EdgeColor', 'none');
            end
        end

        function showHelpDialog(obj, topic)
            switch lower(topic)
                case 'perpart'
                    msg = sprintf([ ...
                        'Per-part settings table (Block 3):\n' ...
                        '\n' ...
                        'Each row = one DLC body part. Editable columns:\n' ...
                        '  use   - include this part in Compute and Save\n' ...
                        '  thr   - likelihood threshold; frames below = bad\n' ...
                        '  win,s - smoothing window in seconds (sgolay/movmean/...)\n' ...
                        '  interp - gap-filling method (pchip / linear / spline / makima)\n' ...
                        '  smooth - sgolay / movmean / movmedian / gaussian / kalman\n' ...
                        '  NF%%  - if more than NF%% of frames are bad, status = NotFound\n' ...
                        '\n' ...
                        'Read-only after Compute:\n' ...
                        '  %%NaN  - share of frames that came back NaN from DLC\n' ...
                        '  %%lowL - share of frames where likelihood < thr\n' ...
                        '  %%out  - share of frames flagged by outlier filters (Block 2)\n' ...
                        '  status - Good or NotFound\n' ...
                        '\n' ...
                        'Buttons:\n' ...
                        '  Default this/all - reset to defaults from defaultConfig\n' ...
                        '  Compute this/all - run the pipeline\n' ...
                        '  Auto this/all    - pick a likelihood threshold from the\n' ...
                        '                     distribution (otsu/knee/quantile/preset)\n' ...
                        '\n' ...
                        'Click a row to switch the preview to that body part.\n' ...
                        'Editing any setting (other than use) triggers live recompute.']);
                case 'outlier'
                    msg = sprintf([ ...
                        'Outlier filter (Block 2):\n' ...
                        '\n' ...
                        'These run INSIDE Compute, between bounds-check and\n' ...
                        'interpolation. They add to %%out for each part.\n' ...
                        '\n' ...
                        'velocity-jump (default ON):\n' ...
                        '  flags frames where between-frame displacement > max cm/s.\n' ...
                        '  Catches single-frame DLC teleports. Requires preset for pxlPerCm.\n' ...
                        '\n' ...
                        'Hampel (default OFF):\n' ...
                        '  median +- k*MAD outlier detector in a sliding window.\n' ...
                        '  Good for short (1-5 frame) spikes that velocity-jump misses.\n' ...
                        '  Does NOT work for long (>20 frame) excursions - those need\n' ...
                        '  Manual exclusion regions instead.\n' ...
                        '\n' ...
                        'Kalman params:\n' ...
                        '  Used only when a body part picks "kalman" in its smooth\n' ...
                        '  column. Hand-rolled 2D constant-velocity smoother;\n' ...
                        '  measurement noise scales as 1/likelihood^2 so low-confidence\n' ...
                        '  frames are heavily discounted.\n' ...
                        '\n' ...
                        'Pipeline order:\n' ...
                        '  likelihood -> bounds -> velocity-jump -> Hampel -> regions\n' ...
                        '  -> interpolate -> smooth (sgolay/.../kalman)']);
                otherwise
                    msg = sprintf('No help for topic: %s', topic);
            end
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                uialert(obj.Figure, msg, 'Help', 'Icon', 'info');
            else
                disp(msg);
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

function fps = pickFrameRate(obj)
    fps = 30;
    if ~isempty(obj.State.presetData) && isfield(obj.State.presetData, 'Options') ...
            && isfield(obj.State.presetData.Options, 'FrameRate')
        fps = obj.State.presetData.Options.FrameRate;
    end
end

function ppc = pickPxlPerCm(obj)
    ppc = [];
    if ~isempty(obj.State.presetData) && isfield(obj.State.presetData, 'Options') ...
            && isfield(obj.State.presetData.Options, 'pxl2sm')
        ppc = obj.State.presetData.Options.pxl2sm;
    end
end

function safeClose(h)
    if ~isempty(h) && isvalid(h)
        close(h);
    end
end

function runs = findRuns(mask)
    % Returns Mx2 [start end] indices of consecutive true runs in mask.
    if isempty(mask); runs = zeros(0, 2); return; end
    mask = logical(mask(:)');
    d = diff([false mask false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    runs = [starts(:), ends(:)];
end

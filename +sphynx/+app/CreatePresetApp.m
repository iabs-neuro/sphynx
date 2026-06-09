classdef CreatePresetApp < handle
% CREATEPRESETAPP  Single-window preset builder for sphynx.
%
%   sphynx.app.CreatePresetApp() opens a uifigure-based three-tab editor:
%     Tab 1: Create Preset (full preset builder)
%     Tab 2: Preprocess Tracking (per-bodypart DLC preprocessing)
%     Tab 3: Analyze Session (placeholder for batch run, Pass E)
%
%   Tab 1 layout: left column of step-panels (Load -> Calibration ->
%   Arena -> Objects -> Zones -> Save+Plot), right column with a
%   large preview axes + NextFrame button.
%
%   Implementation: hand-written `handle` class using uifigure +
%   uitabgroup + uigridlayout. Compute / IO logic lives in
%   +sphynx/+preset/* and +sphynx/+pipeline/*; this file is a thin
%   shell with state management.
%
%   Built for MATLAB R2020a.

    properties
        Figure
        TabGroup
        TabCreate
        TabPreprocess
        TabDefineActs
        TabAnalyze
        TabBatch
        TabMakeOutputTable
        TabPlotData
        TabPreprocessVideo
        TabSynthetic
        PreprocessController       % sphynx.app.PreprocessTabController
        DefineActsController       % sphynx.app.DefineActsTabController
        AnalyzeSessionController   % sphynx.app.AnalyzeSessionTabController
        BatchAnalysisController    % sphynx.app.BatchAnalysisTabController
        MakeOutputTableController  % sphynx.app.MakeOutputTableTabController
        PlotDataController         % sphynx.app.PlotDataTabController
        PreprocessVideoController  % sphynx.app.PreprocessVideoTabController
        SyntheticController        % sphynx.app.SyntheticDataTabController
        % Layout containers
        OuterGrid
        LeftGrid
        RightGrid
        % Panels
        LoadPanel
        CalibPanel
        ArenaPanel
        ObjectsPanel
        ZonesPanel
        SavePanel
        % Load
        ProjectRootField
        VideoPathField
        OutDirField
        PresetPathField
        % Calibration
        DistanceYField
        DistanceXField
        PxlPerCmYLabel
        PxlPerCmXLabel
        PxlPerCmAvgLabel
        XKcorrLabel
        ExpTypeDropDown
        CalibModeDropDown   % '4 points' | '2 lines'
        % Arena
        ArenaGeometryButtons      % cell array of state buttons (Polygon/Circle/Ellipse/O-maze)
        ArenaStatusLabel
        ArenaPickModeDropDown
        % Objects
        ObjectGeometryButtons     % cell array of state buttons (Polygon/Circle/Ellipse)
        ObjectsListBox
        ObjectPickModeDropDown
        ObjectClassField          % text edit for class label (S8)
        CopyNField                % numeric edit for Copy x N count (S2)
        % Zones
        ZonesStrategyDropDown
        WallWidthField
        MiddleWidthField
        CornerTypeDropDown
        NumStripsField
        StripDirDropDown
        CenterDiameterCmField
        ObjectZoneWidthField
        ZonesCountLabel
        % Auto-detect objects (S7)
        AutoModeDropdown
        AutoAlgorithmDropdown
        AutoSensitivitySlider
        AutoMinAreaField
        AutoMaxAreaField
        AutoRadiusMinField
        AutoRadiusMaxField
        AutoStartFromField
        % Save / plot
        PlotAllCheckbox
        % Preview
        PreviewPanel
        PreviewAxes
        FrameIndexLabel
        FramePickerNField
        FramePickerDropdown
        % Move/rotate
        MoveTargetDropDown
        MoveStepField
        % Log
        LogTextArea
        % State
        State
        % Guard flag: true while setSelectedObjectIdx or refreshObjectsList
        % is writing to ObjectsListBox.Value, so onObjectsListBoxChanged
        % short-circuits and avoids a double refreshPreview (C1).
        UpdatingListboxFromState = false
        % Objects manager window (Fix 3)
        ObjectsManagerFig
        ObjectsCountLabel
        % Manager preview axes + pending-pick state
        ManagerAxes
        ManagerStatusLabel
        PendingShapeHandles    % cell array of drawXX handles
        PendingShapeGeometries % cell array of strings: geometry of each pending
        % Auto-detect neighborhood
        AutoNeighborhoodField
        % Live sensitivity value display label (Fix 4)
        AutoSensitivityValueLabel
        % Mirror listbox in Block 4 (Fix 7)
        ObjectsMirrorListBox
        % Draft model: true while manager is open / has uncommitted edits (Fix 5)
        ManagerSessionDirty = false
    end

    methods
        function app = CreatePresetApp(varargin)
            app.State = sphynx.app.CreatePresetApp.emptyState();
            app.buildUI();
            sphynx.util.log('info', '[App] CreatePresetApp opened');
            app.refocus();
        end

        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                close(app.Figure);
            end
            if ~isempty(app.ObjectsManagerFig) && isvalid(app.ObjectsManagerFig)
                close(app.ObjectsManagerFig);
            end
        end

        % --- Programmatic API (stable for tests) ----------------------------
        function setVideo(app, path)
            try
                gframe = sphynx.preset.pickGoodFrame(path, 'FrameIndex', 1);
                app.State.videoPath = path;
                app.State.frame = gframe.frame;
                app.State.frameRate = gframe.frameRate;
                app.State.numFrames = gframe.numFrames;
                app.State.height = gframe.height;
                app.State.width = gframe.width;
                app.State.frameIndex = 1;
                if ~isempty(app.VideoPathField); app.VideoPathField.Value = path; end
                if ~isempty(app.FrameIndexLabel)
                    app.FrameIndexLabel.Text = sprintf('Frame %d / %d', 1, app.State.numFrames);
                end
                if ~isempty(app.FramePickerNField) && isvalid(app.FramePickerNField)
                    app.rebuildFramePickerDropdown();
                end
                app.refreshPreview();
                app.refreshPreviewTitle();
                app.status(sprintf('Loaded video: %dx%d, %d frames @ %.1f fps', ...
                    app.State.width, app.State.height, app.State.numFrames, app.State.frameRate));
            catch ME
                app.status(sprintf('Video load failed: %s', ME.message));
            end
        end

        function setOutDir(app, dir)
            app.State.outDir = dir;
            if ~isempty(app.OutDirField); app.OutDirField.Value = dir; end
            app.status(sprintf('Output dir: %s', dir));
        end

        function setProjectRoot(app, dir)
            app.State.projectRoot = dir;
            if ~isempty(app.ProjectRootField); app.ProjectRootField.Value = dir; end
            app.status(sprintf('Project root: %s', dir));
        end

        function setPixelsPerCm(app, pxlAvg, varargin)
            p = inputParser;
            addParameter(p, 'Y', NaN);
            addParameter(p, 'X', NaN);
            addParameter(p, 'KCorr', 1);
            parse(p, varargin{:});
            app.State.pxlPerCm = pxlAvg;
            app.State.pxlPerCmY = ifNaN(p.Results.Y, pxlAvg);
            app.State.pxlPerCmX = ifNaN(p.Results.X, pxlAvg);
            app.State.x_kcorr = p.Results.KCorr;
            app.refreshCalibLabels();
            sphynx.util.log('info', '[App] pxl/cm: avg=%.3f Y=%.3f X=%.3f kcorr=%.3f', ...
                pxlAvg, app.State.pxlPerCmY, app.State.pxlPerCmX, app.State.x_kcorr);
        end

        function setArena(app, geometry, points)
            try
                arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
                    'Points', points, 'ExistingObjects', app.State.objects);
                app.State.arena = arena;
                app.applog('info', 'Arena: %s OK', geometry);
                app.refreshPreview();
                onZoneStrategyChanged(app);   % object-zone field may change
                app.refreshMoveTargets();
                sphynx.util.log('info', '[App] arena geometry=%s npoints=%d', geometry, size(points,1));
            catch ME
                app.status(sprintf('Arena failed: %s', ME.message));
            end
        end

        function addObject(app, geometry, points)
            try
                obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
                    'Points', points, 'ExistingObjects', app.State.objects, ...
                    'ExistingArena', app.State.arena);
                obj.type = sprintf('object%d', numel(app.State.objects) + 1);
                objCanon = app.canonicalizeObjects(obj);
                existing = app.canonicalizeObjects(app.State.objects);
                if isempty(existing)
                    app.State.objects = objCanon;
                else
                    existing(end+1) = objCanon;
                    app.State.objects = existing;
                end
                app.refreshObjectsList();
                app.refreshPreview();
                onZoneStrategyChanged(app);
                app.refreshMoveTargets();
                sphynx.util.log('info', '[App] object %d added geometry=%s', numel(app.State.objects), geometry);
            catch ME
                app.status(sprintf('Object failed: %s', ME.message));
            end
        end

        function removeSelectedObject(app)
            % I1: remove ALL selected objects in one shot (spec: vector delete).
            idx = app.getSelectedObjectIdx();
            if isempty(idx)
                app.status('No objects selected');
                return;
            end
            n = numel(app.State.objects);
            keep = setdiff(1:n, idx);
            app.State.objects = app.State.objects(keep);
            % Renumber remaining objects to maintain Object1..ObjectN.
            for k = 1:numel(app.State.objects)
                app.State.objects(k).type = sprintf('object%d', k);
            end
            app.setSelectedObjectIdx([]);
            app.refreshObjectsList();
            app.refreshManagerPreview();
            app.refreshPreview();
            onZoneStrategyChanged(app);
            app.refreshMoveTargets();
            sphynx.util.log('info', '[App] removed %d object(s); %d remain', ...
                numel(idx), numel(app.State.objects));
            app.focusManagerIfOpen();
        end

        function replaceSelectedObject(app)
            if isempty(app.State.objects); app.status('No object selected'); return; end
            idx = app.getSelectedObjectIdx(); if isempty(idx); app.status('No object selected'); return; end
            idx = idx(1);
            geometry = app.State.objectGeometry;
            try
                otherIdx = setdiff(1:numel(app.State.objects), idx);
                obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
                    'ExistingObjects', app.State.objects(otherIdx), ...
                    'ExistingArena', app.State.arena);
                obj.type = app.State.objects(idx).type;     % preserve label
                app.State.objects(idx) = obj;
                app.refreshObjectsList();
                app.refreshManagerPreview();
                app.refreshPreview();
                app.refreshMoveTargets();
                sphynx.util.log('info', '[App] replaced %s with new %s', obj.type, geometry);
                app.focusManagerIfOpen();
            catch ME
                app.status(sprintf('Replace failed: %s', ME.message));
            end
        end

        function previewZones(app)
            % Auto-refit all masks first so previewed zones use the
            % current geometry (after any move/rotate). Then build.
            % R12.1: object zones are added regardless of strategy --
            % including 'none' or any case where computeZonesFromUI
            % returns nothing -- so the per-hole zones always show.
            app.refitAllMasks();
            Z = computeZonesFromUI(app);
            if ~isempty(app.State.savedObjects)
                Zobj = sphynx.preset.buildObjectZones(app.State.savedObjects, ...
                    app.State.height, app.State.width, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'ZoneWidthCm', app.ObjectZoneWidthField.Value);
                Z = [Z, Zobj];
            end
            if isempty(Z); return; end
            app.State.previewZones = Z;
            app.refreshPreview();
            app.status(sprintf('Previewing %d zones (%s)', numel(Z), app.ZonesStrategyDropDown.Value));
        end

        function refitAllMasks(app)
            if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
                app.State.arena.mask = imfill(...
                    sphynx.preset.maskFromBorder(app.State.height, app.State.width, ...
                    app.State.arena.border_x, app.State.arena.border_y), 'holes');
            end
            for k = 1:numel(app.State.objects)
                obj = app.State.objects(k);
                obj.mask = imfill(...
                    sphynx.preset.maskFromBorder(app.State.height, app.State.width, ...
                    obj.border_x, obj.border_y), 'holes');
                app.State.objects(k) = obj;
            end
            % Also refit savedObjects masks (draft model: zones use savedObjects).
            for k = 1:numel(app.State.savedObjects)
                obj = app.State.savedObjects(k);
                obj.mask = imfill(...
                    sphynx.preset.maskFromBorder(app.State.height, app.State.width, ...
                    obj.border_x, obj.border_y), 'holes');
                app.State.savedObjects(k) = obj;
            end
        end

        function invalidateZonesOnTransform(app)
            if ~isempty(app.State.zones)
                n = numel(app.State.zones);
                app.State.zones = struct('name',{},'type',{},'maskfilled',{});
                app.State.zoneStrategies = {};
                app.refreshZonesLabel();
                app.applog('warn', 'Cleared %d committed zones (geometry changed); re-Add to set when ready', n);
            end
        end

        function refreshZonesLabel(app)
            if isempty(app.ZonesCountLabel); return; end
            if isempty(app.State.zoneStrategies)
                app.ZonesCountLabel.Text = 'Added: -';
            else
                app.ZonesCountLabel.Text = ['Added: ' strjoin(app.State.zoneStrategies, ' + ')];
            end
        end

        function renameSelectedObject(app)
            if isempty(app.State.objects); app.status('No object selected'); return; end
            idx = app.getSelectedObjectIdx(); if isempty(idx); app.status('No object selected'); return; end
            idx = idx(1);
            oldName = app.State.objects(idx).type;
            answer = inputdlg(sprintf('New name for %s:', oldName), 'Rename object', 1, {oldName});
            if isempty(answer) || isempty(strtrim(answer{1})); return; end
            app.State.objects(idx).type = strtrim(answer{1});
            app.refreshObjectsList();
            app.refreshMoveTargets();
            app.refreshManagerPreview();
            app.refreshPreview();
            app.invalidateZonesOnTransform();
            app.applog('info', 'Renamed %s -> %s', oldName, app.State.objects(idx).type);
            app.focusManagerIfOpen();
        end

        function assignClassToSelected(app)
            % ASSIGNCLASSTOSELECTED  Write ObjectClassField value into the
            % class field of every currently-selected object (S8).
            idx = app.getSelectedObjectIdx();
            if isempty(idx)
                app.status('No objects selected');
                return;
            end
            val = app.ObjectClassField.Value;
            for k = idx(:)'
                app.State.objects(k).class = val;
            end
            app.refreshManagerPreview();
            app.status(sprintf('Assigned class "%s" to %d objects', val, numel(idx)));
            app.focusManagerIfOpen();
        end

        function copyObjectsN(app)
            % COPYOBJECTSN  Duplicate the single selected object N times,
            % ring layout around source centroid + interactive drag + confirm (Fix 4).
            idx = app.getSelectedObjectIdx();
            if numel(idx) ~= 1
                app.status('Copy x N requires exactly 1 object selected');
                return;
            end
            src = app.State.objects(idx);
            n = round(app.CopyNField.Value);
            pxlPerCm = app.State.pxlPerCm;
            if isnan(pxlPerCm) || pxlPerCm <= 0
                app.status('Calibrate pxlPerCm first');
                return;
            end
            % Source object's centroid and bounding-circle radius
            srcCx = mean(src.border_x);
            srcCy = mean(src.border_y);
            srcR  = max(sqrt((src.border_x - srcCx).^2 + (src.border_y - srcCy).^2));
            % Place copies in a ring around the source, radius = max(2.5 * srcR, 15 cm in px)
            ringR = max(2.5 * srcR, 15 * pxlPerCm);

            % Open interactive figure
            fh = figure('Name', sprintf('Copy x %d — drag, then click Confirm', n), ...
                        'NumberTitle', 'off');
            cleaner = onCleanup(@() closeIfValid(fh)); %#ok<NASGU>
            ax = axes(fh);
            imshow(app.State.frame, 'Parent', ax); hold(ax, 'on');
            % Reference overlay: arena (orange line) + existing objects (blue filled)
            if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
                plot(ax, app.State.arena.border_x, app.State.arena.border_y, '-', ...
                    'Color', [0.85 0.55 0.10], 'LineWidth', 2);
            end
            for o = app.State.objects
                if isempty(o.border_x); continue; end
                fill(ax, o.border_x, o.border_y, [0.3 0.5 0.8], ...
                    'FaceAlpha', 0.20, 'EdgeColor', [0.1 0.3 0.6], 'LineWidth', 1);
            end

            % Create N interactive polygons in a ring around source
            handles = cell(1, n);
            for k = 1:n
                a = 2*pi * (k - 1) / n;
                offX = ringR * cos(a);
                offY = ringR * sin(a);
                copyVerts = [src.border_x(:) + offX, src.border_y(:) + offY];
                % Avoid too many points -- subsample if border is dense
                if size(copyVerts, 1) > 60
                    stride = ceil(size(copyVerts, 1) / 60);
                    copyVerts = copyVerts(1:stride:end, :);
                end
                handles{k} = drawpolygon(ax, 'Position', copyVerts, ...
                    'Color', [0 0.6 0]);
            end

            % Confirm/Cancel buttons
            confirmed = false;
            uicontrol(fh, 'Style', 'pushbutton', 'String', 'Confirm', ...
                'Position', [10 10 80 30], 'BackgroundColor', [0.8 1 0.8], ...
                'Callback', @(~,~) onConfirmCopy());
            uicontrol(fh, 'Style', 'pushbutton', 'String', 'Cancel', ...
                'Position', [100 10 80 30], 'BackgroundColor', [1 0.8 0.8], ...
                'Callback', @(~,~) onCancelCopy());

            function onConfirmCopy()
                confirmed = true;
                uiresume(fh);
            end
            function onCancelCopy()
                confirmed = false;
                uiresume(fh);
            end

            uiwait(fh);
            if ~confirmed
                app.status('Copy x N cancelled');
                return;
            end

            % Commit: pull final positions out of each ROI
            newIdx = [];
            for k = 1:n
                h = handles{k};
                if ~isvalid(h); continue; end
                finalPos = h.Position;   % Nx2
                cp = src;
                cp.border_x = finalPos(:, 1);
                cp.border_y = finalPos(:, 2);
                cp.mask = imfill(sphynx.preset.maskFromBorder( ...
                    app.State.height, app.State.width, cp.border_x, cp.border_y), 'holes');
                cp.type = sprintf('object%d', numel(app.State.objects) + 1);
                if isempty(app.State.objects)
                    app.State.objects = cp;
                else
                    app.State.objects(end + 1) = cp;
                end
                newIdx(end + 1) = numel(app.State.objects); %#ok<AGROW>
            end

            app.refreshObjectsList();
            app.refreshMoveTargets();
            app.setSelectedObjectIdx(newIdx);
            app.refreshManagerPreview();
            app.refreshPreview();
            app.status(sprintf('Committed %d copies', numel(newIdx)));
            app.focusManagerIfOpen();
        end

        function addZones(app)
            % Auto-refit masks first so committed zones reflect the
            % current (possibly transformed) geometry.
            % R12.1: object zones are now added even when the strategy
            % returns nothing (e.g. 'none' for a Barnes preset where
            % only the per-hole zones matter).
            app.refitAllMasks();
            Z = computeZonesFromUI(app);
            % Object zones — only if not already committed (dedup).
            % Uses savedObjects (draft model Fix 5).
            if ~isempty(app.State.savedObjects)
                hasObjectZones = false;
                if ~isempty(app.State.zones)
                    hasObjectZones = any(startsWith(string({app.State.zones.name}), 'object'));
                end
                if ~hasObjectZones
                    Zobj = sphynx.preset.buildObjectZones(app.State.savedObjects, ...
                        app.State.height, app.State.width, ...
                        'PixelsPerCm', app.State.pxlPerCm, ...
                        'ZoneWidthCm', app.ObjectZoneWidthField.Value);
                    Z = [Z, Zobj];
                else
                    sphynx.util.log('info', '[App] object zones already committed, not duplicating');
                end
            end
            % Arena corner points (only when arena is Polygon)
            if ~isempty(app.State.arena) && strcmp(app.State.arena.geometry, 'Polygon') ...
                    && ~isempty(app.State.arena.border_separate_x)
                hasCorners = false;
                if ~isempty(app.State.zones)
                    hasCorners = any(startsWith(string({app.State.zones.name}), 'arenacorner'));
                end
                if ~hasCorners
                    Zcorners = arenaCornerZones(app.State.arena);
                    Z = [Z, Zcorners];
                end
            end
            % Object centers (one per object). Uses savedObjects (draft model Fix 5).
            if ~isempty(app.State.savedObjects)
                hasCenters = false;
                if ~isempty(app.State.zones)
                    hasCenters = any(endsWith(string({app.State.zones.name}), '_center'));
                end
                if ~hasCenters
                    Zcenters = objectCenterZones(app.State.savedObjects);
                    Z = [Z, Zcenters];
                end
            end

            if isempty(Z)
                app.status('No zones to add (set Strategy or commit objects in manager first)');
                return;
            end
            if isempty(app.State.zones)
                app.State.zones = Z;
            else
                app.State.zones(end+1:end+numel(Z)) = Z;
            end
            app.State.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
            % Track strategy tag for the "Added: ..." label.
            stratTag = composeStrategyTag(app);
            app.State.zoneStrategies{end+1} = stratTag;
            app.refreshZonesLabel();
            app.refreshPreview();
            app.applog('info', 'Added %d zones (%s); total committed = %d', ...
                numel(Z), stratTag, numel(app.State.zones));
            for k = 1:numel(Z)
                app.applog('info', '       zone[%d] = %s', ...
                    numel(app.State.zones)-numel(Z)+k, Z(k).name);
            end
        end

        function clearZones(app)
            app.State.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.State.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.State.zoneStrategies = {};
            app.refreshZonesLabel();
            app.refreshPreview();
            app.status('Cleared all zones');
        end

        function clearArena(app)
            % CLEARARENA  Drop the arena mask (zones get cleared too because
            % they were built relative to that arena).
            app.State.arena = [];
            app.clearZones();
            app.refreshPreview();
            app.status('Cleared arena');
        end

        function deleteAllObjects(app)
            % DELETEALLOBJECTS  Wipe every object. Zones lose their object
            % zones via the same auto-clear contract.
            app.State.objects = struct('type', {}, 'geometry', {}, ...
                'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
            app.refreshObjectsList();
            app.clearZones();
            app.refreshManagerPreview();
            app.refreshPreview();
            app.status('Deleted all objects');
            app.focusManagerIfOpen();
        end

        function refreshPreviewTitle(app)
            if isempty(app.PreviewPanel) || ~isvalid(app.PreviewPanel); return; end
            if isempty(app.State.videoPath)
                app.PreviewPanel.Title = 'Preview (no video loaded)';
                return;
            end
            [~, base, ext] = fileparts(app.State.videoPath);
            app.PreviewPanel.Title = upper([base ext]);
        end

        function clearAll(app)
            % CLEARALL  Reset arena, objects, zones (paths and calibration
            % stay so the user can re-pick geometry on the same video).
            app.State.arena = [];
            app.State.objects = struct('type', {}, 'geometry', {}, ...
                'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
            app.State.savedObjects = struct('type', {}, 'geometry', {}, ...
                'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
            app.ManagerSessionDirty = false;
            app.State.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.State.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.State.zoneStrategies = {};
            app.refreshObjectsList();
            app.refreshZonesLabel();
            app.refreshPreview();
            app.status('Cleared all geometry (paths and calibration kept)');
        end

        function savePreset(app)
            if isempty(app.State.outDir); app.status('Set output dir'); return; end
            if isempty(app.State.arena); app.status('Define arena first'); return; end
            % Draft model: auto-finish uncommitted manager edits before save.
            if app.ManagerSessionDirty
                app.status('Auto-finishing Objects Manager draft before save');
                app.finishManager();
            end
            try
                Options = app.assembleOptions();
                ArenaAndObjects = app.assembleArenaAndObjects();
                Zones = app.State.zones;
                if isempty(Zones); Zones = struct('name',{},'type',{},'maskfilled',{}); end
                [~, baseName, ~] = fileparts(app.State.videoPath);
                if isempty(baseName); baseName = 'preset'; end
                sessionDir = fullfile(app.State.outDir, baseName);
                if ~isfolder(sessionDir); mkdir(sessionDir); end
                outPath = fullfile(sessionDir, sprintf('%s_Preset.mat', baseName));
                save(outPath, 'Options', 'Zones', 'ArenaAndObjects');
                % Auto-save the combined layout plot next to the preset.
                autoSaveLayoutPlot(app, sessionDir, baseName);
                % If "plot all zones" is checked, save one PNG per zone.
                if ~isempty(app.PlotAllCheckbox) && app.PlotAllCheckbox.Value
                    savePerZonePlots(app, sessionDir, baseName);
                end
                app.status(sprintf('Saved: %s', outPath));
            catch ME
                app.status(sprintf('Save failed: %s', ME.message));
            end
        end

        function makePlot(app)
            if isempty(app.State.frame); app.status('Load video first'); return; end
            if isempty(app.State.outDir); app.status('Set output dir'); return; end
            plotAll = false;
            if ~isempty(app.PlotAllCheckbox); plotAll = app.PlotAllCheckbox.Value; end
            [~, baseName, ~] = fileparts(app.State.videoPath);
            if isempty(baseName); baseName = 'preset'; end
            sessionDir = fullfile(app.State.outDir, baseName);
            if ~isfolder(sessionDir); mkdir(sessionDir); end

            autoSaveLayoutPlot(app, sessionDir, baseName);

            if plotAll && ~isempty(app.State.zones)
                makePlotState = app.State;
                makePlotState.objects = app.State.savedObjects;
                for k = 1:numel(app.State.zones)
                    z = app.State.zones(k);
                    if isfield(z, 'type') && strcmp(z.type, 'point'); continue; end
                    fh2 = figure('Visible', 'off', 'Position', [100 100 800 600]);
                    cleanup2 = onCleanup(@() closeIfValid(fh2));
                    ax2 = axes(fh2);
                    drawState(ax2, makePlotState, false);
                    if (isnumeric(z.maskfilled) || islogical(z.maskfilled))
                        hold(ax2, 'on');
                        drawZoneFilled(ax2, z, [0 0.5 1], 0.35);
                    end
                    title(ax2, sprintf('%s — zone: %s', baseName, z.name), 'Interpreter', 'none');
                    outPath2 = fullfile(sessionDir, sprintf('%s_zone_%s.png', baseName, sanitize(z.name)));
                    exportgraphics(ax2, outPath2);
                    app.applog('info', 'saved plot %s', outPath2);
                    clear cleanup2;
                end
            end
            app.status(sprintf('Plots saved to %s', sessionDir));
        end

        function moveTarget(app, dirVec)
            step = app.MoveStepField.Value;
            target = app.MoveTargetDropDown.Value;
            if strcmp(target, '<selection>')
                idx = app.getSelectedObjectIdx();
                if isempty(idx); return; end
                delta = dirVec * step;
                for k = idx(:)'
                    app.State.objects(k).border_x = app.State.objects(k).border_x + delta(1);
                    app.State.objects(k).border_y = app.State.objects(k).border_y + delta(2);
                end
                app.invalidateZonesOnTransform();
                app.refreshPreview();
                return;
            end
            % existing single-target path
            tIdx = currentTargetIdx(app);
            if isnan(tIdx); return; end
            applyTransformToTarget(app, tIdx, dirVec * step, 0);
            app.invalidateZonesOnTransform();
            app.refreshPreview();
        end

        function rotateTarget(app, sign)
            stepDeg = app.MoveStepField.Value;
            target = app.MoveTargetDropDown.Value;
            if strcmp(target, '<selection>')
                idx = app.getSelectedObjectIdx();
                if isempty(idx); return; end
                % Pool centroid = mean of all selected objects' border points
                allX = []; allY = [];
                for k = idx(:)'
                    allX = [allX; app.State.objects(k).border_x(:)]; %#ok<AGROW>
                    allY = [allY; app.State.objects(k).border_y(:)]; %#ok<AGROW>
                end
                centroid = [mean(allX), mean(allY)];
                angleRad = deg2rad(sign * stepDeg);
                for k = idx(:)'
                    [xR, yR] = sphynx.preset.rotateAroundCentroid( ...
                        app.State.objects(k).border_x, app.State.objects(k).border_y, ...
                        centroid, angleRad);
                    app.State.objects(k).border_x = xR;
                    app.State.objects(k).border_y = yR;
                end
                app.invalidateZonesOnTransform();
                app.refreshPreview();
                return;
            end
            tIdx = currentTargetIdx(app);
            if isnan(tIdx); return; end
            applyTransformToTarget(app, tIdx, [0 0], sign * stepDeg);
            app.invalidateZonesOnTransform();
            app.refreshPreview();
        end

        function refitTargetMask(app)
            % Recompute the mask from the (possibly translated/rotated)
            % border, so when the geometry was just nudged the mask
            % follows. Useful after a sequence of moveTarget/rotateTarget.
            tIdx = currentTargetIdx(app);
            if isnan(tIdx); return; end
            if tIdx == 0
                app.State.arena.mask = imfill(...
                    sphynx.preset.maskFromBorder(app.State.height, app.State.width, ...
                    app.State.arena.border_x, app.State.arena.border_y), 'holes');
            else
                obj = app.State.objects(tIdx);
                obj.mask = imfill(...
                    sphynx.preset.maskFromBorder(app.State.height, app.State.width, ...
                    obj.border_x, obj.border_y), 'holes');
                app.State.objects(tIdx) = obj;
            end
            app.refreshPreview();
            sphynx.util.log('info', '[App] refit mask for target idx=%d', tIdx);
        end

        function refreshMoveTargets(app)
            items = {'All', 'Arena'};
            if numel(app.State.selectedObjectIdx) >= 2
                items{end+1} = '<selection>';
            end
            for k = 1:numel(app.State.objects)
                items{end+1} = app.State.objects(k).type; %#ok<AGROW>
            end
            old = app.MoveTargetDropDown.Value;
            app.MoveTargetDropDown.Items = items;
            if ismember(old, items)
                app.MoveTargetDropDown.Value = old;
            else
                app.MoveTargetDropDown.Value = items{1};
            end
        end

        function nextFrame(app)
            if isempty(app.State.videoPath); app.status('Load video first'); return; end
            if isempty(app.FramePickerDropdown) || ~isvalid(app.FramePickerDropdown)
                return;
            end
            items = app.FramePickerDropdown.Items;
            if isempty(items); return; end
            curIdx = find(strcmp(items, app.FramePickerDropdown.Value), 1);
            if isempty(curIdx); curIdx = 0; end
            nextIdx = mod(curIdx, numel(items)) + 1;
            app.FramePickerDropdown.Value = items{nextIdx};
            app.pickFrame();
        end

        function pickFrame(app)
            if isempty(app.State.videoPath); return; end
            sel = app.FramePickerDropdown.Value;
            parts = strsplit(sel, '/');
            k = str2double(parts{1});
            N = str2double(parts{2});
            app.State.frameIndex = max(1, round(app.State.numFrames * k / N));
            try
                app.State.frame = sphynx.preset.readFrameAt( ...
                    app.State.videoPath, app.State.frameIndex, app.State.frameRate);
                app.refreshPreview();
                if ~isempty(app.FrameIndexLabel)
                    app.FrameIndexLabel.Text = sprintf('Frame %d / %d', ...
                        app.State.frameIndex, app.State.numFrames);
                end
            catch ME
                app.status(sprintf('Frame pick failed: %s', ME.message));
            end
        end

        function rebuildFramePickerDropdown(app)
            if isempty(app.State.numFrames) || isnan(app.State.numFrames); return; end
            if isempty(app.FramePickerNField) || ~isvalid(app.FramePickerNField); return; end
            N = app.FramePickerNField.Value;
            items = arrayfun(@(k) sprintf('%d/%d', k, N), 1:N, 'UniformOutput', false);
            old = '';
            if ~isempty(app.FramePickerDropdown) && isvalid(app.FramePickerDropdown)
                old = app.FramePickerDropdown.Value;
            end
            app.FramePickerDropdown.Items = items;
            if ismember(old, items)
                app.FramePickerDropdown.Value = old;
            else
                app.FramePickerDropdown.Value = items{1};
            end
        end

        function idx = getSelectedObjectIdx(app)
            % Return selected object indices clamped to currently-valid range.
            n = numel(app.State.objects);
            idx = app.State.selectedObjectIdx;
            idx = idx(idx >= 1 & idx <= n);
        end

        function setSelectedObjectIdx(app, idx)
            % Accept numeric vector; clamp, dedup, sort; sync listbox + preview.
            % I4: guard against non-numeric / NaN inputs.
            if ~isnumeric(idx); idx = []; end
            idx = idx(:);
            idx = idx(~isnan(idx));
            n = numel(app.State.objects);
            idx = idx(idx >= 1 & idx <= n);
            idx = unique(idx(:));   % sort + dedup, column vector
            app.State.selectedObjectIdx = idx;
            if isempty(app.ObjectsListBox) || ~isvalid(app.ObjectsListBox)
                app.refreshPreview();
                return;
            end
            % C1: set guard so onObjectsListBoxChanged short-circuits.
            app.UpdatingListboxFromState = true;
            cleaner = onCleanup(@() app.resetListboxFlag()); %#ok<NASGU>
            if isempty(idx) || isempty(app.ObjectsListBox.Items)
                app.ObjectsListBox.Value = {};
            else
                app.ObjectsListBox.Value = app.ObjectsListBox.Items(idx);
            end
            app.refreshMoveTargets();
            app.refreshPreview();
            % R8.2: also refresh manager axes so the yellow selection
            % highlight follows the listbox click while manager is open.
            app.refreshManagerPreview();
        end

        function resetListboxFlag(app)
            app.UpdatingListboxFromState = false;
        end

        function onMirrorListBoxChanged(app)
            % R8.3: main-window mirror listbox selection -> highlight on
            % main preview. Reads ObjectsMirrorListBox.Value, resolves to
            % indices in savedObjects, stores in selectedSavedIdx, redraws.
            if isempty(app.ObjectsMirrorListBox) || ~isvalid(app.ObjectsMirrorListBox)
                return;
            end
            val = app.ObjectsMirrorListBox.Value;
            if isempty(val)
                idx = [];
            else
                if ischar(val); val = {val}; end
                items = app.ObjectsMirrorListBox.Items;
                idx = zeros(0, 1);
                for k = 1:numel(val)
                    hit = find(strcmp(items, val{k}), 1);
                    if ~isempty(hit); idx(end+1, 1) = hit; end %#ok<AGROW>
                end
            end
            app.State.selectedSavedIdx = idx;
            app.refreshPreview();
        end

        function onObjectsListBoxChanged(app, ~)
            % C1: short-circuit when we are the ones writing to the listbox.
            if app.UpdatingListboxFromState; return; end
            if isempty(app.ObjectsListBox) || ~isvalid(app.ObjectsListBox)
                return;
            end
            % I2: convert listbox Value -> numeric indices, then route
            % through setSelectedObjectIdx (single normalization point).
            val = app.ObjectsListBox.Value;
            if isempty(val)
                idx = [];
            else
                if ischar(val); val = {val}; end  % single-select compat guard
                idx = zeros(0, 1);
                for k = 1:numel(val)
                    hit = find(strcmp(app.ObjectsListBox.Items, val{k}), 1);
                    if ~isempty(hit); idx(end+1, 1) = hit; end %#ok<AGROW>
                end
            end
            app.setSelectedObjectIdx(idx);
        end

        function runAutoDetect(app)
            if isempty(app.State.frame) || isempty(app.State.arena) || isempty(app.State.arena.mask)
                app.status('Need video + arena before auto-detect');
                return;
            end
            pxlPerCm = app.State.pxlPerCm;
            % Guard NaN pxlPerCm -> area filters would reject everything
            if isnan(pxlPerCm) || pxlPerCm <= 0
                pxlPerCm = 1;   % treat as 1 px/cm (areas in px^2)
            end
            cfg = struct( ...
                'mode',         app.AutoModeDropdown.Value, ...
                'algorithm',    app.AutoAlgorithmDropdown.Value, ...
                'sensitivity',  app.AutoSensitivitySlider.Value, ...
                'minAreaCm2',   app.AutoMinAreaField.Value, ...
                'maxAreaCm2',   app.AutoMaxAreaField.Value, ...
                'pxlPerCm',     pxlPerCm, ...
                'radiusRangePx', [app.AutoRadiusMinField.Value * pxlPerCm, ...
                                  app.AutoRadiusMaxField.Value * pxlPerCm], ...
                'neighborhoodCm', app.AutoNeighborhoodField.Value);
            try
                if size(app.State.frame, 3) == 3
                    gray = rgb2gray(app.State.frame);
                else
                    gray = app.State.frame;
                end
                objs = sphynx.preset.autoDetectObjects(gray, app.State.arena.mask, cfg);
                app.State.autoDetectedObjects = objs;
                app.refreshManagerPreview();
                app.refreshPreview();
                app.status(sprintf('Auto-detected %d objects (preview only; click Commit to add)', numel(objs)));
                app.focusManagerIfOpen();
            catch ME
                app.status(sprintf('Auto-detect failed: %s', ME.message));
            end
        end

        function refreshManagerPreview(app)
            % Redraw manager axes: frame + arena + objects + auto-detected.
            % Pending ROIs are saved and restored after cla so they survive refresh.
            if isempty(app.ManagerAxes) || ~isvalid(app.ManagerAxes); return; end
            % Save pending positions before cla
            pendingPositions = {};
            pendingGeoms     = {};
            if ~isempty(app.PendingShapeHandles)
                for k = 1:numel(app.PendingShapeHandles)
                    h = app.PendingShapeHandles{k};
                    if isvalid(h)
                        geomK = app.PendingShapeGeometries{k};
                        switch geomK
                            case 'Circle'
                                pos = struct('Center', h.Center, 'Radius', h.Radius);
                            case 'Ellipse'
                                pos = struct('Center', h.Center, 'SemiAxes', h.SemiAxes, ...
                                    'RotationAngle', h.RotationAngle);
                            otherwise  % Polygon
                                pos = h.Position;
                        end
                        pendingPositions{end+1} = pos; %#ok<AGROW>
                        pendingGeoms{end+1}     = geomK; %#ok<AGROW>
                    end
                end
            end
            cla(app.ManagerAxes);
            hold(app.ManagerAxes, 'on');
            if ~isempty(app.State.frame)
                imshow(app.State.frame, 'Parent', app.ManagerAxes);
            end
            % Arena overlay
            if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
                plot(app.ManagerAxes, app.State.arena.border_x, app.State.arena.border_y, '-', ...
                    'Color', [0.85 0.55 0.10], 'LineWidth', 2);
            end
            % Existing objects (semi-transparent fill + type-name label).
            % R8.1: show actual type (target / object1..N-1) so Order Barnes
            % reflects on the picture, not just in the listbox.
            for k = 1:numel(app.State.objects)
                o = app.State.objects(k);
                if isempty(o.border_x); continue; end
                fill(app.ManagerAxes, o.border_x, o.border_y, [0.3 0.5 0.8], ...
                    'FaceAlpha', 0.20, 'EdgeColor', [0.1 0.3 0.6], 'LineWidth', 1);
                label = o.type;
                if isempty(label); label = sprintf('%d', k); end
                text(app.ManagerAxes, mean(o.border_x), mean(o.border_y), ...
                    label, 'Color', 'w', 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'FontSize', 10);
            end
            % Selected objects highlighted in yellow
            selIdx = app.getSelectedObjectIdx();
            for k = selIdx(:)'
                o = app.State.objects(k);
                if isempty(o.border_x); continue; end
                plot(app.ManagerAxes, o.border_x, o.border_y, '-', ...
                    'Color', [1 0.85 0], 'LineWidth', 2);
            end
            % Auto-detected preview (green dashed)
            if isfield(app.State, 'autoDetectedObjects') && ~isempty(app.State.autoDetectedObjects)
                for k = 1:numel(app.State.autoDetectedObjects)
                    ado = app.State.autoDetectedObjects(k);
                    if isempty(ado.border_x); continue; end
                    plot(app.ManagerAxes, ado.border_x, ado.border_y, '--', ...
                        'Color', [0 0.8 0], 'LineWidth', 1.5);
                end
            end
            hold(app.ManagerAxes, 'off');
            % Restore pending ROIs
            app.PendingShapeHandles    = {};
            app.PendingShapeGeometries = {};
            for k = 1:numel(pendingPositions)
                h = createPendingROI(app.ManagerAxes, pendingGeoms{k}, pendingPositions{k});
                app.PendingShapeHandles{end+1}    = h;
                app.PendingShapeGeometries{end+1} = pendingGeoms{k};
            end
        end

        function addPendingShape(app)
            if isempty(app.State.frame)
                if ~isempty(app.ManagerStatusLabel) && isvalid(app.ManagerStatusLabel)
                    app.ManagerStatusLabel.Text = 'Load video first';
                end
                return;
            end
            if isempty(app.ManagerAxes) || ~isvalid(app.ManagerAxes); return; end
            geom = app.State.objectGeometry;
            app.ManagerStatusLabel.Text = sprintf('Drawing %s — drag/click, double-click to finish', geom);
            try
                switch geom
                    case 'Polygon'
                        h = drawpolygon(app.ManagerAxes, 'Color', [0 0.6 0], 'LineWidth', 1);
                    case 'Circle'
                        h = drawcircle(app.ManagerAxes, 'Color', [0 0.6 0], 'LineWidth', 1);
                    case 'Ellipse'
                        h = drawellipse(app.ManagerAxes, 'Color', [0 0.6 0], 'LineWidth', 1);
                    otherwise
                        h = drawpolygon(app.ManagerAxes, 'Color', [0 0.6 0], 'LineWidth', 1);
                end
                wait(h);
                if ~isvalid(h)
                    app.ManagerStatusLabel.Text = 'Cancelled';
                    return;
                end
                app.PendingShapeHandles{end+1}    = h;
                app.PendingShapeGeometries{end+1} = geom;
                app.ManagerStatusLabel.Text = sprintf('Pending: %d shape(s). Click + Add shape for next, or Commit pending.', ...
                    numel(app.PendingShapeHandles));
                app.focusManagerIfOpen();
            catch ME
                if ~isempty(app.ManagerStatusLabel) && isvalid(app.ManagerStatusLabel)
                    app.ManagerStatusLabel.Text = sprintf('Add shape failed: %s', ME.message);
                end
            end
        end

        function commitPendingShapes(app)
            if isempty(app.PendingShapeHandles)
                if ~isempty(app.ManagerStatusLabel) && isvalid(app.ManagerStatusLabel)
                    app.ManagerStatusLabel.Text = 'No pending shapes';
                end
                return;
            end
            nCommitted = 0;
            for k = 1:numel(app.PendingShapeHandles)
                h = app.PendingShapeHandles{k};
                if ~isvalid(h); continue; end
                geom = app.PendingShapeGeometries{k};
                switch geom
                    case 'Polygon'
                        pts = h.Position;   % Nx2 [x y]
                    case 'Circle'
                        cx = h.Center(1); cy = h.Center(2); r = h.Radius;
                        ang = linspace(0, 2*pi, 60)';
                        pts = [cx + r*cos(ang), cy + r*sin(ang)];
                    case 'Ellipse'
                        cx = h.Center(1); cy = h.Center(2);
                        a  = h.SemiAxes(1); b = h.SemiAxes(2);
                        rot = deg2rad(h.RotationAngle);
                        ang = linspace(0, 2*pi, 60)';
                        xx = a*cos(ang); yy = b*sin(ang);
                        pts = [cx + xx*cos(rot) - yy*sin(rot), ...
                               cy + xx*sin(rot) + yy*cos(rot)];
                    otherwise
                        pts = h.Position;
                end
                try
                    obj = sphynx.preset.readArenaGeometry(app.State.frame, geom, 'Points', pts);
                    obj.type  = sprintf('object%d', numel(app.State.objects) + 1);
                    obj.class = '';
                    objCanon = app.canonicalizeObjects(obj);
                    existing = app.canonicalizeObjects(app.State.objects);
                    if isempty(existing)
                        app.State.objects = objCanon;
                    else
                        existing(end + 1) = objCanon;
                        app.State.objects = existing;
                    end
                    nCommitted = nCommitted + 1;
                    delete(h);
                catch ME
                    sphynx.util.log('warn', '[Manager] commit shape %d failed: %s', k, ME.message);
                end
            end
            app.PendingShapeHandles    = {};
            app.PendingShapeGeometries = {};
            app.refreshObjectsList();
            app.refreshMoveTargets();
            app.refreshManagerPreview();
            app.refreshPreview();
            if ~isempty(app.ManagerStatusLabel) && isvalid(app.ManagerStatusLabel)
                app.ManagerStatusLabel.Text = sprintf('Committed %d shapes', nCommitted);
            end
            app.focusManagerIfOpen();
        end

        function cancelPendingShapes(app)
            for k = 1:numel(app.PendingShapeHandles)
                h = app.PendingShapeHandles{k};
                if isvalid(h); delete(h); end
            end
            app.PendingShapeHandles    = {};
            app.PendingShapeGeometries = {};
            if ~isempty(app.ManagerStatusLabel) && isvalid(app.ManagerStatusLabel)
                app.ManagerStatusLabel.Text = 'Pending cleared';
            end
            app.focusManagerIfOpen();
        end

        function orderObjectsBarnes(app)
            % Sort objects clockwise around arena center starting from selected target.
            idx = app.getSelectedObjectIdx();
            if numel(idx) ~= 1
                app.status('Order by Barnes: select exactly 1 target object');
                return;
            end
            if isempty(app.State.arena) || isempty(app.State.arena.border_x)
                app.status('Order by Barnes: arena required');
                return;
            end
            if numel(app.State.objects) < 2
                app.status('Order by Barnes: need at least 2 objects');
                return;
            end
            targetIdx = idx(1);
            arenaCx = mean(app.State.arena.border_x);
            arenaCy = mean(app.State.arena.border_y);
            n = numel(app.State.objects);
            angles = zeros(n, 1);
            for k = 1:n
                cx = mean(app.State.objects(k).border_x);
                cy = mean(app.State.objects(k).border_y);
                % atan2(y-down, x-right): in image coords this increases CW visually
                angles(k) = atan2(cy - arenaCy, cx - arenaCx);
            end
            targetAng = angles(targetIdx);
            rel = mod(angles - targetAng, 2*pi);
            [~, order] = sort(rel);
            reordered = app.State.objects(order);
            % order(1) is the target (rel_target = 0). Rename target + CW objects.
            reordered(1).type = 'target';
            for k = 2:numel(reordered)
                reordered(k).type = sprintf('object%d', k - 1);
            end
            app.State.objects = reordered;
            app.refreshObjectsList();
            app.refreshMoveTargets();
            app.setSelectedObjectIdx(1);
            app.refreshManagerPreview();
            app.refreshPreview();
            app.status(sprintf('Ordered: target + %d objects CW around arena center', n - 1));
            app.focusManagerIfOpen();
        end

        function updateAutoDetectEnableState(app)
            % Enable/disable Hough vs threshold controls based on Mode + Algorithm.
            if isempty(app.AutoModeDropdown); return; end
            mode = app.AutoModeDropdown.Value;
            isCircles = strcmp(mode, 'all-circles');
            app.AutoAlgorithmDropdown.Enable = toOnOff(isCircles);
            if isCircles
                alg = app.AutoAlgorithmDropdown.Value;
            else
                alg = 'threshold';
            end
            isHough = isCircles && strcmp(alg, 'hough');
            app.AutoNeighborhoodField.Enable = toOnOff(~isHough);
            app.AutoRadiusMinField.Enable    = toOnOff(isHough);
            app.AutoRadiusMaxField.Enable    = toOnOff(isHough);
        end

        function onSensitivityChanging(app, evt)
            % Debounced live slider: re-run auto-detect while user drags.
            % Update live value label.
            if ~isempty(app.AutoSensitivityValueLabel) && isvalid(app.AutoSensitivityValueLabel)
                app.AutoSensitivityValueLabel.Text = sprintf('%.2f', evt.Value);
            end
            % Mirror slider Value so runAutoDetect reads the live value.
            app.AutoSensitivitySlider.Value = evt.Value;
            if isempty(app.State.frame) || isempty(app.State.arena); return; end
            if isempty(app.State.arena.mask); return; end
            app.runAutoDetect();
        end

        function commitAutoDetected(app)
            if isempty(app.State.autoDetectedObjects)
                app.status('Nothing to commit. Run Auto-detect first.');
                return;
            end
            startNum = app.AutoStartFromField.Value;
            newObjs = app.State.autoDetectedObjects;
            % Round 7 fix: canonicalize each auto-detected object to the
            % full 9-field schema (adds empty border_separate_x/y) so
            % subsequent manual-add via Pending shapes can append without
            % a struct-array field-mismatch error.
            for k = 1:numel(newObjs)
                newObjs(k).type = sprintf('object%d', startNum + k - 1);
            end
            canonNew = app.canonicalizeObjects(newObjs);
            existing = app.canonicalizeObjects(app.State.objects);
            if isempty(existing)
                app.State.objects = canonNew;
            else
                for k = 1:numel(canonNew)
                    existing(end + 1) = canonNew(k); %#ok<AGROW>
                end
                app.State.objects = existing;
            end
            nAdded = numel(canonNew);
            app.State.autoDetectedObjects = struct('type', {}, 'geometry', {}, ...
                'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
            app.refreshObjectsList();
            app.refreshMoveTargets();
            app.refreshManagerPreview();
            app.refreshPreview();
            app.status(sprintf('Committed %d auto-detected objects', nAdded));
        end

        function objs = canonicalizeObjects(~, objs)
            % Round 7: ensure every element has the canonical 8 fields so
            % struct arrays from different sources (autoDetectObjects 6-field,
            % readArenaGeometry 9-field) can be concatenated safely.
            needs = {'type', 'geometry', 'border_x', 'border_y', ...
                'border_separate_x', 'border_separate_y', 'mask', 'class'};
            if isempty(objs)
                objs = cell2struct(cell(numel(needs), 0), needs, 1);
                return;
            end
            for f = 1:numel(needs)
                if ~isfield(objs, needs{f})
                    for k = 1:numel(objs)
                        objs(k).(needs{f}) = [];
                    end
                end
            end
            for k = 1:numel(objs)
                if ~iscell(objs(k).border_separate_x)
                    objs(k).border_separate_x = {};
                end
                if ~iscell(objs(k).border_separate_y)
                    objs(k).border_separate_y = {};
                end
                if isempty(objs(k).class); objs(k).class = ''; end
            end
            objs = orderfields(objs, needs);
        end

        function alignDetectedRadii(app)
            if ~isfield(app.State, 'autoDetectedObjects') || isempty(app.State.autoDetectedObjects)
                app.status('No auto-detected objects to align');
                app.focusManagerIfOpen();
                return;
            end
            pxlPerCm = app.State.pxlPerCm;
            if isnan(pxlPerCm) || pxlPerCm <= 0
                app.status('Calibrate pxlPerCm first');
                app.focusManagerIfOpen();
                return;
            end
            % Mean radius across detected objects, in cm
            radii = zeros(1, numel(app.State.autoDetectedObjects));
            for k = 1:numel(app.State.autoDetectedObjects)
                o = app.State.autoDetectedObjects(k);
                cx = mean(o.border_x);
                cy = mean(o.border_y);
                radii(k) = mean(sqrt((o.border_x - cx).^2 + (o.border_y - cy).^2)) / pxlPerCm;
            end
            meanCm = mean(radii);
            answer = inputdlg(sprintf('Detected mean radius: %.2f cm. Apply this (or edit) to all:', meanCm), ...
                              'Align radii', 1, {sprintf('%.2f', meanCm)});
            if isempty(answer); app.focusManagerIfOpen(); return; end
            newR_cm = str2double(answer{1});
            if isnan(newR_cm) || newR_cm <= 0
                app.status('Invalid radius');
                app.focusManagerIfOpen();
                return;
            end
            newR_px = newR_cm * pxlPerCm;
            ang = linspace(0, 2*pi, 60)';
            for k = 1:numel(app.State.autoDetectedObjects)
                o = app.State.autoDetectedObjects(k);
                cx = mean(o.border_x);
                cy = mean(o.border_y);
                o.border_x = cx + newR_px * cos(ang);
                o.border_y = cy + newR_px * sin(ang);
                o.mask = imfill(sphynx.preset.maskFromBorder( ...
                    app.State.height, app.State.width, o.border_x, o.border_y), 'holes');
                o.geometry = 'Circle';
                app.State.autoDetectedObjects(k) = o;
            end
            app.refreshManagerPreview();
            app.status(sprintf('Aligned %d detected circles to r=%.2f cm', numel(radii), newR_cm));
            app.focusManagerIfOpen();
        end
    end

    % ========== UI builders =================================================
    methods (Access = private)
        function buildUI(app)
            app.Figure = uifigure('Name', 'sphynx — Preset & Analyze', ...
                'Position', [80, 80, 1100, 720], 'Visible', 'on', ...
                'WindowState', 'maximized');
            % Wrap the tabgroup in a uigridlayout so it fills the figure
            % and resizes correctly when the user drags the window.
            outerWrap = uigridlayout(app.Figure, [1, 1]);
            outerWrap.Padding = [0 0 0 0];
            outerWrap.RowHeight = {'1x'};
            outerWrap.ColumnWidth = {'1x'};
            app.TabGroup = uitabgroup(outerWrap);
            % Order: Create Preset / Preprocess Tracking / Define Acts /
            % Analyze Session / Batch Analysis / Preprocess Video /
            % Synthetic Data (last).
            app.TabCreate          = uitab(app.TabGroup, 'Title', 'Create Preset');
            app.TabPreprocess      = uitab(app.TabGroup, 'Title', 'Preprocess Tracking');
            app.TabDefineActs      = uitab(app.TabGroup, 'Title', 'Define Acts');
            app.TabAnalyze         = uitab(app.TabGroup, 'Title', 'Analyze Session');
            app.TabBatch           = uitab(app.TabGroup, 'Title', 'Batch Analysis');
            app.TabMakeOutputTable = uitab(app.TabGroup, 'Title', 'Make Output Table');
            app.TabPlotData        = uitab(app.TabGroup, 'Title', 'Plot Data');
            app.TabPreprocessVideo = uitab(app.TabGroup, 'Title', 'Preprocess Video *');
            app.TabSynthetic       = uitab(app.TabGroup, 'Title', 'Synthetic Data *');

            buildCreateTab(app);
            app.PreprocessController      = sphynx.app.PreprocessTabController(app.TabPreprocess, app);
            app.DefineActsController      = sphynx.app.DefineActsTabController(app.TabDefineActs, app);
            app.AnalyzeSessionController  = sphynx.app.AnalyzeSessionTabController(app.TabAnalyze, app);
            app.BatchAnalysisController   = sphynx.app.BatchAnalysisTabController(app.TabBatch, app);
            app.MakeOutputTableController = sphynx.app.MakeOutputTableTabController(app.TabMakeOutputTable, app);
            app.PlotDataController        = sphynx.app.PlotDataTabController(app.TabPlotData, app);
            app.PreprocessVideoController = sphynx.app.PreprocessVideoTabController(app.TabPreprocessVideo, app);
            app.SyntheticController       = sphynx.app.SyntheticDataTabController(app.TabSynthetic, app);
        end

        function tf = isManagerOpen(app)
            tf = ~isempty(app.ObjectsManagerFig) && isvalid(app.ObjectsManagerFig);
        end

        function refocus(app)
            % Suppress focus shift to main while the manager is open
            % (round 7: prevents flickering between manager and main).
            if app.isManagerOpen(); return; end
            if ~isempty(app.Figure) && isvalid(app.Figure)
                figure(app.Figure);
            end
        end

        function focusManagerIfOpen(app)
            % Round 7: kept as a no-op. Focus stealing fixed at the source
            % (refocus + refreshPreview are now manager-aware), so no need
            % to fight the OS with visibility cycles.
        end

        function status(app, msg)
            app.applog('info', '%s', msg);
            app.refocus();
        end

        function applog(app, level, fmt, varargin)
            % Mirror sphynx.util.log to the in-app textarea so the user
            % can scroll the history without leaving the GUI.
            sphynx.util.log(level, ['[App] ' fmt], varargin{:});
            if isempty(app.LogTextArea); return; end
            line = sprintf(['[' upper(level) '] ' fmt], varargin{:});
            current = app.LogTextArea.Value;
            if isempty(current); current = {}; end
            if ~iscell(current); current = cellstr(current); end
            % Newest line at the TOP so the latest message is always visible
            % without scrolling (workaround for R2020a uitextarea).
            current = [{line}; current(:)];
            if numel(current) > 500
                current = current(1:500);
            end
            app.LogTextArea.Value = current;
        end

        function showObjectsManager(app)
            % Open (or bring to front) the Objects + Auto-detect manager window.
            if ~isempty(app.ObjectsManagerFig) && isvalid(app.ObjectsManagerFig)
                figure(app.ObjectsManagerFig);
                return;
            end
            if ~app.ManagerSessionDirty
                % Fresh session: copy committed state to working copy so
                % the manager starts from where the saved state left off.
                app.State.objects = app.State.savedObjects;
                app.ManagerSessionDirty = true;
            end
            fh = uifigure('Name', 'Objects Manager', ...
                'Position', [120 80 1400 750]);
            app.ObjectsManagerFig = fh;
            gl = uigridlayout(fh, [1, 3]);
            gl.ColumnWidth = {260, '1x', 300};
            gl.ColumnSpacing = 8;
            gl.Padding = [8 8 8 8];

            listPanel    = uipanel(gl, 'Title', 'Objects', 'FontSize', 13, 'FontWeight', 'bold');
            previewPanel = uipanel(gl, 'Title', 'Preview & Pick', 'FontSize', 13, 'FontWeight', 'bold');
            adPanel      = uipanel(gl, 'Title', 'Auto-detect', 'FontSize', 13, 'FontWeight', 'bold');

            buildObjectsListIn(app, listPanel);
            buildObjectsPickIn(app, previewPanel);
            buildAutoDetectControlsIn(app, adPanel);
        end

        function finishManager(app)
            % Commit working copy (app.State.objects) to saved state and close manager.
            app.State.savedObjects = app.State.objects;
            app.ManagerSessionDirty = false;
            if isfield(app.State, 'autoDetectedObjects')
                app.State.autoDetectedObjects = struct('type', {}, 'geometry', {}, ...
                    'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
            end
            app.refreshPreview();
            app.refreshObjectsList();
            app.refreshMoveTargets();
            app.status(sprintf('Finished: %d object(s) committed', numel(app.State.savedObjects)));
            if ~isempty(app.ObjectsManagerFig) && isvalid(app.ObjectsManagerFig)
                delete(app.ObjectsManagerFig);
            end
            app.ObjectsManagerFig = [];
        end

        function refreshPreview(app)
            if isempty(app.State.frame); return; end
            % Round 7: skip main redraw while manager is open. Main only
            % reflects committed (saved) state; finishManager triggers an
            % explicit refresh on close. Avoids focus flicker.
            if app.isManagerOpen(); return; end
            ax = app.PreviewAxes;
            cla(ax);
            % Use raw image() instead of imshow() — image() coexists with
            % patch + FaceAlpha cleanly in uiaxes (imshow re-locks props).
            image(ax, app.State.frame);
            ax.YDir = 'reverse';
            ax.DataAspectRatio = [1 1 1];
            ax.XLim = [0.5, size(app.State.frame, 2) + 0.5];
            ax.YLim = [0.5, size(app.State.frame, 1) + 0.5];
            ax.XTick = []; ax.YTick = [];
            ax.Box = 'on';
            hold(ax, 'on');
            % Zones — outline-only in preview (filled is too slow with
            % many zones on large frames). Save plot still uses filled.
            if ~isempty(app.State.zones)
                cmap = colorPaletteForZones(numel(app.State.zones));
                for k = 1:numel(app.State.zones)
                    drawZoneOutline(ax, app.State.zones(k), cmap(k,:));
                end
            end
            if ~isempty(app.State.previewZones)
                cmap = colorPaletteForZones(numel(app.State.previewZones));
                for k = 1:numel(app.State.previewZones)
                    drawZoneOutline(ax, app.State.previewZones(k), cmap(k,:));
                end
            end
            % Arena outline
            if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
                plot(ax, app.State.arena.border_x(:), app.State.arena.border_y(:), ...
                    'k-', 'LineWidth', 2);
            end
            % Objects — main panel shows SAVED state only (draft model Fix 5).
            % R8.3: selected saved object(s) get yellow highlight + name tag.
            savedObjs = app.State.savedObjects;
            for k = 1:numel(savedObjs)
                plot(ax, savedObjs(k).border_x(:), savedObjs(k).border_y(:), ...
                    '-', 'Color', [0 0.7 0], 'LineWidth', 1.5);
            end
            selSavedIdx = [];
            if isfield(app.State, 'selectedSavedIdx')
                selSavedIdx = app.State.selectedSavedIdx;
                selSavedIdx = selSavedIdx(selSavedIdx >= 1 & selSavedIdx <= numel(savedObjs));
            end
            for k = selSavedIdx(:)'
                o = savedObjs(k);
                if isempty(o.border_x); continue; end
                plot(ax, o.border_x(:), o.border_y(:), '-', ...
                    'Color', [1 0.85 0], 'LineWidth', 2.5);
                label = o.type;
                if ~isempty(label)
                    text(ax, mean(o.border_x), mean(o.border_y), label, ...
                        'Color', 'w', 'FontWeight', 'bold', 'FontSize', 10, ...
                        'HorizontalAlignment', 'center');
                end
            end
            hold(ax, 'off');
        end

        function refreshObjectsList(app)
            % I3: use getSelectedObjectIdx() — no duplicated clamping logic.
            % Draft model (Fix 5): manager listbox = working state (objects);
            %   mirror listbox in main panel = saved state (savedObjects).

            % Manager listbox — working state
            if ~isempty(app.ObjectsListBox) && isvalid(app.ObjectsListBox)
                if isempty(app.State.objects)
                    workingItems = {};
                else
                    workingItems = arrayfun(@(o) sprintf('%s (%s)', o.type, o.geometry), ...
                        app.State.objects, 'UniformOutput', false);
                end
                app.UpdatingListboxFromState = true;
                cleaner = onCleanup(@() app.resetListboxFlag()); %#ok<NASGU>
                app.ObjectsListBox.Items = workingItems;
                idx = app.getSelectedObjectIdx();
                if isempty(idx)
                    app.ObjectsListBox.Value = {};
                else
                    app.ObjectsListBox.Value = workingItems(idx);
                end
            end
            % Mirror listbox in main Block 4 — saved state (R8.3 interactive)
            if ~isempty(app.ObjectsMirrorListBox) && isvalid(app.ObjectsMirrorListBox)
                if isempty(app.State.savedObjects)
                    savedItems = {};
                else
                    savedItems = arrayfun(@(o) o.type, app.State.savedObjects, 'UniformOutput', false);
                end
                app.ObjectsMirrorListBox.Items = savedItems;
                % Clamp + restore selection from state.
                if isfield(app.State, 'selectedSavedIdx')
                    sel = app.State.selectedSavedIdx;
                    sel = sel(sel >= 1 & sel <= numel(savedItems));
                    app.State.selectedSavedIdx = sel;
                    if isempty(sel) || isempty(savedItems)
                        app.ObjectsMirrorListBox.Value = {};
                    else
                        app.ObjectsMirrorListBox.Value = savedItems(sel);
                    end
                end
            end
            app.refreshObjectsCount();
        end

        function refreshObjectsCount(app)
            % Update the compact summary label in the main left column.
            % Shows SAVED count (draft model Fix 5).
            if isempty(app.ObjectsCountLabel) || ~isvalid(app.ObjectsCountLabel)
                return;
            end
            n = numel(app.State.savedObjects);
            app.ObjectsCountLabel.Text = sprintf('%d object(s) saved -- click Manage to add/edit', n);
        end

        function refreshZonesCount(app)  %#ok<MANU>
            % Replaced by refreshZonesLabel; kept as no-op for legacy callers.
            app.refreshZonesLabel();
        end

        function refreshCalibLabels(app)
            if ~isempty(app.PxlPerCmAvgLabel)
                app.PxlPerCmAvgLabel.Text = sprintf('avg: %.2f', app.State.pxlPerCm);
                app.PxlPerCmYLabel.Text   = sprintf('Y: %.2f', app.State.pxlPerCmY);
                app.PxlPerCmXLabel.Text   = sprintf('X: %.2f', app.State.pxlPerCmX);
                app.XKcorrLabel.Text      = sprintf('kcorr: %.3f', app.State.x_kcorr);
            end
        end

        function Options = assembleOptions(app)
            % Per-user spec (Q6): keep frame metadata + calibration +
            % experiment type + arena geometry + good-frame snapshot;
            % store widths and counts. Drop pipeline-side params
            % (LikelihoodThreshold, velocity_*, BodyPart) — those live
            % in sphynx.pipeline.defaultConfig now.
            Options = struct();
            Options.ExperimentType = app.ExpTypeDropDown.Value;
            Options.pxl2sm = app.State.pxlPerCm;
            Options.pxl2smY = app.State.pxlPerCmY;
            Options.pxl2smX = app.State.pxlPerCmX;
            Options.x_kcorr = app.State.x_kcorr;
            Options.FrameRate = app.State.frameRate;
            Options.NumFrames = app.State.numFrames;
            Options.Height = app.State.height;
            Options.Width = app.State.width;
            Options.ArenaGeometry = '';
            if ~isempty(app.State.arena); Options.ArenaGeometry = app.State.arena.geometry; end
            Options.GoodVideoFrame = app.State.frame;
            if size(app.State.frame, 3) >= 1
                Options.GoodVideoFrameGray = app.State.frame(:, :, 1);
            end
            Options.ObjectsNumber = numel(app.State.savedObjects);
            Options.WallWidthCm       = app.WallWidthField.Value;
            Options.MiddleWidthCm     = app.MiddleWidthField.Value;
            Options.NumStrips         = app.NumStripsField.Value;
            Options.StripDirection    = app.StripDirDropDown.Value;
            Options.CenterDiameterCm  = app.CenterDiameterCmField.Value;
            Options.ObjectZoneWidthCm = app.ObjectZoneWidthField.Value;
            % Save the cm distances the user typed during calibration so
            % that loading this preset later can restore the same values
            % into the cm Y / cm X fields (round-5 fix).
            Options.DistanceYCm = app.DistanceYField.Value;
            Options.DistanceXCm = app.DistanceXField.Value;
        end

        function ArenaAndObjects = assembleArenaAndObjects(app)
            ArenaAndObjects = struct( ...
                'type', {}, 'geometry', {}, 'maskborder', {}, 'maskfilled', {}, ...
                'border_x', {}, 'border_y', {}, ...
                'border_separate_x', {}, 'border_separate_y', {}, 'class', {});
            ArenaAndObjects(1).type = 'Arena';
            ArenaAndObjects(1).geometry = app.State.arena.geometry;
            ArenaAndObjects(1).maskfilled = single(app.State.arena.mask);
            ArenaAndObjects(1).border_x = app.State.arena.border_x;
            ArenaAndObjects(1).border_y = app.State.arena.border_y;
            ArenaAndObjects(1).border_separate_x = app.State.arena.border_separate_x;
            ArenaAndObjects(1).border_separate_y = app.State.arena.border_separate_y;
            ArenaAndObjects(1).class = '';
            % Use savedObjects for serialization (draft model Fix 5).
            for k = 1:numel(app.State.savedObjects)
                idx = k + 1;
                ArenaAndObjects(idx).type = app.State.savedObjects(k).type;
                ArenaAndObjects(idx).geometry = app.State.savedObjects(k).geometry;
                ArenaAndObjects(idx).maskfilled = single(app.State.savedObjects(k).mask);
                ArenaAndObjects(idx).border_x = app.State.savedObjects(k).border_x;
                ArenaAndObjects(idx).border_y = app.State.savedObjects(k).border_y;
                ArenaAndObjects(idx).class = getFieldOr(app.State.savedObjects(k), 'class', '');
            end
        end
    end

    methods (Static)
        function s = emptyState()
            s.projectRoot = '';
            s.videoPath = '';
            s.outDir = '';
            s.presetPath = '';
            s.frame = [];
            s.frameRate = NaN;
            s.numFrames = NaN;
            s.height = NaN;
            s.width = NaN;
            s.frameIndex = 1;
            s.pxlPerCm = NaN;
            s.pxlPerCmY = NaN;
            s.pxlPerCmX = NaN;
            s.x_kcorr = 1;
            s.calibPoints = [];
            s.arenaGeometry = 'Polygon';
            s.objectGeometry = 'Polygon';
            s.arena = [];
            s.objects = struct('type', {}, 'geometry', {}, 'border_x', {}, 'border_y', {}, ...
                                'border_separate_x', {}, 'border_separate_y', {}, 'mask', {}, 'class', {});
            s.savedObjects = struct('type', {}, 'geometry', {}, 'border_x', {}, 'border_y', {}, ...
                                    'mask', {}, 'class', {});
            s.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            s.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
            s.zoneStrategies = {};   % short tags appended on each Add to set
            s.selectedObjectIdx = [];   % vector of object indices (S1 foundation)
            s.selectedSavedIdx  = [];   % R8.3: main mirror listbox selection
            s.autoDetectedObjects = struct('type', {}, 'geometry', {}, ...
                'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
        end
    end
end

% =================== Tab builders =========================================

function buildCreateTab(app)
    app.OuterGrid = uigridlayout(app.TabCreate, [1, 2]);
    % Round-4: explicit 480 px so all 'fit' panels (Arena with extra
    % buttons / Objects) have enough room for INFO etc.
    app.OuterGrid.ColumnWidth = {480, '1x'};
    app.OuterGrid.RowHeight = {'1x'};

    % Wrap left column in a scrollable panel so panels stay readable
    % when the user shrinks the window vertically.
    leftScroll = uipanel(app.OuterGrid, 'BorderType', 'none', 'Scrollable', 'on');
    leftScroll.Layout.Column = 1;

    app.LeftGrid = uigridlayout(leftScroll, [6, 1]);
    app.LeftGrid.Scrollable = 'on';   % belt-and-braces: also on the grid itself
    % Per-panel height = sum(rowHeights) + (n-1)*rowSpacing + 8 padding
    %                    + ~25 panel title bar. Row heights are 28 px
    %                    uniformly; Scrollable wrapper handles overflow.
    % Tuned visually from a screenshot:
    %   Row 1 Load (100), Row 2 Calib (3 rows × 28 + spacing + padding +
    %   panel title ≈ 145), Row 3 Arena (2 rows × 28 + title ≈ 95),
    %   Row 4 Objects compact (label + button + mirror listbox = 200),
    %   Row 5 Zones (245), Row 6 Save (75).
    %   Objects manager + Auto-detect are in a separate uifigure window.
    app.LeftGrid.RowHeight = {100, 145, 95, 200, 245, 75};
    app.LeftGrid.RowSpacing = 4;
    app.LeftGrid.Padding = [4 4 4 4];

    app.LoadPanel    = uipanel(app.LeftGrid, 'Title', '1. Load');
    app.CalibPanel   = uipanel(app.LeftGrid, 'Title', '2. Calibration');
    app.ArenaPanel   = uipanel(app.LeftGrid, 'Title', '3. Arena');
    app.ObjectsPanel = uipanel(app.LeftGrid, 'Title', '4. Objects');
    app.ZonesPanel   = uipanel(app.LeftGrid, 'Title', '5. Zones');
    app.SavePanel    = uipanel(app.LeftGrid, 'Title', '6. Save');

    buildLoadPanel(app);
    buildCalibPanel(app);
    buildArenaPanel(app);
    buildObjectsPanelCompact(app);
    buildZonesPanel(app);
    buildSavePanel(app);

    % Right column: preview + nav strip + move strip + log textarea
    app.RightGrid = uigridlayout(app.OuterGrid, [4, 1]);
    app.RightGrid.Layout.Column = 2;
    app.RightGrid.RowHeight = {'1x', 40, 40, 130};
    app.RightGrid.RowSpacing = 3;
    app.PreviewPanel = uipanel(app.RightGrid, 'Title', 'Preview', ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.55 0.10 0.10]);   % bordo
    pg = uigridlayout(app.PreviewPanel, [1, 1]);
    app.PreviewAxes = uiaxes(pg);
    app.PreviewAxes.XTick = []; app.PreviewAxes.YTick = [];

    % Row 2: nav (Next frame + frame label + N field + dropdown + target dropdown + step)
    navPanel = uipanel(app.RightGrid);
    cg = uigridlayout(navPanel, [1, 9]);
    cg.RowHeight = {'1x'};   % stretch to fit panel height — vertically centered
    cg.ColumnWidth = {'fit', 110, 'fit', 50, 120, 'fit', 'fit', 'fit', 60};
    cg.ColumnSpacing = 4;
    cg.Padding = [4 4 4 4];
    bNext = uibutton(cg, 'Text', 'Next frame', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.nextFrame());
    bNext.Layout.Row = 1; bNext.Layout.Column = 1;
    app.FrameIndexLabel = uilabel(cg, 'Text', 'Frame -- / --');
    app.FrameIndexLabel.Layout.Row = 1; app.FrameIndexLabel.Layout.Column = 2;
    lblN = uilabel(cg, 'Text', 'N:');
    lblN.Layout.Row = 1; lblN.Layout.Column = 3;
    app.FramePickerNField = uieditfield(cg, 'numeric', 'Value', 20, ...
        'Limits', [2 200], 'RoundFractionalValues', 'on', ...
        'ValueChangedFcn', @(~,~) app.rebuildFramePickerDropdown());
    app.FramePickerNField.Layout.Row = 1; app.FramePickerNField.Layout.Column = 4;
    app.FramePickerDropdown = uidropdown(cg, 'Items', {'1/20'}, 'Value', '1/20', ...
        'ValueChangedFcn', @(~,~) app.pickFrame());
    app.FramePickerDropdown.Layout.Row = 1; app.FramePickerDropdown.Layout.Column = 5;
    lblTarget = uilabel(cg, 'Text', 'Target:');
    lblTarget.Layout.Row = 1; lblTarget.Layout.Column = 6;
    app.MoveTargetDropDown = uidropdown(cg, 'Items', {'Arena'}, 'Value', 'Arena');
    app.MoveTargetDropDown.Layout.Row = 1; app.MoveTargetDropDown.Layout.Column = 7;
    lblStep = uilabel(cg, 'Text', 'Step:');
    lblStep.Layout.Row = 1; lblStep.Layout.Column = 8;
    app.MoveStepField = uieditfield(cg, 'numeric', 'Value', 5, 'Limits', [0.1, 200]);
    app.MoveStepField.Layout.Row = 1; app.MoveStepField.Layout.Column = 9;

    % Row 3: arrow + rotate buttons
    movePanel = uipanel(app.RightGrid);
    mg = uigridlayout(movePanel, [1, 6]);
    mg.RowHeight = {'1x'};   % stretch to fit panel height — vertically centered
    mg.ColumnWidth = {80, 80, 80, 80, 80, 80};
    mg.ColumnSpacing = 4;
    mg.Padding = [4 4 4 4];
    addMoveBtn(mg, 1, 'Left',  @() app.moveTarget([-1  0]));
    addMoveBtn(mg, 2, 'Right', @() app.moveTarget([ 1  0]));
    addMoveBtn(mg, 3, 'Up',    @() app.moveTarget([ 0 -1]));
    addMoveBtn(mg, 4, 'Down',  @() app.moveTarget([ 0  1]));
    addMoveBtn(mg, 5, 'Rot ↺', @() app.rotateTarget(-1));
    addMoveBtn(mg, 6, 'Rot ↻', @() app.rotateTarget( 1));

    % Row 4: log textarea (mirrors command-window output)
    logPanel = uipanel(app.RightGrid, 'Title', 'Log');
    lg = uigridlayout(logPanel, [1, 1]);
    lg.Padding = [2 2 2 2];
    app.LogTextArea = uitextarea(lg, 'Editable', 'off', 'Value', {''});
end

function addMoveBtn(parent, col, txt, cb)
    b = uibutton(parent, 'Text', txt, ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) cb());
    b.Layout.Row = 1; b.Layout.Column = col;
end

% Analyze tab is now AnalyzeSessionTabController.

% =================== Panel builders =======================================

function buildLoadPanel(app)
    % 4 columns × 2 rows: top row Browse buttons, bottom row short
    % path-fields. Saves vertical space.
    g = uigridlayout(app.LoadPanel, [2 4]);
    g.RowHeight = {28, 28};
    g.ColumnWidth = {'1x', '1x', '1x', '1x'};
    g.ColumnSpacing = 4;

    addLoadCol(g, 1, 'Project root', @() pickDirAndApply(app, 'setProjectRoot'),  'projectRoot', app);
    addLoadCol(g, 2, 'Video',        @() pickVideoStart(app),                       'videoPath',   app);
    addLoadCol(g, 3, 'Output dir',   @() pickDirAndApply(app, 'setOutDir'),         'outDir',      app);
    addLoadCol(g, 4, 'Preset',       @() pickPresetStart(app),                      'presetPath',  app);
end

function addLoadCol(g, col, btnText, btnFcn, fieldKey, app)
    btn = uibutton(g, 'Text', btnText, ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) btnFcn());
    btn.Layout.Row = 1; btn.Layout.Column = col;
    fld = uieditfield(g, 'text', 'Value', '');
    fld.Layout.Row = 2; fld.Layout.Column = col;
    switch fieldKey
        case 'projectRoot'; app.ProjectRootField = fld;
        case 'videoPath';   app.VideoPathField = fld;
        case 'outDir';      app.OutDirField = fld;
        case 'presetPath';  app.PresetPathField = fld;
    end
end

function buildCalibPanel(app)
    % Round-4 / Round-5: 3 rows total.
    %   Row 1: Choose | mode | cm Y | val | cm X | val | Compute | INFO
    %   Row 2: result labels (Y: / X: / avg: / kcorr:)
    %   Row 3: Exp dropdown spanning the full width
    g = uigridlayout(app.CalibPanel, [3 8]);
    g.RowHeight = {28, 28, 28};
    g.ColumnWidth = {70, 80, 'fit', 50, 'fit', 50, 'fit', 50};
    g.ColumnSpacing = 4;
    g.RowSpacing = 4;

    % Row 1: Choose | mode | cm Y | cmYval | cm X | cmXval | Compute | INFO
    bChoose = uibutton(g, 'Text', 'Choose', ...
        'BackgroundColor', semanticColor('action'), ...
        'Tooltip', ['4 points: click 4 points. ' ...
                    '2 lines / 1 line: drag line endpoints, ' ...
                    'then DOUBLE-CLICK to confirm.'], ...
        'ButtonPushedFcn', @(~,~) onCalibrateChoose(app));
    bChoose.Layout.Row = 1; bChoose.Layout.Column = 1;
    app.CalibModeDropDown = uidropdown(g, ...
        'Items', {'4 points', '2 lines', '1 line'}, 'Value', '1 line', ...
        'Tooltip', '4 points = legacy click-y1-y2-x1-x2; 2 lines = drawline; 1 line = single reference line', ...
        'ValueChangedFcn', @(~,~) onCalibModeChanged(app));
    app.CalibModeDropDown.Layout.Row = 1; app.CalibModeDropDown.Layout.Column = 2;
    lblY = uilabel(g, 'Text', 'cm Y:'); lblY.Layout.Row = 1; lblY.Layout.Column = 3;
    app.DistanceYField = uieditfield(g, 'numeric', 'Value', 92, 'Limits', [0.1, Inf]);
    app.DistanceYField.Layout.Row = 1; app.DistanceYField.Layout.Column = 4;
    lblX = uilabel(g, 'Text', 'cm X:'); lblX.Layout.Row = 1; lblX.Layout.Column = 5;
    app.DistanceXField = uieditfield(g, 'numeric', 'Value', 92, 'Limits', [0.1, Inf]);
    app.DistanceXField.Layout.Row = 1; app.DistanceXField.Layout.Column = 6;
    bCompute = uibutton(g, 'Text', 'Compute', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) onCalibrateCompute(app));
    bCompute.Layout.Row = 1; bCompute.Layout.Column = 7;
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Calibration', helpCalibrationText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = 8;

    % Row 2: result labels
    app.PxlPerCmYLabel = uilabel(g, 'Text', 'Y: ?');
    app.PxlPerCmYLabel.Layout.Row = 2; app.PxlPerCmYLabel.Layout.Column = [1 2];
    app.PxlPerCmXLabel = uilabel(g, 'Text', 'X: ?');
    app.PxlPerCmXLabel.Layout.Row = 2; app.PxlPerCmXLabel.Layout.Column = [3 4];
    app.PxlPerCmAvgLabel = uilabel(g, 'Text', 'avg: ?');
    app.PxlPerCmAvgLabel.Layout.Row = 2; app.PxlPerCmAvgLabel.Layout.Column = [5 6];
    app.XKcorrLabel = uilabel(g, 'Text', 'kcorr: ?');
    app.XKcorrLabel.Layout.Row = 2; app.XKcorrLabel.Layout.Column = [7 8];

    % Row 3: Exp type — '<New>' lets the user define a custom experiment.
    lblExp = uilabel(g, 'Text', 'Exp:');
    lblExp.Layout.Row = 3; lblExp.Layout.Column = 1;
    app.ExpTypeDropDown = uidropdown(g, ...
        'Items', {'Barnes','Novelty OF','BowlsOpenField','NOL','Holes Track','Odor Track', ...
                  'Freezing Track','New Track','Complex Context','OF_Obj','3DM','<New>'}, ...
        'Value', 'Barnes', ...
        'ValueChangedFcn', @(s, ~) onExpTypeChanged(app, s));
    app.ExpTypeDropDown.Layout.Row = 3; app.ExpTypeDropDown.Layout.Column = [2 8];

    % Sync enabled state of cm X field with chosen mode (1 line disables cm X).
    onCalibModeChanged(app);
end

function onExpTypeChanged(app, src)
    if ~strcmp(src.Value, '<New>'); return; end
    answer = inputdlg('New experiment name:', 'Experiment', 1, {'MyExp'});
    if isempty(answer); src.Value = src.Items{1}; return; end
    name = strtrim(answer{1});
    if isempty(name); src.Value = src.Items{1}; return; end
    items = src.Items;
    items{end+1} = name;
    src.Items = items;
    src.Value = name;
    app.status(sprintf('Added experiment type "%s"', name));
end

function onCalibModeChanged(app)
    mode = app.CalibModeDropDown.Value;
    app.DistanceXField.Enable = toOnOff(~strcmpi(mode, '1 line'));
end

function buildArenaPanel(app)
    % Round-5: split into two rows.
    %   Row 1: 4 yellow geometry toggles + flex spacer + INFO (right edge).
    %   Row 2: Pick mode + Pick arena + flex spacer + Clear (right edge).
    nGeom = 4;       % Polygon / Circle / Ellipse / O-maze
    g = uigridlayout(app.ArenaPanel, [2, nGeom + 2]);
    g.RowHeight = {28, 28};
    g.ColumnWidth = [repmat({'fit'}, 1, nGeom), {'1x'}, {55}];
    g.RowSpacing = 4;
    g.ColumnSpacing = 4;
    g.Padding = [4 4 4 4];

    geometries = {'Polygon', 'Circle', 'Ellipse', 'O-maze'};
    defaultArena = 'Ellipse';   % Barnes default
    app.ArenaGeometryButtons = cell(1, numel(geometries));
    for i = 1:numel(geometries)
        b = uibutton(g, 'state', 'Text', geometries{i}, ...
            'BackgroundColor', semanticColor('geometry'), ...
            'ValueChangedFcn', @(src, ~) onArenaGeometryToggle(app, src));
        b.Layout.Row = 1; b.Layout.Column = i;
        if strcmp(geometries{i}, defaultArena)
            b.Value = true;
            app.State.arenaGeometry = defaultArena;
        end
        app.ArenaGeometryButtons{i} = b;
    end
    % Row 1 INFO at the right edge
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Arena', helpArenaText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = nGeom + 2;

    % Row 2: pick mode | pick | clear, all left-aligned
    app.ArenaPickModeDropDown = uidropdown(g, ...
        'Items', {'shape', 'points'}, 'Value', 'points', ...
        'Tooltip', 'shape = drag-and-drop ROI; points = click vertices then ENTER');
    app.ArenaPickModeDropDown.Layout.Row = 2;
    app.ArenaPickModeDropDown.Layout.Column = 1;
    bArena = uibutton(g, 'Text', 'Pick arena', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) onPickArena(app));
    bArena.Layout.Row = 2; bArena.Layout.Column = 2;
    bClear = uibutton(g, 'Text', 'Clear', ...
        'BackgroundColor', [0.92 0.55 0.55], ...
        'Tooltip', 'Drop the arena mask (clears dependent zones too)', ...
        'ButtonPushedFcn', @(~,~) app.clearArena());
    bClear.Layout.Row = 2; bClear.Layout.Column = nGeom + 2;   % flush right
end

function buildObjectsPanelCompact(app)
    % Block 4: count label + Manage button + read-only mirror listbox.
    % The listbox is kept in sync with state.objects via refreshObjectsList.
    g = uigridlayout(app.ObjectsPanel, [3, 1]);
    g.RowHeight = {28, 28, '1x'};
    g.Padding = [4 4 4 4];
    g.RowSpacing = 4;
    app.ObjectsCountLabel = uilabel(g, ...
        'Text', '0 objects — click Manage to add/edit');
    bManage = uibutton(g, 'Text', 'Manage objects...', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.showObjectsManager());
    bManage.Layout.Row = 2; bManage.Layout.Column = 1;
    % R8.3: mirror listbox is now interactive — clicking a row
    % highlights that saved object in main preview.
    app.ObjectsMirrorListBox = uilistbox(g, 'Items', {}, ...
        'Multiselect', 'on', ...
        'ValueChangedFcn', @(~,~) app.onMirrorListBoxChanged());
    app.ObjectsMirrorListBox.Layout.Row = 3; app.ObjectsMirrorListBox.Layout.Column = 1;
end

function buildObjectsListIn(app, parent)
    % Listbox column (column 1) of the 3-column Objects Manager.
    g = uigridlayout(parent, [7, 2]);
    g.RowHeight = {'1x', 28, 28, 28, 28, 28, 28};
    g.ColumnWidth = {'1x', '1x'};
    g.Padding = [4 4 4 4];
    g.RowSpacing = 4;
    g.ColumnSpacing = 4;

    app.ObjectsListBox = uilistbox(g, 'Items', {}, ...
        'Multiselect', 'on', ...
        'ValueChangedFcn', @(~,evt) app.onObjectsListBoxChanged(evt));
    app.ObjectsListBox.Layout.Row = 1; app.ObjectsListBox.Layout.Column = [1 2];
    % Repopulate listbox if manager reopened with existing objects.
    if ~isempty(app.State.objects)
        items = arrayfun(@(o) sprintf('%s (%s)', o.type, o.geometry), ...
            app.State.objects, 'UniformOutput', false);
        app.ObjectsListBox.Items = items;
        idx = app.getSelectedObjectIdx();
        app.UpdatingListboxFromState = true;
        cleaner = onCleanup(@() app.resetListboxFlag()); %#ok<NASGU>
        if ~isempty(idx)
            app.ObjectsListBox.Value = items(idx);
        end
    end

    bRemove = uibutton(g, 'Text', 'Remove', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.removeSelectedObject());
    bRemove.Layout.Row = 2; bRemove.Layout.Column = 1;
    bReplace = uibutton(g, 'Text', 'Replace', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.replaceSelectedObject());
    bReplace.Layout.Row = 2; bReplace.Layout.Column = 2;

    bRename = uibutton(g, 'Text', 'Rename', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.renameSelectedObject());
    bRename.Layout.Row = 3; bRename.Layout.Column = 1;
    bDelAll = uibutton(g, 'Text', 'Delete all', ...
        'BackgroundColor', [0.92 0.55 0.55], ...
        'ButtonPushedFcn', @(~,~) app.deleteAllObjects());
    bDelAll.Layout.Row = 3; bDelAll.Layout.Column = 2;

    % Class assignment (row 4 label + 5 field+button)
    lblClass = uilabel(g, 'Text', 'Class:');
    lblClass.Layout.Row = 4; lblClass.Layout.Column = 1;
    app.ObjectClassField = uieditfield(g, 'Value', '');
    app.ObjectClassField.Layout.Row = 4; app.ObjectClassField.Layout.Column = 2;
    bAssign = uibutton(g, 'Text', 'Assign to selected', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.assignClassToSelected());
    bAssign.Layout.Row = 5; bAssign.Layout.Column = [1 2];

    % Copy x N (row 6 label+field)
    lblCopy = uilabel(g, 'Text', 'Copy N:');
    lblCopy.Layout.Row = 6; lblCopy.Layout.Column = 1;
    app.CopyNField = uieditfield(g, 'numeric', 'Value', 5, ...
        'Limits', [1 20], 'RoundFractionalValues', 'on');
    app.CopyNField.Layout.Row = 6; app.CopyNField.Layout.Column = 2;

    % Row 7: Copy x N button + Order by Barnes
    bCopyN = uibutton(g, 'Text', 'Copy x N', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.copyObjectsN());
    bCopyN.Layout.Row = 7; bCopyN.Layout.Column = 1;
    bOrder = uibutton(g, 'Text', 'Order Barnes', ...
        'BackgroundColor', semanticColor('action'), ...
        'Tooltip', 'Renumber objects CW around arena center from selected target', ...
        'ButtonPushedFcn', @(~,~) app.orderObjectsBarnes());
    bOrder.Layout.Row = 7; bOrder.Layout.Column = 2;
end

function buildObjectsPickIn(app, parent)
    % Preview & pick column (column 2) of the 3-column Objects Manager.
    g = uigridlayout(parent, [4, 1]);
    g.RowHeight = {36, '1x', 30, 40};
    g.Padding = [4 4 4 4];
    g.RowSpacing = 2;

    % --- Toolbar row ---
    tb = uigridlayout(g, [1, 8]);
    tb.Layout.Row = 1;
    tb.RowHeight = {28};
    tb.ColumnWidth = {'fit', 'fit', 'fit', 90, 100, 105, 105, '1x'};
    tb.ColumnSpacing = 4;
    tb.Padding = [0 0 0 0];

    geometries = {'Polygon', 'Circle', 'Ellipse'};
    defaultObjGeom = 'Circle';   % Barnes default
    app.ObjectGeometryButtons = cell(1, numel(geometries));
    for i = 1:numel(geometries)
        b = uibutton(tb, 'state', 'Text', geometries{i}, ...
            'BackgroundColor', semanticColor('geometry'), ...
            'ValueChangedFcn', @(src, ~) onObjectGeometryToggle(app, src));
        b.Layout.Row = 1; b.Layout.Column = i;
        if strcmp(geometries{i}, defaultObjGeom)
            b.Value = true;
            app.State.objectGeometry = defaultObjGeom;
        end
        app.ObjectGeometryButtons{i} = b;
    end

    app.ObjectPickModeDropDown = uidropdown(tb, ...
        'Items', {'shape', 'points'}, 'Value', 'shape', ...
        'Tooltip', 'shape = drag-and-drop ROI; points = click vertices then ENTER');
    app.ObjectPickModeDropDown.Layout.Row = 1; app.ObjectPickModeDropDown.Layout.Column = 4;

    bAdd = uibutton(tb, 'Text', '+ Add shape', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.addPendingShape());
    bAdd.Layout.Row = 1; bAdd.Layout.Column = 5;

    bCommit = uibutton(tb, 'Text', 'Commit pending', ...
        'BackgroundColor', [0.7 1 0.7], ...
        'ButtonPushedFcn', @(~,~) app.commitPendingShapes());
    bCommit.Layout.Row = 1; bCommit.Layout.Column = 6;

    bCancel = uibutton(tb, 'Text', 'Cancel pending', ...
        'BackgroundColor', [1 0.85 0.85], ...
        'ButtonPushedFcn', @(~,~) app.cancelPendingShapes());
    bCancel.Layout.Row = 1; bCancel.Layout.Column = 7;

    % --- Preview axes ---
    axParent = uipanel(g, 'BorderType', 'none');
    axParent.Layout.Row = 2;
    axGrid = uigridlayout(axParent, [1, 1]);
    axGrid.Padding = [0 0 0 0];
    app.ManagerAxes = uiaxes(axGrid);
    app.ManagerAxes.XTick = []; app.ManagerAxes.YTick = [];

    % --- Status bar ---
    app.ManagerStatusLabel = uilabel(g, 'Text', 'Ready. Pick geometry then click + Add shape.');
    app.ManagerStatusLabel.Layout.Row = 3;

    % --- Finish button (row 4) ---
    bFinish = uibutton(g, 'Text', 'Finish (commit all to preset)', ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.4 0.85 0.4], ...
        'ButtonPushedFcn', @(~,~) app.finishManager());
    bFinish.Layout.Row = 4; bFinish.Layout.Column = 1;

    % Initialize pending state
    app.PendingShapeHandles    = {};
    app.PendingShapeGeometries = {};

    % Initial render
    app.refreshManagerPreview();
end

function onArenaGeometryToggle(app, src)
    onGeometryToggle(app.ArenaGeometryButtons, src, @(g) setfield(app.State, 'arenaGeometry', g));
    app.State.arenaGeometry = src.Text;   % redundant safety: store directly
end

function onObjectGeometryToggle(app, src)
    onGeometryToggle(app.ObjectGeometryButtons, src, @(g) setfield(app.State, 'objectGeometry', g));
    app.State.objectGeometry = src.Text;
end

function onGeometryToggle(buttons, src, ~)
    % Exclusive toggle group: when one is turned on, the others go off.
    % If user tries to toggle the active one off, snap it back on (must
    % always have a selection).
    if ~src.Value
        src.Value = true;
        return;
    end
    for k = 1:numel(buttons)
        if buttons{k} ~= src
            buttons{k}.Value = false;
        end
    end
end

function buildZonesPanel(app)
    g = uigridlayout(app.ZonesPanel, [6 6]);
    g.RowHeight = {28, 28, 28, 28, 28, 28};
    g.ColumnWidth = {'fit', 50, 'fit', 90, '1x', 60};
    g.ColumnSpacing = 4;

    lblStrat = uilabel(g, 'Text', 'Strategy:');
    lblStrat.Layout.Row = 1; lblStrat.Layout.Column = 1;
    app.ZonesStrategyDropDown = uidropdown(g, ...
        'Items', {'corners-walls-center', 'strips', 'circle', 'circle-rings', 'circle-with-center', 'none'}, ...
        'Value', 'circle', ...
        'ValueChangedFcn', @(~,~) onZoneStrategyChanged(app));
    app.ZonesStrategyDropDown.Layout.Row = 1; app.ZonesStrategyDropDown.Layout.Column = [2 4];
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Zones', helpZonesText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = 6;

    lblWall = uilabel(g, 'Text', 'Wall:');
    lblWall.Layout.Row = 2; lblWall.Layout.Column = 1;
    app.WallWidthField = uieditfield(g, 'numeric', 'Value', 15, 'Limits', [0, Inf]);
    app.WallWidthField.Layout.Row = 2; app.WallWidthField.Layout.Column = 2;
    lblMid = uilabel(g, 'Text', 'Middle:');
    lblMid.Layout.Row = 2; lblMid.Layout.Column = 3;
    app.MiddleWidthField = uieditfield(g, 'numeric', 'Value', 20, 'Limits', [0.1, Inf]);
    app.MiddleWidthField.Layout.Row = 2; app.MiddleWidthField.Layout.Column = 4;

    lblN = uilabel(g, 'Text', 'Strips:');
    lblN.Layout.Row = 3; lblN.Layout.Column = 1;
    app.NumStripsField = uieditfield(g, 'numeric', 'Value', 3, 'Limits', [1, 50]);
    app.NumStripsField.Layout.Row = 3; app.NumStripsField.Layout.Column = 2;
    lblDir = uilabel(g, 'Text', 'Dir:');
    lblDir.Layout.Row = 3; lblDir.Layout.Column = 3;
    app.StripDirDropDown = uidropdown(g, 'Items', {'horizontal','vertical'});
    app.StripDirDropDown.Layout.Row = 3; app.StripDirDropDown.Layout.Column = 4;
    lblCtrDiam = uilabel(g, 'Text', 'Center diameter, cm:');
    lblCtrDiam.Layout.Row = 3; lblCtrDiam.Layout.Column = 5;
    app.CenterDiameterCmField = uieditfield(g, 'numeric', 'Value', 20, ...
        'Limits', [0.1, Inf]);
    app.CenterDiameterCmField.Layout.Row = 3; app.CenterDiameterCmField.Layout.Column = 6;

    lblObjZone = uilabel(g, 'Text', 'Obj zone:');
    lblObjZone.Layout.Row = 4; lblObjZone.Layout.Column = 1;
    app.ObjectZoneWidthField = uieditfield(g, 'numeric', 'Value', 4, 'Limits', [0, Inf]);
    app.ObjectZoneWidthField.Layout.Row = 4; app.ObjectZoneWidthField.Layout.Column = 2;
    lblCorners = uilabel(g, 'Text', 'Corners:');
    lblCorners.Layout.Row = 4; lblCorners.Layout.Column = 3;
    app.CornerTypeDropDown = uidropdown(g, ...
        'Items', {'round', 'square'}, 'Value', 'round', ...
        'Tooltip', 'round = Manhattan-style nearest-corner; square = perpendiculars from corner sides to opposite walls');
    app.CornerTypeDropDown.Layout.Row = 4; app.CornerTypeDropDown.Layout.Column = 4;

    % Buttons in their own sub-grid so each is sized to its text.
    % Round-5: Clear pushed to the right edge, painted in the same bright
    % rose as other delete-style buttons.
    btnPanel = uipanel(g, 'BorderType', 'none');
    btnPanel.Layout.Row = 5; btnPanel.Layout.Column = [1 6];
    bg = uigridlayout(btnPanel, [1, 4]);
    bg.RowHeight = {28};
    bg.ColumnWidth = {'fit', 'fit', '1x', 'fit'};
    bg.Padding = [0 0 0 0];
    bg.ColumnSpacing = 4;
    bPreview = uibutton(bg, 'Text', 'Preview', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.previewZones());
    bPreview.Layout.Row = 1; bPreview.Layout.Column = 1;
    bAdd = uibutton(bg, 'Text', 'Add to set', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.addZones());
    bAdd.Layout.Row = 1; bAdd.Layout.Column = 2;
    bClear = uibutton(bg, 'Text', 'Clear zones', ...
        'BackgroundColor', [0.92 0.55 0.55], ...
        'ButtonPushedFcn', @(~,~) app.clearZones());
    bClear.Layout.Row = 1; bClear.Layout.Column = 4;

    app.ZonesCountLabel = uilabel(g, 'Text', 'Added: -');
    app.ZonesCountLabel.Layout.Row = 6; app.ZonesCountLabel.Layout.Column = [1 6];

    onZoneStrategyChanged(app);
end

function buildSavePanel(app)
    g = uigridlayout(app.SavePanel, [1 5]);
    g.RowHeight = {28};
    g.ColumnWidth = {'fit', 'fit', '1x', 90, 60};
    g.ColumnSpacing = 4;
    bSave = uibutton(g, 'Text', 'Save preset', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.savePreset());
    bSave.Layout.Row = 1; bSave.Layout.Column = 1;
    app.PlotAllCheckbox = uicheckbox(g, 'Text', 'plot all zones', 'Value', false);
    app.PlotAllCheckbox.Layout.Row = 1; app.PlotAllCheckbox.Layout.Column = 2;
    bClearAll = uibutton(g, 'Text', 'Clear All', ...
        'BackgroundColor', [0.92 0.55 0.55], ...
        'FontWeight', 'bold', ...
        'Tooltip', 'Wipe arena, objects and zones (paths and calibration kept)', ...
        'ButtonPushedFcn', @(~,~) app.clearAll());
    bClearAll.Layout.Row = 1; bClearAll.Layout.Column = 4;
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Save', helpSaveText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = 5;
end

function buildAutoDetectControlsIn(app, parent)
    % Build auto-detect controls inside `parent` (uipanel in manager window).
    % Rows: 1=Mode, 2=Algorithm, 3=Sensitivity, 4=Neighborhood,
    %       5=MinArea, 6=MaxArea, 7=Radius range, 8=StartFrom, 9=buttons, 10=INFO
    ag = uigridlayout(parent, [10, 3]);
    ag.RowHeight = repmat({28}, 1, 10);
    ag.ColumnWidth = {180, '1x', 'fit'};

    % Row 1: Mode dropdown
    lblMode = uilabel(ag, 'Text', 'Mode:');
    lblMode.Layout.Row = 1; lblMode.Layout.Column = 1;
    app.AutoModeDropdown = uidropdown(ag, ...
        'Items', {'free-form', 'all-circles', 'all-polygons', 'all-ellipses'}, ...
        'Value', 'all-circles', ...
        'ValueChangedFcn', @(~,~) app.updateAutoDetectEnableState());
    app.AutoModeDropdown.Layout.Row = 1; app.AutoModeDropdown.Layout.Column = 2;

    % Row 2: Algorithm
    lblAlg = uilabel(ag, 'Text', 'Algorithm (circles):');
    lblAlg.Layout.Row = 2; lblAlg.Layout.Column = 1;
    app.AutoAlgorithmDropdown = uidropdown(ag, ...
        'Items', {'threshold', 'hough'}, 'Value', 'threshold', ...
        'ValueChangedFcn', @(~,~) app.updateAutoDetectEnableState());
    app.AutoAlgorithmDropdown.Layout.Row = 2; app.AutoAlgorithmDropdown.Layout.Column = 2;

    % Row 3: Sensitivity slider + live value label
    lblSens = uilabel(ag, 'Text', 'Sensitivity:');
    lblSens.Layout.Row = 3; lblSens.Layout.Column = 1;
    sensSub = uigridlayout(ag, [1, 2]);
    sensSub.Layout.Row = 3; sensSub.Layout.Column = 2;
    sensSub.ColumnWidth = {'1x', 50};
    sensSub.Padding = [0 0 0 0];
    sensSub.ColumnSpacing = 4;
    app.AutoSensitivitySlider = uislider(sensSub, 'Limits', [0 1], 'Value', 0.75, ...
        'ValueChangingFcn', @(~,evt) app.onSensitivityChanging(evt));
    app.AutoSensitivityValueLabel = uilabel(sensSub, 'Text', '0.75');

    % Row 4: Neighborhood (moved up near Sensitivity)
    lblNh = uilabel(ag, 'Text', 'Neighborhood, cm:');
    lblNh.Layout.Row = 4; lblNh.Layout.Column = 1;
    app.AutoNeighborhoodField = uieditfield(ag, 'numeric', 'Value', 5, 'Limits', [0 100]);
    app.AutoNeighborhoodField.Layout.Row = 4; app.AutoNeighborhoodField.Layout.Column = 2;

    % Row 5: Min area
    lblMin = uilabel(ag, 'Text', 'Min area, cm^2:');
    lblMin.Layout.Row = 5; lblMin.Layout.Column = 1;
    app.AutoMinAreaField = uieditfield(ag, 'numeric', 'Value', 1, 'Limits', [0 1e6]);
    app.AutoMinAreaField.Layout.Row = 5; app.AutoMinAreaField.Layout.Column = 2;

    % Row 6: Max area (default 100 cm^2)
    lblMax = uilabel(ag, 'Text', 'Max area, cm^2:');
    lblMax.Layout.Row = 6; lblMax.Layout.Column = 1;
    app.AutoMaxAreaField = uieditfield(ag, 'numeric', 'Value', 100, 'Limits', [0 1e6]);
    app.AutoMaxAreaField.Layout.Row = 6; app.AutoMaxAreaField.Layout.Column = 2;

    % Row 7: Radius range in cm (default 2..7; converted to px in runAutoDetect)
    lblR = uilabel(ag, 'Text', 'Radius range, cm:');
    lblR.Layout.Row = 7; lblR.Layout.Column = 1;
    rGrid = uigridlayout(ag, [1, 2]);
    rGrid.Layout.Row = 7; rGrid.Layout.Column = 2;
    rGrid.Padding = [0 0 0 0];
    app.AutoRadiusMinField = uieditfield(rGrid, 'numeric', 'Value', 2);
    app.AutoRadiusMaxField = uieditfield(rGrid, 'numeric', 'Value', 7);

    % Row 8: Start numbering
    lblStart = uilabel(ag, 'Text', 'Start numbering from:');
    lblStart.Layout.Row = 8; lblStart.Layout.Column = 1;
    app.AutoStartFromField = uieditfield(ag, 'numeric', 'Value', 1, ...
        'Limits', [1 1e6], 'RoundFractionalValues', 'on');
    app.AutoStartFromField.Layout.Row = 8; app.AutoStartFromField.Layout.Column = 2;

    % Row 9: Action buttons (Auto-detect, Commit, Align radii)
    btnGrid = uigridlayout(ag, [1, 3]);
    btnGrid.Layout.Row = 9; btnGrid.Layout.Column = [1 3];
    btnGrid.ColumnWidth = {'1x', '1x', '1x'};
    btnGrid.Padding = [0 0 0 0];
    uibutton(btnGrid, 'Text', 'Auto-detect', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.runAutoDetect());
    uibutton(btnGrid, 'Text', 'Commit', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.commitAutoDetected());
    uibutton(btnGrid, 'Text', 'Align radii', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.alignDetectedRadii());

    % Row 10: INFO button (bottom, spanning all columns)
    bInfo = uibutton(ag, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Auto-detect', helpAutoDetectText()));
    bInfo.Layout.Row = 10; bInfo.Layout.Column = [1 3];

    % Initialize conditional enable state
    app.updateAutoDetectEnableState();
end

% buildStatusPanel removed — status now goes to command-line log only.

% =================== Callbacks ============================================

function onZoneStrategyChanged(app)
    s = app.ZonesStrategyDropDown.Value;
    app.WallWidthField.Enable         = enableIfAny(s, {'corners-walls-center', 'circle', 'circle-rings', 'circle-with-center'});
    app.MiddleWidthField.Enable       = enableIfAny(s, {'circle-rings'});
    app.NumStripsField.Enable         = enableIfAny(s, {'strips'});
    app.StripDirDropDown.Enable       = enableIfAny(s, {'strips'});
    app.CenterDiameterCmField.Enable  = enableIfAny(s, {'circle-with-center'});
    % R12.2: corners only exist for the square arena strategy.
    app.CornerTypeDropDown.Enable     = enableIfAny(s, {'corners-walls-center'});
    % R12.3: ObjectZone width is always editable -- it's a global
    % setting that applies whenever savedObjects are present, and
    % users want to set the default *before* committing objects.
    app.ObjectZoneWidthField.Enable   = 'on';
end

function v = enableIfAny(s, list)
    v = toOnOff(any(strcmp(s, list)));
end

function s = toOnOff(b)
    if b; s = 'on'; else; s = 'off'; end
end

function onCalibrateChoose(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    mode = '4 points';
    if ~isempty(app.CalibModeDropDown); mode = app.CalibModeDropDown.Value; end
    fh = figure('Name', sprintf('Calibration (%s)', mode));
    cleanup = onCleanup(@() closeIfValid(fh));
    ax = axes(fh); imshow(app.State.frame, 'Parent', ax); hold(ax, 'on');
    if strcmpi(mode, '2 lines')
        % Two interactive lines. Only the axis-projection length is used:
        % the Y line contributes abs(dy), the X line contributes abs(dx).
        title(ax, 'Draw the Y reference line (vertical) — drag, then double-click', 'Interpreter', 'none');
        hY = drawline(ax);
        wait(hY);
        if ~isvalid(hY); clear cleanup; return; end
        posY = hY.Position;   % 2x2 [x1 y1; x2 y2]
        title(ax, 'Draw the X reference line (horizontal) — drag, then double-click', 'Interpreter', 'none');
        hX = drawline(ax);
        wait(hX);
        if ~isvalid(hX); clear cleanup; return; end
        posX = hX.Position;
        % Pack as 4 points so pixelsPerCm picks up Y from rows 1-2 (vertical
        % distance) and X from rows 3-4 (horizontal distance).
        app.State.calibPoints = [ ...
            posY(1, 1), posY(1, 2); ...
            posY(2, 1), posY(2, 2); ...
            posX(1, 1), posX(1, 2); ...
            posX(2, 1), posX(2, 2)];
        clear cleanup;
        app.status('Got 2 calibration lines; now click "Compute"');
    elseif strcmpi(mode, '1 line')
        title(ax, 'Draw a reference line, then click "Compute"', 'Interpreter', 'none');
        hL = drawline(ax);
        wait(hL);
        if ~isvalid(hL); clear cleanup; return; end
        P = hL.Position;
        % Store only the 2 endpoints (2x2). onCalibrateCompute handles the
        % 1-line branch directly without routing through pixelsPerCm.
        app.State.calibPoints = P;   % 2x2 [x1 y1; x2 y2]
        clear cleanup;
        app.status('Got 1 calibration line; set total length in "cm Y" and click "Compute"');
    else
        title(ax, 'Click 4 points: Y-pair (1, 2), then X-pair (3, 4)', 'Interpreter', 'none');
        [xPts, yPts] = ginput(4);
        app.State.calibPoints = [xPts(:), yPts(:)];
        clear cleanup;
        app.status(sprintf('Got %d calibration points; now click "Compute"', size(app.State.calibPoints,1)));
    end
    app.refocus();
end

function onCalibrateCompute(app)
    if isempty(app.State.calibPoints)
        app.status('Click "Choose" first');
        return;
    end
    mode = '4 points';
    if ~isempty(app.CalibModeDropDown); mode = app.CalibModeDropDown.Value; end

    if strcmpi(mode, '1 line')
        % Direct compute: no pixelsPerCm call — use Euclidean length directly.
        P = app.State.calibPoints;
        if size(P, 1) < 2; app.status('Need a 2-point line; click "Choose" first'); return; end
        dxPx = P(2, 1) - P(1, 1);
        dyPx = P(2, 2) - P(1, 2);
        lengthPx = sqrt(dxPx^2 + dyPx^2);
        totalCm = app.DistanceYField.Value;
        if totalCm <= 0; app.status('Length must be > 0'); return; end
        pxlPerCm = lengthPx / totalCm;
        % Derive cm legs proportionally (for status display only).
        dxCm = totalCm * abs(dxPx) / lengthPx;
        dyCm = totalCm * abs(dyPx) / lengthPx;
        % Uniform scaling: X = Y = pxlPerCm, kcorr = 1.
        app.setPixelsPerCm(pxlPerCm, 'Y', pxlPerCm, 'X', pxlPerCm, 'KCorr', 1);
        app.status(sprintf( ...
            'Calibrated (1 line): pxlPerCm=%.3f | legs px [dx=%.1f dy=%.1f] cm [dx=%.2f dy=%.2f] | total %.1f px / %.1f cm', ...
            pxlPerCm, dxPx, dyPx, dxCm, dyCm, lengthPx, totalCm));
        return;
    end

    % 4-point / 2-line path: need exactly 4 stored points.
    if size(app.State.calibPoints, 1) < 4
        app.status('Click "Choose" first (need 4 points)');
        return;
    end
    dY = app.DistanceYField.Value;
    dX = app.DistanceXField.Value;
    [pxlAvg, kcorr, pxlY, pxlX, ~] = sphynx.preset.pixelsPerCm(app.State.frame, ...
        'Points', app.State.calibPoints, ...
        'DistancesCm', [dY, dX]);
    % Always pass actual Y and X so the labels show the raw measurements
    % even when kcorr collapses to 1 (within threshold).
    app.setPixelsPerCm(pxlAvg, 'Y', pxlY, 'X', pxlX, 'KCorr', kcorr);
    app.status(sprintf('Calibrated (%s): avg=%.2f, Y=%.2f, X=%.2f, kcorr=%.3f', ...
        mode, pxlAvg, pxlY, pxlX, kcorr));
end


function onPickArena(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.State.arenaGeometry;
    pickMode = 'shape';
    if ~isempty(app.ArenaPickModeDropDown)
        pickMode = app.ArenaPickModeDropDown.Value;
    end
    try
        arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
            'PickMode', pickMode);
        app.State.arena = arena;
        app.applog('info', 'Arena: %s OK', geometry);
        app.refreshPreview();
        onZoneStrategyChanged(app);
        app.refreshMoveTargets();
        sphynx.util.log('info', '[App] arena geometry=%s', geometry);
        app.refocus();
    catch ME
        app.status(sprintf('Arena failed: %s', ME.message));
    end
end

function onAddObject(app)
    % LEGACY: superseded by addPendingShape in Manager (round 3).
    % Kept as fallback; no longer reachable from main panel.
    % Loop adding the same object until the user confirms it (Yes) or
    % asks to delete it. "No (redo)" pops the bad object first so the
    % old mask is NOT shown on preview while the user re-picks.
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.State.objectGeometry;
    pickMode = 'shape';
    if ~isempty(app.ObjectPickModeDropDown)
        pickMode = app.ObjectPickModeDropDown.Value;
    end
    while true
        try
            obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
                'PickMode', pickMode, ...
                'ExistingObjects', app.State.objects, ...
                'ExistingArena', app.State.arena);
            obj.type = sprintf('object%d', numel(app.State.objects) + 1);
            if isempty(app.State.objects)
                app.State.objects = obj;
            else
                app.State.objects(end+1) = obj;
            end
            app.refreshObjectsList();
            app.refreshPreview();
            onZoneStrategyChanged(app);
            app.refreshMoveTargets();
            sphynx.util.log('info', '[App] object %s added geometry=%s', obj.type, geometry);
            app.refocus();
            choice = uiconfirm(app.Figure, ...
                sprintf('Is %s correct?', obj.type), 'Confirm object', ...
                'Options', {'Yes', 'No (redo)', 'No (delete)'}, ...
                'DefaultOption', 1, 'CancelOption', 2);
            switch choice
                case 'Yes'
                    return;
                case 'No (redo)'
                    % Drop the just-added object so its mask leaves the
                    % preview before the next picker opens.
                    app.State.objects(end) = [];
                    app.refreshObjectsList();
                    app.refreshPreview();
                    sphynx.util.log('info', '[App] redoing %s', obj.type);
                    continue;
                case 'No (delete)'
                    app.State.objects(end) = [];
                    app.refreshObjectsList();
                    app.refreshPreview();
                    onZoneStrategyChanged(app);
                    sphynx.util.log('info', '[App] object discarded');
                    return;
            end
        catch ME
            app.status(sprintf('Object failed: %s', ME.message));
            return;
        end
    end
end

% =================== Helpers ==============================================

function pickDirAndApply(app, methodName)
    startDir = pickStart(app);
    d = uigetdir(startDir, 'Select directory');
    if isequal(d, 0); app.refocus(); return; end
    app.(methodName)(d);
    app.refocus();
end

function pickVideoStart(app)
    startDir = pickStart(app);
    [f, p] = uigetfile({'*.mp4;*.avi;*.mov', 'Video files'}, 'Select video', startDir);
    if isequal(f, 0); app.refocus(); return; end
    app.setVideo(fullfile(p, f));
    app.refocus();
end

function pickPresetStart(app)
    startDir = pickStart(app);
    [f, p] = uigetfile({'*.mat', 'Preset .mat'}, 'Select preset', startDir);
    if isequal(f, 0); app.refocus(); return; end
    app.State.presetPath = fullfile(p, f);
    app.PresetPathField.Value = app.State.presetPath;
    preset = sphynx.io.readPreset(app.State.presetPath);

    % Calibration — pxl/cm and the cm Y / cm X distances the user typed
    if isfield(preset.Options, 'pxl2sm')
        kcorr = ifNaN(getOptField(preset.Options, 'x_kcorr'), 1);
        app.setPixelsPerCm(preset.Options.pxl2sm, 'Y', preset.Options.pxl2sm, ...
            'X', preset.Options.pxl2sm / kcorr, 'KCorr', kcorr);
    end
    if isfield(preset.Options, 'DistanceYCm') && ~isempty(preset.Options.DistanceYCm)
        app.DistanceYField.Value = preset.Options.DistanceYCm;
    end
    if isfield(preset.Options, 'DistanceXCm') && ~isempty(preset.Options.DistanceXCm)
        app.DistanceXField.Value = preset.Options.DistanceXCm;
    end
    if isfield(preset.Options, 'ExperimentType') && ~isempty(preset.Options.ExperimentType)
        items = app.ExpTypeDropDown.Items;
        if ~ismember(preset.Options.ExperimentType, items)
            items{end+1} = preset.Options.ExperimentType;
            app.ExpTypeDropDown.Items = items;
        end
        app.ExpTypeDropDown.Value = preset.Options.ExperimentType;
    end

    % Frame size + GoodVideoFrame if no video has been loaded yet
    if isempty(app.State.frame) && isfield(preset.Options, 'GoodVideoFrame') ...
            && ~isempty(preset.Options.GoodVideoFrame)
        app.State.frame = preset.Options.GoodVideoFrame;
        if isfield(preset.Options, 'Width');     app.State.width = preset.Options.Width;     end
        if isfield(preset.Options, 'Height');    app.State.height = preset.Options.Height;    end
        if isfield(preset.Options, 'FrameRate'); app.State.frameRate = preset.Options.FrameRate; end
        if isfield(preset.Options, 'NumFrames'); app.State.numFrames = preset.Options.NumFrames; end
    end

    % Arena + objects from ArenaAndObjects struct array (element 1 = arena).
    % NOTE: assemble each entry by field-by-field assignment instead of
    % struct('field', value, ...). The latter expands cell-array values
    % into a struct ARRAY (e.g. when border_separate_x is a cell), which
    % would later make `app.State.arena.border_x` a comma-separated list
    % and break isempty(...) downstream.
    if isfield(preset, 'ArenaAndObjects') && ~isempty(preset.ArenaAndObjects)
        AAO = preset.ArenaAndObjects;
        % Arena
        if numel(AAO) >= 1 && strcmp(AAO(1).type, 'Arena')
            arenaS.type     = 'Arena';
            arenaS.geometry = AAO(1).geometry;
            arenaS.border_x = AAO(1).border_x;
            arenaS.border_y = AAO(1).border_y;
            arenaS.border_separate_x = getFieldOr(AAO(1), 'border_separate_x', {});
            arenaS.border_separate_y = getFieldOr(AAO(1), 'border_separate_y', {});
            arenaS.mask     = logical(AAO(1).maskfilled);
            app.State.arena = arenaS;
            % Sync the arena geometry toggle so the picker uses the right one
            app.State.arenaGeometry = AAO(1).geometry;
            for k = 1:numel(app.ArenaGeometryButtons)
                btn = app.ArenaGeometryButtons{k};
                btn.Value = strcmp(btn.Text, AAO(1).geometry);
            end
        end
        % Objects — assemble each one by field-by-field assignment too
        objs = struct('type', {}, 'geometry', {}, 'border_x', {}, ...
                      'border_y', {}, 'mask', {}, 'class', {});
        for k = 2:numel(AAO)
            o.type     = AAO(k).type;
            o.geometry = AAO(k).geometry;
            o.border_x = AAO(k).border_x;
            o.border_y = AAO(k).border_y;
            o.mask     = logical(AAO(k).maskfilled);
            o.class    = getFieldOr(AAO(k), 'class', '');  % backward-compat (S8)
            if isempty(objs)
                objs = o;
            else
                objs(end+1) = o; %#ok<AGROW>
            end
            clear o;
        end
        app.State.objects = objs;
        app.State.savedObjects = objs;  % draft model: preset load sets both
        app.ManagerSessionDirty = false;
        app.refreshObjectsList();
    end

    % Zones (already in the canonical {name, type, maskfilled} shape)
    if isfield(preset, 'Zones') && ~isempty(preset.Zones)
        app.State.zones = preset.Zones;
        if isfield(preset.Options, 'WallWidthCm')
            app.WallWidthField.Value = preset.Options.WallWidthCm;
        end
        if isfield(preset.Options, 'MiddleWidthCm')
            app.MiddleWidthField.Value = preset.Options.MiddleWidthCm;
        end
        if isfield(preset.Options, 'CenterDiameterCm')
            app.CenterDiameterCmField.Value = preset.Options.CenterDiameterCm;
        else
            app.CenterDiameterCmField.Value = 20;
        end
    end

    app.refreshMoveTargets();
    onZoneStrategyChanged(app);
    app.refreshPreview();
    app.refreshPreviewTitle();
    app.applog('info', 'Loaded preset: %s — arena=%s, %d object(s), %d zone(s)', ...
        f, ifempty(getFieldOr(app.State.arena, 'geometry', '<none>'), '<none>'), ...
        numel(app.State.objects), numel(app.State.zones));
    app.refocus();
end

function v = getFieldOr(s, name, fallback)
    if isstruct(s) && isfield(s, name); v = s.(name); else; v = fallback; end
end

function v = ifempty(x, fallback)
    if isempty(x); v = fallback; else; v = x; end
end

function startDir = pickStart(app)
    if ~isempty(app.State.projectRoot) && isfolder(app.State.projectRoot)
        startDir = app.State.projectRoot;
    else
        startDir = '';
    end
end

function Z = computeZonesFromUI(app)
    Z = struct('name', {}, 'type', {}, 'maskfilled', {});
    if isempty(app.State.arena)
        app.status('Define arena first');
        return;
    end
    try
        strategy = app.ZonesStrategyDropDown.Value;
        wallCm = app.WallWidthField.Value;
        switch strategy
            case 'corners-walls-center'
                cornerType = 'round';
                if ~isempty(app.CornerTypeDropDown)
                    cornerType = app.CornerTypeDropDown.Value;
                end
                Z = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                    'Strategy', 'corners-walls-center', ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'WallWidthCm', wallCm, ...
                    'CornerType', cornerType, ...
                    'CornerPoints', cornerPointsFromArena(app.State.arena));
            case 'strips'
                % Pass arena vertices when geometry is Polygon so strips
                % run parallel to the arena's sides (TODO #7).
                arenaVerts = [];
                if strcmp(app.State.arena.geometry, 'Polygon')
                    arenaVerts = arenaPolygonVertices(app.State.arena);
                end
                Z = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                    'Strategy', 'strips', ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'WallWidthCm', wallCm, ...
                    'NumStrips', app.NumStripsField.Value, ...
                    'StripDirection', app.StripDirDropDown.Value, ...
                    'ArenaVertices', arenaVerts);
            case 'circle'
                Z = sphynx.preset.buildZonesCircleWall(app.State.arena.mask, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'WallWidthCm', wallCm);
            case 'circle-rings'
                Z = sphynx.preset.buildZonesCircle(app.State.arena.mask, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'WallWidthCm', wallCm, ...
                    'MiddleWidthCm', app.MiddleWidthField.Value);
            case 'circle-with-center'
                Z = sphynx.preset.buildZonesCircleCenter(app.State.arena.mask, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'CenterDiameterCm', app.CenterDiameterCmField.Value, ...
                    'WallWidthCm', app.WallWidthField.Value);
            case 'none'
                Z = sphynx.preset.buildZonesSquare(app.State.arena.mask, 'Strategy', 'none');
        end
    catch ME
        app.status(sprintf('Zone build failed: %s', ME.message));
        Z = struct('name', {}, 'type', {}, 'maskfilled', {});
    end
end

function v = ifNaN(x, fallback)
    if isnan(x); v = fallback; else; v = x; end
end

function verts = arenaPolygonVertices(arena)
    % Recover the user's clicked corners from the dense outline.
    % border_separate_x is a cell array, one entry per arena side; the
    % first point of each side is a corner.
    if isfield(arena, 'border_separate_x') && ~isempty(arena.border_separate_x)
        n = numel(arena.border_separate_x);
        verts = zeros(n, 2);
        for k = 1:n
            verts(k, 1) = arena.border_separate_x{k}(1);
            verts(k, 2) = arena.border_separate_y{k}(1);
        end
    else
        verts = [arena.border_x(:), arena.border_y(:)];
    end
end

function v = getOptField(s, name)
    if isfield(s, name); v = s.(name); else; v = NaN; end
end

function pts = cornerPointsFromArena(arena)
    if ~isempty(arena.border_separate_x)
        pts = zeros(numel(arena.border_separate_x), 2);
        for k = 1:numel(arena.border_separate_x)
            pts(k, 1) = arena.border_separate_x{k}(1);
            pts(k, 2) = arena.border_separate_y{k}(1);
        end
    else
        pts = [];
    end
end

function drawZoneOutline(ax, z, color)
    if ~isfield(z, 'maskfilled'); return; end
    if isfield(z, 'type') && strcmp(z.type, 'point')
        if numel(z.maskfilled) >= 2
            plot(ax, z.maskfilled(1), z.maskfilled(2), 'o', ...
                'MarkerEdgeColor', color, 'MarkerFaceColor', color, 'MarkerSize', 8);
        end
        return;
    end
    if ~isnumeric(z.maskfilled) && ~islogical(z.maskfilled); return; end
    mask = logical(z.maskfilled);
    if ~any(mask(:)); return; end
    % Use without 'noholes' so ring-shaped masks (object Out zones) get
    % both outer and inner boundaries drawn.
    B = bwboundaries(mask);
    for k = 1:numel(B)
        b = B{k};
        if size(b, 1) < 3; continue; end
        plot(ax, b(:, 2), b(:, 1), '-', 'Color', color, 'LineWidth', 1.5);
    end
end

function drawZoneFilled(ax, z, color, alpha)
    % Per-pixel alpha overlay using image() + AlphaData, which handles
    % arbitrary topologies (rings, multi-component) correctly. patch
    % with bwboundaries fails for ring masks because 'noholes' fills
    % the hole; this approach sidesteps that.
    if ~isfield(z, 'maskfilled'); return; end
    if isfield(z, 'type') && strcmp(z.type, 'point')
        if numel(z.maskfilled) >= 2
            plot(ax, z.maskfilled(1), z.maskfilled(2), 'o', ...
                'MarkerEdgeColor', color, 'MarkerFaceColor', color, 'MarkerSize', 8);
        end
        return;
    end
    if ~isnumeric(z.maskfilled) && ~islogical(z.maskfilled); return; end
    mask = logical(z.maskfilled);
    if ~any(mask(:)); return; end
    [H, W] = size(mask);
    rgb = zeros(H, W, 3);
    rgb(:,:,1) = color(1);
    rgb(:,:,2) = color(2);
    rgb(:,:,3) = color(3);
    image(ax, rgb, 'AlphaData', double(mask) * alpha);
    % Outline (uses both outer and inner boundaries — correct for rings)
    B = bwboundaries(mask);
    for k = 1:numel(B)
        b = B{k};
        if size(b, 1) < 3; continue; end
        plot(ax, b(:, 2), b(:, 1), '-', 'Color', color, 'LineWidth', 1.0);
    end
end

function tIdx = currentTargetIdx(app)
    val = app.MoveTargetDropDown.Value;
    if strcmp(val, 'All')
        tIdx = -1;   % sentinel: arena + all objects
    elseif strcmp(val, 'Arena')
        if isempty(app.State.arena); tIdx = NaN; app.applog('warn','Arena not defined yet'); return; end
        tIdx = 0;
    else
        tIdx = find(strcmp({app.State.objects.type}, val), 1);
        if isempty(tIdx); tIdx = NaN; end
    end
end

function applyTransformToTarget(app, tIdx, translation, rotationDeg, sharedPivot)
    % SHAREDPIVOT (optional): when not empty, rotation uses this [x y] as
    % the pivot instead of the entity's own centroid. Used by tIdx==-1
    % ('All') so every child rotates around the same point — the arena
    % centroid — preserving relative positions (TODO #6 fix).
    if nargin < 5; sharedPivot = []; end
    if tIdx == -1
        % Compute a shared pivot once for the whole batch
        pivot = computeSharedPivot(app);
        if ~isempty(app.State.arena)
            applyTransformToTarget(app, 0, translation, rotationDeg, pivot);
        end
        for k = 1:numel(app.State.objects)
            applyTransformToTarget(app, k, translation, rotationDeg, pivot);
        end
        return;
    end
    if tIdx == 0
        ent = app.State.arena;
    else
        ent = app.State.objects(tIdx);
    end
    if isempty(ent); return; end
    if ~isempty(sharedPivot)
        cx = sharedPivot(1); cy = sharedPivot(2);
    else
        cx = mean(ent.border_x(:)); cy = mean(ent.border_y(:));
    end
    rad = deg2rad(rotationDeg);
    R = [cos(rad), -sin(rad); sin(rad), cos(rad)];
    bx = ent.border_x(:) - cx;
    by = ent.border_y(:) - cy;
    rot = R * [bx, by]';
    ent.border_x = reshape(rot(1, :)' + cx + translation(1), size(ent.border_x));
    ent.border_y = reshape(rot(2, :)' + cy + translation(2), size(ent.border_y));
    if isfield(ent, 'border_separate_x') && ~isempty(ent.border_separate_x)
        for s = 1:numel(ent.border_separate_x)
            sx = ent.border_separate_x{s}(:) - cx;
            sy = ent.border_separate_y{s}(:) - cy;
            r2 = R * [sx, sy]';
            ent.border_separate_x{s} = reshape(r2(1,:)' + cx + translation(1), size(ent.border_separate_x{s}));
            ent.border_separate_y{s} = reshape(r2(2,:)' + cy + translation(2), size(ent.border_separate_y{s}));
        end
    end
    if tIdx == 0
        app.State.arena = ent;
    else
        app.State.objects(tIdx) = ent;
    end
end

function pivot = computeSharedPivot(app)
    if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
        pivot = [mean(app.State.arena.border_x(:)), mean(app.State.arena.border_y(:))];
    elseif ~isempty(app.State.frame)
        [Hf, Wf, ~] = size(app.State.frame);
        pivot = [Wf/2, Hf/2];
    else
        pivot = [0, 0];
    end
end

function drawState(ax, S, drawZones)
    % Pure export function — draws arena, objects, and (optionally) zones.
    % C2: selectedIdx parameter removed; yellow overlay belongs only in
    % refreshPreviewAxes (the live preview), not in saved-plot exports.
    imshow(S.frame, 'Parent', ax);
    hold(ax, 'on');
    if drawZones && ~isempty(S.zones)
        cmap = colorPaletteForZones(numel(S.zones));
        for k = 1:numel(S.zones)
            drawZoneFilled(ax, S.zones(k), cmap(k,:), 0.22);
        end
    end
    if ~isempty(S.arena) && ~isempty(S.arena.border_x)
        plot(ax, S.arena.border_x(:), S.arena.border_y(:), 'k-', 'LineWidth', 2);
    end
    for k = 1:numel(S.objects)
        plot(ax, S.objects(k).border_x(:), S.objects(k).border_y(:), '-', ...
            'Color', [0 0.7 0], 'LineWidth', 1.5);
    end
    hold(ax, 'off');
end

function cmap = colorPaletteForZones(n)
    if n <= 0
        cmap = zeros(0,3);
        return;
    end
    base = [
        0.10 0.45 0.95;   % blue
        0.95 0.30 0.20;   % red
        0.20 0.70 0.30;   % green
        0.95 0.65 0.10;   % orange
        0.55 0.30 0.85;   % purple
        0.20 0.80 0.80;   % cyan
        0.85 0.20 0.65;   % magenta
        0.80 0.80 0.20;   % yellow-olive
    ];
    if n <= size(base, 1)
        cmap = base(1:n, :);
    else
        cmap = repmat(base, ceil(n / size(base,1)), 1);
        cmap = cmap(1:n, :);
    end
end

function s = sanitize(name)
    s = regexprep(name, '[^a-zA-Z0-9_-]', '_');
end

function closeIfValid(h)
    if ~isempty(h) && isvalid(h); close(h); end
end

function h = createPendingROI(ax, geom, pos)
    % Recreate a pending ROI on ax with known Position (after cla).
    switch geom
        case 'Circle'
            % pos for circle = [cx, cy, r] or center+radius struct — use center/radius
            % drawcircle Position is [cx, cy, r] but we store .Position as struct.
            % Safe fallback: create at default center derived from pos if numeric.
            if isstruct(pos)
                h = drawcircle(ax, 'Center', pos.Center, 'Radius', pos.Radius, ...
                    'Color', [0 0.6 0], 'LineWidth', 1);
            else
                h = drawcircle(ax, 'Color', [0 0.6 0], 'LineWidth', 1);
            end
        case 'Ellipse'
            if isstruct(pos)
                h = drawellipse(ax, 'Center', pos.Center, 'SemiAxes', pos.SemiAxes, ...
                    'RotationAngle', pos.RotationAngle, 'Color', [0 0.6 0], 'LineWidth', 1);
            else
                h = drawellipse(ax, 'Color', [0 0.6 0], 'LineWidth', 1);
            end
        otherwise  % Polygon
            if ~isempty(pos)
                h = drawpolygon(ax, 'Position', pos, 'Color', [0 0.6 0], 'LineWidth', 1);
            else
                h = drawpolygon(ax, 'Color', [0 0.6 0], 'LineWidth', 1);
            end
    end
end

% =================== Help text ============================================

function showHelp(title, text)
    msgbox(text, title, 'help', 'modal');
end

function Z = arenaCornerZones(arena)
    Z = struct('name', {}, 'type', {}, 'maskfilled', {});
    for c = 1:numel(arena.border_separate_x)
        Z(end+1).name = sprintf('arenacorner%d', c); %#ok<AGROW>
        Z(end).type = 'point';
        Z(end).maskfilled = [arena.border_separate_x{c}(1), arena.border_separate_y{c}(1)];
    end
end

function Z = objectCenterZones(objects)
    Z = struct('name', {}, 'type', {}, 'maskfilled', {});
    for k = 1:numel(objects)
        cx = mean(objects(k).border_x(:));
        cy = mean(objects(k).border_y(:));
        Z(end+1).name = sprintf('%s_center', lower(objects(k).type)); %#ok<AGROW>
        Z(end).type = 'point';
        Z(end).maskfilled = [cx, cy];
    end
end

function tag = composeStrategyTag(app)
    s = app.ZonesStrategyDropDown.Value;
    if strcmp(s, 'strips')
        tag = sprintf('strips_%s_%d', app.StripDirDropDown.Value, app.NumStripsField.Value);
    else
        tag = s;
    end
end

function autoSaveLayoutPlot(app, sessionDir, baseName)
    fh = figure('Visible', 'off', 'Position', [100 100 1000 750]);
    cleanup = onCleanup(@() closeIfValid(fh));
    ax = axes(fh);
    plotState = app.State;
    plotState.objects = app.State.savedObjects;  % use committed objects for plots
    drawState(ax, plotState, true);
    title(ax, sprintf('%s — combined layout', baseName), 'Interpreter', 'none');
    outPath = fullfile(sessionDir, sprintf('%s_layout.png', baseName));
    exportgraphics(ax, outPath);
    app.applog('info', 'saved plot %s', outPath);
end

function savePerZonePlots(app, sessionDir, baseName)
    if isempty(app.State.zones); return; end
    plotState = app.State;
    plotState.objects = app.State.savedObjects;  % use committed objects for plots
    for k = 1:numel(app.State.zones)
        z = app.State.zones(k);
        if isfield(z, 'type') && strcmp(z.type, 'point'); continue; end
        fh = figure('Visible', 'off', 'Position', [100 100 1000 750]);
        cleanup = onCleanup(@() closeIfValid(fh)); %#ok<NASGU>
        ax = axes(fh);
        drawState(ax, plotState, false);
        if (isnumeric(z.maskfilled) || islogical(z.maskfilled))
            hold(ax, 'on');
            drawZoneFilled(ax, z, [0 0.5 1], 0.35);
        end
        title(ax, sprintf('%s — zone: %s', baseName, z.name), 'Interpreter', 'none');
        outPath = fullfile(sessionDir, sprintf('%s_zone_%s.png', baseName, sanitize(z.name)));
        exportgraphics(ax, outPath);
        app.applog('info', 'saved plot %s', outPath);
        clear cleanup;
    end
end

function c = semanticColor(category)
    % Subdued pastel button-tinting by semantic role (~50% paler than v6).
    switch category
        case 'geometry'; c = [1.00, 0.99, 0.91];   % faint yellow  — selectors
        case 'action';   c = [1.00, 0.94, 0.93];   % faint rose    — do-something
        case 'info';     c = [0.92, 0.97, 0.96];   % faint teal    — INFO/help
        otherwise;       c = [0.97, 0.97, 0.97];   % default near-white
    end
end

function txt = helpCalibrationText()
    txt = {
        'Calibration: convert pixels to centimeters.';
        '';
        'Pick a mode in the dropdown next to "Choose":';
        '';
        '  4 points - click 4 points in this order:';
        '      1,2: Y-axis pair (top/bottom of vertical reference)';
        '      3,4: X-axis pair (left/right of horizontal reference)';
        '      Window closes after the 4th click.';
        '';
        '  2 lines - draw a Y line, DOUBLE-CLICK to confirm, then';
        '      draw an X line and DOUBLE-CLICK again. Each line';
        '      contributes its axis-projection length.';
        '';
        '  1 line - draw a single line of known length anywhere';
        '      and DOUBLE-CLICK to confirm. The full Euclidean';
        '      length is used; X = Y, kcorr = 1.';
        '      (cm Y field = total length in cm; cm X is ignored.)';
        '';
        'After choosing, enter the real cm distance(s) in cm Y / cm X';
        'and click "Compute". Results appear in row 2: pxl/cm Y, X,';
        'avg, and the X/Y correction factor (kcorr).';
        '';
        'For BARNES: 1 line is the default. Drag a line across the';
        'arena diameter, enter 92 cm in cm Y, click Compute.';
    };
end

function txt = helpArenaText()
    txt = {
        'Define the arena boundary on the current preview frame.';
        '';
        'Step 1 - geometry (yellow toggle row):';
        '   Polygon | Circle | Ellipse | O-maze';
        '';
        'Step 2 - pick mode:';
        '   shape  - drag/resize an interactive ROI directly on the';
        '            frame; DOUBLE-CLICK to confirm.';
        '   points - click points on the rim; press ENTER to fit.';
        '            (Circle: 3+ pts, Ellipse: 5+ pts,';
        '             O-maze: 3+ outer then 3+ inner).';
        '';
        'Step 3 - "Pick arena": opens a temp window with the frame.';
        'Step 4 - the arena outline appears in black on the preview.';
        '';
        'Clear drops the arena (and dependent zones).';
        '';
        'For BARNES: Ellipse + points (mark 5-8 points on the arena';
        'rim, ENTER to fit).';
    };
end

function txt = helpObjectsText()
    txt = {
        'Block 4 in the main window is a compact summary - click';
        '"Manage objects..." to open the Objects Manager.';
        '';
        'Objects Manager layout (3 columns):';
        '';
        '  LEFT  - the objects listbox + tools:';
        '     Remove / Replace / Rename / Delete all';
        '     Class field + "Assign to selected"';
        '     Copy x N (replicate selected; you place N copies)';
        '     Order Barnes (CW renumber around arena center from the';
        '       selected target; target keeps name "target")';
        '';
        '  CENTER - preview + manual picking:';
        '     Geometry row (Polygon/Circle/Ellipse) + pick mode';
        '       (shape = drag ROI; points = click vertices + ENTER)';
        '     "+ Add shape" - draws a new ROI in the manager preview;';
        '        for shape mode: DOUBLE-CLICK to confirm the ROI.';
        '     "Commit pending" - turns ALL pending ROIs into objects.';
        '     "Cancel pending"  - drops them.';
        '     FINISH (bright green, bottom) - commit working state';
        '        to the preset and close the manager. Until Finish,';
        '        nothing renders in the main window (draft model).';
        '';
        '  RIGHT - Auto-detect (see its own INFO):';
        '     Mode + Algorithm + sensitivity slider + area/radius';
        '     filters. "Auto-detect" runs detection (preview only).';
        '     "Commit" adds detected objects to the working list.';
        '     Manual and auto can be mixed in any order.';
        '';
        'Selection in the listbox is multi (Ctrl/Shift). Group';
        'rotate/translate via the "Move target" buttons in main.';
    };
end

function txt = helpZonesText()
    txt = {
        'Build spatial-zone masks based on the arena (and objects).';
        '';
        'Strategies:';
        '  corners-walls-center - square arena split into corner,';
        '       wall, and center zones. Wall (cm) = wall width.';
        '  strips - split arena into N equal-width strips.';
        '  circle - simplest: wall ring + center (everything else).';
        '       Wall (cm) = ring thickness. Barnes default.';
        '  circle-rings - concentric rings (wall + middle1.. + center)';
        '       for round arenas. Wall and Middle widths in cm.';
        '  circle-with-center - three zones for round arenas:';
        '       wall annulus + middle + center disc.';
        '  none - no spatial subdivision (only per-hole object zones).';
        '';
        '"Preview zones" shows the proposed partition on the preview';
        '(magenta) without committing.';
        '"Add to set" commits the previewed zones to the final set';
        '(blue). You can call it multiple times with different';
        'strategies to combine partitions.';
        '"Clear zones" removes every committed zone.';
        '';
        'Object zone (cm) is the inflated radius around each object';
        'that counts as object interaction. Field is enabled only';
        'when objects are committed (Finish in the manager).';
        '';
        'Implicit "outside-wall" 10 cm offset is always applied';
        'internally to wall/corner/center calculations (legacy';
        'default). It is not exposed in the UI.';
    };
end

function txt = helpSaveText()
    txt = {
        '"Save preset": writes <output_dir>/<videobase>_Preset.mat';
        'with Options + Zones + ArenaAndObjects in the legacy shape';
        '(consumed by both the legacy BehaviorAnalyzer.m and the';
        'new sphynx.pipeline.analyzeSession).';
        '';
        'Save also auto-writes <videobase>_layout.png - the combined';
        'preview (arena + committed objects + all committed zones).';
        '';
        'If the Objects Manager is still open with uncommitted edits,';
        'Save auto-finishes the draft first (= equivalent to clicking';
        'Finish in the manager).';
        '';
        'Check "plot all zones" to ALSO save one PNG per individual';
        'zone (<videobase>_zone_<name>.png).';
        '';
        'Clear All wipes arena/objects/zones (paths and calibration';
        'are kept).';
    };
end

function txt = helpAutoDetectText()
    txt = { ...
        'AUTO-DETECT OBJECTS — find objects inside the arena.', ...
        '', ...
        'Mode:', ...
        '  free-form     — any shape; each detected blob -> polygon outline.', ...
        '  all-circles   — every blob is fit to a circle (or via Hough).', ...
        '  all-polygons  — outlines reduced to polygons (~10 vertices).', ...
        '  all-ellipses  — ellipse fit using regionprops axes.', ...
        '', ...
        'Algorithm (for all-circles):', ...
        '  threshold — local adaptive threshold (adaptthresh)', ...
        '              + connected components inside arena.', ...
        '  hough     — Hough Circle Transform via imfindcircles.', ...
        '              Best for circular objects with clear edges.', ...
        '', ...
        'Sensitivity (0..1): higher = more detections, more false positives.', ...
        '  Threshold mode: passes to adaptthresh.', ...
        '  Hough mode: passes to imfindcircles Sensitivity.', ...
        '', ...
        'Neighborhood, cm: window size for local thresholding.', ...
        '  Smaller -> more locally adaptive (good for uneven lighting).', ...
        '  Larger -> more global. 0 = auto (MATLAB default).', ...
        '  Only used in threshold mode.', ...
        '', ...
        'Min/Max area, cm^2: filter detected blobs by area.', ...
        'Radius range, cm: only for Hough mode — search range for circles.', ...
        '', ...
        'Buttons:', ...
        '  Auto-detect    — runs detection, shows green dashed preview.', ...
        '  Commit         — accepts preview, adds objects to the list.', ...
        '  Align radii    — replace all detected circles with same radius', ...
        '                   (default = mean of detected; you can edit).', ...
        '', ...
        'For BARNES holes: try mode all-circles + algorithm hough,', ...
        'radius range 2..7 cm, sensitivity 0.9. Refine with Align radii.' ...
        };
end

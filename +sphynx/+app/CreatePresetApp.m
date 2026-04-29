classdef CreatePresetApp < handle
% CREATEPRESETAPP  Single-window preset builder for sphynx.
%
%   sphynx.app.CreatePresetApp() opens a uifigure-based two-tab editor:
%     Tab 1: Create Preset (full preset builder)
%     Tab 2: Analyze Session (placeholder for batch run, Pass E)
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
        TabAnalyze
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
        % Arena
        ArenaGeometryButtons      % cell array of state buttons (Polygon/Circle/Ellipse/O-maze)
        ArenaStatusLabel
        % Objects
        ObjectGeometryButtons     % cell array of state buttons (Polygon/Circle/Ellipse)
        ObjectsListBox
        % Zones
        ZonesStrategyDropDown
        WallWidthField
        MiddleWidthField
        NumStripsField
        StripDirDropDown
        ObjectZoneWidthField
        ZonesCountLabel
        % Save / plot
        PlotAllCheckbox
        % Preview
        PreviewAxes
        FrameIndexLabel
        % Status
        StatusBar
        % State
        State
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
                app.refreshPreview();
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
                    'Points', points);
                app.State.arena = arena;
                app.ArenaStatusLabel.Text = sprintf('Arena: %s OK', geometry);
                app.refreshPreview();
                onZoneStrategyChanged(app);   % object-zone field may change
                sphynx.util.log('info', '[App] arena geometry=%s npoints=%d', geometry, size(points,1));
            catch ME
                app.status(sprintf('Arena failed: %s', ME.message));
            end
        end

        function addObject(app, geometry, points)
            try
                obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, 'Points', points);
                obj.type = sprintf('Object%d', numel(app.State.objects) + 1);
                if isempty(app.State.objects)
                    app.State.objects = obj;
                else
                    app.State.objects(end+1) = obj;
                end
                app.refreshObjectsList();
                app.refreshPreview();
                onZoneStrategyChanged(app);
                sphynx.util.log('info', '[App] object %d added geometry=%s', numel(app.State.objects), geometry);
            catch ME
                app.status(sprintf('Object failed: %s', ME.message));
            end
        end

        function removeSelectedObject(app)
            if isempty(app.State.objects); return; end
            idx = find(strcmp(app.ObjectsListBox.Items, app.ObjectsListBox.Value), 1);
            if isempty(idx); return; end
            removed = app.State.objects(idx).type;
            app.State.objects(idx) = [];
            % Renumber remaining objects so their type labels stay sequential
            for k = 1:numel(app.State.objects)
                app.State.objects(k).type = sprintf('Object%d', k);
            end
            app.refreshObjectsList();
            app.refreshPreview();
            onZoneStrategyChanged(app);
            sphynx.util.log('info', '[App] removed %s; %d remain', removed, numel(app.State.objects));
        end

        function replaceSelectedObject(app)
            if isempty(app.State.objects); app.status('No object selected'); return; end
            idx = find(strcmp(app.ObjectsListBox.Items, app.ObjectsListBox.Value), 1);
            if isempty(idx); app.status('No object selected'); return; end
            geometry = app.State.objectGeometry;
            try
                obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry);
                obj.type = app.State.objects(idx).type;     % preserve label
                app.State.objects(idx) = obj;
                app.refreshObjectsList();
                app.refreshPreview();
                sphynx.util.log('info', '[App] replaced %s with new %s', obj.type, geometry);
                app.refocus();
            catch ME
                app.status(sprintf('Replace failed: %s', ME.message));
            end
        end

        function previewZones(app)
            % Build zones with current strategy+params and SHOW them on
            % preview, but do not commit to State.zones.
            Z = computeZonesFromUI(app);
            if isempty(Z); return; end
            % Include object zones in the preview too, so what user sees
            % is what will be committed
            if ~isempty(app.State.objects)
                Zobj = sphynx.preset.buildObjectZones(app.State.objects, ...
                    app.State.height, app.State.width, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'ZoneWidthCm', app.ObjectZoneWidthField.Value);
                Z = [Z, Zobj];
            end
            app.State.previewZones = Z;
            app.refreshPreview();
            app.status(sprintf('Previewing %d zones (%s)', numel(Z), app.ZonesStrategyDropDown.Value));
        end

        function addZones(app)
            Z = computeZonesFromUI(app);
            if isempty(Z); return; end
            % Also add per-object zones if objects are defined
            if ~isempty(app.State.objects)
                Zobj = sphynx.preset.buildObjectZones(app.State.objects, ...
                    app.State.height, app.State.width, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'ZoneWidthCm', app.ObjectZoneWidthField.Value);
                Z = [Z, Zobj];
            end
            if isempty(app.State.zones)
                app.State.zones = Z;
            else
                app.State.zones(end+1:end+numel(Z)) = Z;
            end
            app.State.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.refreshZonesCount();
            app.refreshPreview();
            sphynx.util.log('info', '[App] added %d zones (%s); total committed = %d', ...
                numel(Z), app.ZonesStrategyDropDown.Value, numel(app.State.zones));
            for k = 1:numel(Z)
                sphynx.util.log('info', '       zone[%d] = %s', numel(app.State.zones)-numel(Z)+k, Z(k).name);
            end
        end

        function clearZones(app)
            app.State.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.State.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.refreshZonesCount();
            app.refreshPreview();
            app.status('Cleared all zones');
        end

        function savePreset(app)
            if isempty(app.State.outDir); app.status('Set output dir'); return; end
            if isempty(app.State.arena); app.status('Define arena first'); return; end
            try
                Options = app.assembleOptions();
                ArenaAndObjects = app.assembleArenaAndObjects();
                Zones = app.State.zones;
                if isempty(Zones); Zones = struct('name',{},'type',{},'maskfilled',{}); end
                [~, baseName, ~] = fileparts(app.State.videoPath);
                if isempty(baseName); baseName = 'preset'; end
                outPath = fullfile(app.State.outDir, sprintf('%s_Preset.mat', baseName));
                save(outPath, 'Options', 'Zones', 'ArenaAndObjects');
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

            % Always: one combined plot (arena + objects + all zones)
            fh = figure('Visible', 'off', 'Position', [100 100 800 600]);
            cleanup1 = onCleanup(@() closeIfValid(fh));
            ax = axes(fh);
            drawState(ax, app.State, true);
            title(ax, sprintf('%s — combined layout', baseName), 'Interpreter', 'none');
            outPath = fullfile(app.State.outDir, sprintf('%s_layout.png', baseName));
            exportgraphics(ax, outPath);
            sphynx.util.log('info', '[App] saved plot %s', outPath);
            clear cleanup1;

            % Optional: one per zone
            if plotAll && ~isempty(app.State.zones)
                for k = 1:numel(app.State.zones)
                    fh2 = figure('Visible', 'off', 'Position', [100 100 800 600]);
                    cleanup2 = onCleanup(@() closeIfValid(fh2));
                    ax2 = axes(fh2);
                    drawState(ax2, app.State, false);
                    z = app.State.zones(k);
                    if (isnumeric(z.maskfilled) || islogical(z.maskfilled))
                        hold(ax2, 'on');
                        drawZoneFilled(ax2, z, [0 0.5 1], 0.25);
                    end
                    title(ax2, sprintf('%s — zone: %s', baseName, z.name), 'Interpreter', 'none');
                    outPath2 = fullfile(app.State.outDir, sprintf('%s_zone_%s.png', baseName, sanitize(z.name)));
                    exportgraphics(ax2, outPath2);
                    sphynx.util.log('info', '[App] saved plot %s', outPath2);
                    clear cleanup2;
                end
            end
            app.status(sprintf('Plots saved to %s', app.State.outDir));
        end

        function nextFrame(app)
            if isempty(app.State.videoPath); app.status('Load video first'); return; end
            try
                step = max(round(app.State.numFrames / 20), 1);
                app.State.frameIndex = mod(app.State.frameIndex + step - 1, max(app.State.numFrames,1)) + 1;
                v = VideoReader(app.State.videoPath);
                app.State.frame = read(v, app.State.frameIndex);
                app.refreshPreview();
                if ~isempty(app.FrameIndexLabel)
                    app.FrameIndexLabel.Text = sprintf('Frame %d / %d', app.State.frameIndex, app.State.numFrames);
                end
            catch ME
                app.status(sprintf('NextFrame failed: %s', ME.message));
            end
        end
    end

    % ========== UI builders =================================================
    methods (Access = private)
        function buildUI(app)
            app.Figure = uifigure('Name', 'sphynx — Preset & Analyze', ...
                'Position', [80, 80, 1100, 720], 'Visible', 'on');
            % Wrap the tabgroup in a uigridlayout so it fills the figure
            % and resizes correctly when the user drags the window.
            outerWrap = uigridlayout(app.Figure, [1, 1]);
            outerWrap.Padding = [0 0 0 0];
            outerWrap.RowHeight = {'1x'};
            outerWrap.ColumnWidth = {'1x'};
            app.TabGroup = uitabgroup(outerWrap);
            app.TabCreate = uitab(app.TabGroup, 'Title', 'Create Preset');
            app.TabAnalyze = uitab(app.TabGroup, 'Title', 'Analyze Session');

            buildCreateTab(app);
            buildAnalyzeTab(app);
        end

        function refocus(app)
            % Bring app figure back to front (after a log/status / external focus)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                figure(app.Figure);
            end
        end

        function status(app, msg)
            if ~isempty(app.StatusBar) && isvalid(app.StatusBar)
                app.StatusBar.Text = msg;
            end
            sphynx.util.log('info', '[App] %s', msg);
            app.refocus();
        end

        function refreshPreview(app)
            if isempty(app.State.frame); return; end
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
            % Zones (filled patches) — drawn first so arena/object outlines stay on top
            if ~isempty(app.State.zones)
                cmap = colorPaletteForZones(numel(app.State.zones));
                for k = 1:numel(app.State.zones)
                    drawZoneFilled(ax, app.State.zones(k), cmap(k,:), 0.18);
                end
            end
            if ~isempty(app.State.previewZones)
                cmap = colorPaletteForZones(numel(app.State.previewZones));
                for k = 1:numel(app.State.previewZones)
                    drawZoneFilled(ax, app.State.previewZones(k), cmap(k,:), 0.28);
                end
            end
            % Arena outline
            if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
                plot(ax, app.State.arena.border_x(:), app.State.arena.border_y(:), ...
                    'k-', 'LineWidth', 2);
            end
            % Objects with selection highlight
            selIdx = -1;
            if ~isempty(app.ObjectsListBox) && ~isempty(app.ObjectsListBox.Value)
                selIdx = find(strcmp(app.ObjectsListBox.Items, app.ObjectsListBox.Value), 1);
            end
            for k = 1:numel(app.State.objects)
                if k == selIdx
                    lw = 3.5; col = [1 0.5 0];
                else
                    lw = 1.5; col = [0 0.7 0];
                end
                plot(ax, app.State.objects(k).border_x(:), app.State.objects(k).border_y(:), ...
                    '-', 'Color', col, 'LineWidth', lw);
            end
            hold(ax, 'off');
        end

        function refreshObjectsList(app)
            if isempty(app.State.objects)
                app.ObjectsListBox.Items = {};
                app.ObjectsListBox.Value = {};
                return;
            end
            items = arrayfun(@(o) sprintf('%s (%s)', o.type, o.geometry), ...
                app.State.objects, 'UniformOutput', false);
            app.ObjectsListBox.Items = items;
        end

        function refreshZonesCount(app)
            if ~isempty(app.ZonesCountLabel)
                app.ZonesCountLabel.Text = sprintf('Committed zones: %d', numel(app.State.zones));
            end
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
            Options = struct();
            Options.ExperimentType = app.ExpTypeDropDown.Value;
            Options.pxl2sm = app.State.pxlPerCm;
            Options.x_kcorr = app.State.x_kcorr;
            Options.FrameRate = app.State.frameRate;
            Options.NumFrames = app.State.numFrames;
            Options.Height = app.State.height;
            Options.Width = app.State.width;
            Options.LikelihoodThreshold = 0.95;
            Options.velocity_rest = 1;
            Options.velocity_locomotion = 5;
            Options.BodyPart.Velocity = 'bodycenter';
        end

        function ArenaAndObjects = assembleArenaAndObjects(app)
            ArenaAndObjects = struct( ...
                'type', {}, 'geometry', {}, 'maskborder', {}, 'maskfilled', {}, ...
                'border_x', {}, 'border_y', {}, ...
                'border_separate_x', {}, 'border_separate_y', {});
            ArenaAndObjects(1).type = 'Arena';
            ArenaAndObjects(1).geometry = app.State.arena.geometry;
            ArenaAndObjects(1).maskfilled = single(app.State.arena.mask);
            ArenaAndObjects(1).border_x = app.State.arena.border_x;
            ArenaAndObjects(1).border_y = app.State.arena.border_y;
            ArenaAndObjects(1).border_separate_x = app.State.arena.border_separate_x;
            ArenaAndObjects(1).border_separate_y = app.State.arena.border_separate_y;
            for k = 1:numel(app.State.objects)
                idx = k + 1;
                ArenaAndObjects(idx).type = app.State.objects(k).type;
                ArenaAndObjects(idx).geometry = app.State.objects(k).geometry;
                ArenaAndObjects(idx).maskfilled = single(app.State.objects(k).mask);
                ArenaAndObjects(idx).border_x = app.State.objects(k).border_x;
                ArenaAndObjects(idx).border_y = app.State.objects(k).border_y;
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
                                'border_separate_x', {}, 'border_separate_y', {}, 'mask', {});
            s.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            s.previewZones = struct('name', {}, 'type', {}, 'maskfilled', {});
        end
    end
end

% =================== Tab builders =========================================

function buildCreateTab(app)
    app.OuterGrid = uigridlayout(app.TabCreate, [1, 2]);
    app.OuterGrid.ColumnWidth = {'fit', '1x'};   % left: fits content, right: flex
    app.OuterGrid.RowHeight = {'1x'};

    app.LeftGrid = uigridlayout(app.OuterGrid, [7, 1]);
    app.LeftGrid.Layout.Column = 1;
    app.LeftGrid.RowHeight = {180, 200, 90, 170, 240, 70, 30};
    app.LeftGrid.RowSpacing = 5;
    app.LeftGrid.Padding = [5 5 5 5];

    app.LoadPanel    = uipanel(app.LeftGrid, 'Title', '1. Load');
    app.CalibPanel   = uipanel(app.LeftGrid, 'Title', '2. Calibration');
    app.ArenaPanel   = uipanel(app.LeftGrid, 'Title', '3. Arena');
    app.ObjectsPanel = uipanel(app.LeftGrid, 'Title', '4. Objects');
    app.ZonesPanel   = uipanel(app.LeftGrid, 'Title', '5. Zones');
    app.SavePanel    = uipanel(app.LeftGrid, 'Title', '6. Save / Plot');
    statusPanel      = uipanel(app.LeftGrid, 'Title', 'Status');

    buildLoadPanel(app);
    buildCalibPanel(app);
    buildArenaPanel(app);
    buildObjectsPanel(app);
    buildZonesPanel(app);
    buildSavePanel(app);
    buildStatusPanel(app, statusPanel);

    % Right column
    app.RightGrid = uigridlayout(app.OuterGrid, [2, 1]);
    app.RightGrid.Layout.Column = 2;
    app.RightGrid.RowHeight = {'1x', 40};
    previewWrap = uipanel(app.RightGrid, 'Title', 'Preview (committed zones=blue, preview=magenta)');
    pg = uigridlayout(previewWrap, [1, 1]);
    app.PreviewAxes = uiaxes(pg);
    app.PreviewAxes.XTick = []; app.PreviewAxes.YTick = [];

    ctrlPanel = uipanel(app.RightGrid);
    cg = uigridlayout(ctrlPanel, [1, 3]);
    cg.ColumnWidth = {120, 150, '1x'};
    bNext = uibutton(cg, 'Text', 'Next frame', ...
        'ButtonPushedFcn', @(~,~) app.nextFrame());
    bNext.Layout.Row = 1; bNext.Layout.Column = 1;
    app.FrameIndexLabel = uilabel(cg, 'Text', 'Frame -- / --');
    app.FrameIndexLabel.Layout.Row = 1; app.FrameIndexLabel.Layout.Column = 2;
end

function buildAnalyzeTab(app)
    g = uigridlayout(app.TabAnalyze, [3, 1]);
    g.RowHeight = {30, 30, '1x'};
    lbl1 = uilabel(g, 'Text', 'Analyze Session — placeholder', 'FontSize', 16);
    lbl1.Layout.Row = 1;
    lbl2 = uilabel(g, 'Text', ['This tab will host the batch run UI for sphynx.pipeline.runBatch ' ...
        'and sphynx.pipeline.analyzeSession. For now, run from the Command Window:']);
    lbl2.Layout.Row = 2;
    txt = uitextarea(g, 'Value', { ...
        'cfg = sphynx.pipeline.defaultConfig();', ...
        'cfg.paths.dlc = ''<repo>/Demo/DLC/<file>.csv'';', ...
        'cfg.paths.preset = ''<saved preset>.mat'';', ...
        'cfg.io.saveWorkspace = true;', ...
        'cfg.paths.outDir = ''<output dir>'';', ...
        'result = sphynx.pipeline.analyzeSession(cfg);'}, ...
        'Editable', 'off');
    txt.Layout.Row = 3;
end

% =================== Panel builders =======================================

function buildLoadPanel(app)
    g = uigridlayout(app.LoadPanel, [4 3]);
    g.RowHeight = {25, 25, 25, 25};
    g.ColumnWidth = {'fit', '1x', 'fit'};

    addRow(g, 1, 'Project root:', @() pickDirAndApply(app, 'setProjectRoot'), 'projectRoot', app);
    addRow(g, 2, 'Video file:',   @() pickVideoStart(app), 'videoPath', app);
    addRow(g, 3, 'Output dir:',   @() pickDirAndApply(app, 'setOutDir'), 'outDir', app);
    addRow(g, 4, 'Existing preset:', @() pickPresetStart(app), 'presetPath', app);
end

function addRow(g, row, labelText, btnFcn, fieldKey, app)
    lbl = uilabel(g, 'Text', labelText);
    lbl.Layout.Row = row; lbl.Layout.Column = 1;
    fld = uieditfield(g, 'text', 'Value', '');
    fld.Layout.Row = row; fld.Layout.Column = 2;
    btn = uibutton(g, 'Text', 'Browse', 'ButtonPushedFcn', @(~,~) btnFcn());
    btn.Layout.Row = row; btn.Layout.Column = 3;
    switch fieldKey
        case 'projectRoot'; app.ProjectRootField = fld;
        case 'videoPath';   app.VideoPathField = fld;
        case 'outDir';      app.OutDirField = fld;
        case 'presetPath';  app.PresetPathField = fld;
    end
end

function buildCalibPanel(app)
    g = uigridlayout(app.CalibPanel, [4 4]);
    g.RowHeight = {28, 28, 28, 28};
    g.ColumnWidth = {'fit', 'fit', 'fit', 'fit'};

    bChoose = uibutton(g, 'Text', 'Calibration. Choose points', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) onCalibrateChoose(app));
    bChoose.Layout.Row = 1; bChoose.Layout.Column = [1 2];
    bCompute = uibutton(g, 'Text', 'Calibration. Calculation', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) onCalibrateCompute(app));
    bCompute.Layout.Row = 1; bCompute.Layout.Column = 3;
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Calibration', helpCalibrationText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = 4;

    lblY = uilabel(g, 'Text', 'cm Y (1->2):');
    lblY.Layout.Row = 2; lblY.Layout.Column = 1;
    app.DistanceYField = uieditfield(g, 'numeric', 'Value', 50, 'Limits', [0.1, Inf]);
    app.DistanceYField.Layout.Row = 2; app.DistanceYField.Layout.Column = 2;
    lblX = uilabel(g, 'Text', 'cm X (3->4):');
    lblX.Layout.Row = 2; lblX.Layout.Column = 3;
    app.DistanceXField = uieditfield(g, 'numeric', 'Value', 50, 'Limits', [0.1, Inf]);
    app.DistanceXField.Layout.Row = 2; app.DistanceXField.Layout.Column = 4;

    app.PxlPerCmYLabel = uilabel(g, 'Text', 'Y: ?');
    app.PxlPerCmYLabel.Layout.Row = 3; app.PxlPerCmYLabel.Layout.Column = 1;
    app.PxlPerCmXLabel = uilabel(g, 'Text', 'X: ?');
    app.PxlPerCmXLabel.Layout.Row = 3; app.PxlPerCmXLabel.Layout.Column = 2;
    app.PxlPerCmAvgLabel = uilabel(g, 'Text', 'avg: ?');
    app.PxlPerCmAvgLabel.Layout.Row = 3; app.PxlPerCmAvgLabel.Layout.Column = 3;
    app.XKcorrLabel = uilabel(g, 'Text', 'kcorr: ?');
    app.XKcorrLabel.Layout.Row = 3; app.XKcorrLabel.Layout.Column = 4;

    lblExp = uilabel(g, 'Text', 'Experiment:');
    lblExp.Layout.Row = 4; lblExp.Layout.Column = 1;
    app.ExpTypeDropDown = uidropdown(g, ...
        'Items', {'Novelty OF','BowlsOpenField','NOL','Holes Track','Odor Track', ...
                  'Freezing Track','New Track','Complex Context','OF_Obj','3DM'});
    app.ExpTypeDropDown.Layout.Row = 4; app.ExpTypeDropDown.Layout.Column = [2 4];
end

function buildArenaPanel(app)
    nGeom = 4;       % Polygon / Circle / Ellipse / O-maze
    % Layout: nGeom geometry buttons | spacer | action btn | INFO btn
    nCols = nGeom + 3;
    g = uigridlayout(app.ArenaPanel, [2, nCols]);
    g.RowHeight = {28, 25};
    g.ColumnWidth = [repmat({'fit'}, 1, nGeom), {16}, repmat({'fit'}, 1, 2)];
    g.ColumnSpacing = 4;

    geometries = {'Polygon', 'Circle', 'Ellipse', 'O-maze'};
    app.ArenaGeometryButtons = cell(1, numel(geometries));
    for i = 1:numel(geometries)
        b = uibutton(g, 'state', 'Text', geometries{i}, ...
            'BackgroundColor', semanticColor('geometry'), ...
            'ValueChangedFcn', @(src, ~) onArenaGeometryToggle(app, src));
        b.Layout.Row = 1; b.Layout.Column = i;
        if i == 1; b.Value = true; end
        app.ArenaGeometryButtons{i} = b;
    end

    % column nGeom+1 is the spacer (kept empty)
    bArena = uibutton(g, 'Text', 'Pick arena points', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) onPickArena(app));
    bArena.Layout.Row = 1; bArena.Layout.Column = nGeom + 2;
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Arena', helpArenaText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = nGeom + 3;

    app.ArenaStatusLabel = uilabel(g, 'Text', 'Arena: <none>');
    app.ArenaStatusLabel.Layout.Row = 2; app.ArenaStatusLabel.Layout.Column = [1 nCols];
end

function buildObjectsPanel(app)
    nGeom = 3;       % Polygon / Circle / Ellipse
    nCols = nGeom + 3;
    g = uigridlayout(app.ObjectsPanel, [3, nCols]);
    g.RowHeight = {28, '1x', 28};
    g.ColumnWidth = [repmat({'fit'}, 1, nGeom), {16}, repmat({'fit'}, 1, 2)];
    g.ColumnSpacing = 4;

    geometries = {'Polygon', 'Circle', 'Ellipse'};
    app.ObjectGeometryButtons = cell(1, numel(geometries));
    for i = 1:numel(geometries)
        b = uibutton(g, 'state', 'Text', geometries{i}, ...
            'BackgroundColor', semanticColor('geometry'), ...
            'ValueChangedFcn', @(src, ~) onObjectGeometryToggle(app, src));
        b.Layout.Row = 1; b.Layout.Column = i;
        if i == 1; b.Value = true; end
        app.ObjectGeometryButtons{i} = b;
    end

    % column nGeom+1 is the spacer
    bAdd = uibutton(g, 'Text', '+ Add', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) onAddObject(app));
    bAdd.Layout.Row = 1; bAdd.Layout.Column = nGeom + 2;
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Objects', helpObjectsText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = nGeom + 3;

    app.ObjectsListBox = uilistbox(g, 'Items', {}, ...
        'ValueChangedFcn', @(~,~) app.refreshPreview());
    app.ObjectsListBox.Layout.Row = 2; app.ObjectsListBox.Layout.Column = [1 nCols];

    bRemove = uibutton(g, 'Text', 'Remove', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.removeSelectedObject());
    bRemove.Layout.Row = 3; bRemove.Layout.Column = 1;
    bReplace = uibutton(g, 'Text', 'Replace', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.replaceSelectedObject());
    bReplace.Layout.Row = 3; bReplace.Layout.Column = 2;
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
    g = uigridlayout(app.ZonesPanel, [6 4]);
    g.RowHeight = {28, 28, 28, 28, 28, 28};
    g.ColumnWidth = {'fit', 'fit', 'fit', 'fit'};

    lblStrat = uilabel(g, 'Text', 'Strategy:');
    lblStrat.Layout.Row = 1; lblStrat.Layout.Column = 1;
    app.ZonesStrategyDropDown = uidropdown(g, ...
        'Items', {'corners-walls-center', 'strips', 'circle-rings', 'none'}, ...
        'ValueChangedFcn', @(~,~) onZoneStrategyChanged(app));
    app.ZonesStrategyDropDown.Layout.Row = 1; app.ZonesStrategyDropDown.Layout.Column = [2 3];
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Zones', helpZonesText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = 4;

    lblWall = uilabel(g, 'Text', 'Wall (cm):');
    lblWall.Layout.Row = 2; lblWall.Layout.Column = 1;
    app.WallWidthField = uieditfield(g, 'numeric', 'Value', 3, 'Limits', [0, Inf]);
    app.WallWidthField.Layout.Row = 2; app.WallWidthField.Layout.Column = 2;
    lblMid = uilabel(g, 'Text', 'Middle (cm):');
    lblMid.Layout.Row = 2; lblMid.Layout.Column = 3;
    app.MiddleWidthField = uieditfield(g, 'numeric', 'Value', 20, 'Limits', [0.1, Inf]);
    app.MiddleWidthField.Layout.Row = 2; app.MiddleWidthField.Layout.Column = 4;

    lblN = uilabel(g, 'Text', 'N strips:');
    lblN.Layout.Row = 3; lblN.Layout.Column = 1;
    app.NumStripsField = uieditfield(g, 'numeric', 'Value', 3, 'Limits', [1, 50]);
    app.NumStripsField.Layout.Row = 3; app.NumStripsField.Layout.Column = 2;
    lblDir = uilabel(g, 'Text', 'Strip dir:');
    lblDir.Layout.Row = 3; lblDir.Layout.Column = 3;
    app.StripDirDropDown = uidropdown(g, 'Items', {'horizontal','vertical'});
    app.StripDirDropDown.Layout.Row = 3; app.StripDirDropDown.Layout.Column = 4;

    lblObjZone = uilabel(g, 'Text', 'Object zone (cm):');
    lblObjZone.Layout.Row = 4; lblObjZone.Layout.Column = 1;
    app.ObjectZoneWidthField = uieditfield(g, 'numeric', 'Value', 2.5, 'Limits', [0, Inf]);
    app.ObjectZoneWidthField.Layout.Row = 4; app.ObjectZoneWidthField.Layout.Column = 2;

    bPreview = uibutton(g, 'Text', 'Preview zones', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.previewZones());
    bPreview.Layout.Row = 5; bPreview.Layout.Column = 1;
    bAdd = uibutton(g, 'Text', 'Add to set', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.addZones());
    bAdd.Layout.Row = 5; bAdd.Layout.Column = 2;
    bClear = uibutton(g, 'Text', 'Clear all', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.clearZones());
    bClear.Layout.Row = 5; bClear.Layout.Column = 3;

    app.ZonesCountLabel = uilabel(g, 'Text', 'Committed zones: 0');
    app.ZonesCountLabel.Layout.Row = 6; app.ZonesCountLabel.Layout.Column = [1 4];

    onZoneStrategyChanged(app);
end

function buildSavePanel(app)
    g = uigridlayout(app.SavePanel, [1 4]);
    g.ColumnWidth = {'fit', 'fit', 'fit', 'fit'};
    bSave = uibutton(g, 'Text', 'Save preset', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.savePreset());
    bSave.Layout.Row = 1; bSave.Layout.Column = 1;
    bPlot = uibutton(g, 'Text', 'Make plot', ...
        'BackgroundColor', semanticColor('action'), ...
        'ButtonPushedFcn', @(~,~) app.makePlot());
    bPlot.Layout.Row = 1; bPlot.Layout.Column = 2;
    app.PlotAllCheckbox = uicheckbox(g, 'Text', 'plot all zones', 'Value', false);
    app.PlotAllCheckbox.Layout.Row = 1; app.PlotAllCheckbox.Layout.Column = 3;
    bInfo = uibutton(g, 'Text', 'INFO', ...
        'BackgroundColor', semanticColor('info'), ...
        'ButtonPushedFcn', @(~,~) showHelp('Save / Plot', helpSaveText()));
    bInfo.Layout.Row = 1; bInfo.Layout.Column = 4;
end

function buildStatusPanel(app, parent)
    g = uigridlayout(parent, [1 1]);
    app.StatusBar = uilabel(g, 'Text', 'Ready');
end

% =================== Callbacks ============================================

function onZoneStrategyChanged(app)
    s = app.ZonesStrategyDropDown.Value;
    app.WallWidthField.Enable    = enableIfAny(s, {'corners-walls-center', 'circle-rings'});
    app.MiddleWidthField.Enable  = enableIfAny(s, {'circle-rings'});
    app.NumStripsField.Enable    = enableIfAny(s, {'strips'});
    app.StripDirDropDown.Enable  = enableIfAny(s, {'strips'});
    app.ObjectZoneWidthField.Enable = toOnOff(~isempty(app.State.objects));
end

function v = enableIfAny(s, list)
    v = toOnOff(any(strcmp(s, list)));
end

function s = toOnOff(b)
    if b; s = 'on'; else; s = 'off'; end
end

function onCalibrateChoose(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    fh = figure('Name', 'Click 4 calibration points');
    cleanup = onCleanup(@() closeIfValid(fh));
    imshow(app.State.frame); hold on;
    title('Click 4 points: Y-pair (1, 2), then X-pair (3, 4)');
    [xPts, yPts] = ginput(4);
    app.State.calibPoints = [xPts(:), yPts(:)];
    clear cleanup;
    app.status(sprintf('Got %d calibration points; now click "Calibration. Calculation"', size(app.State.calibPoints,1)));
    app.refocus();
end

function onCalibrateCompute(app)
    if isempty(app.State.calibPoints) || size(app.State.calibPoints, 1) < 4
        app.status('Click "Choose points" first (need 4 points)');
        return;
    end
    [pxlAvg, kcorr, pxlY, pxlX, diffPct] = sphynx.preset.pixelsPerCm(app.State.frame, ...
        'Points', app.State.calibPoints, ...
        'DistancesCm', [app.DistanceYField.Value, app.DistanceXField.Value]);
    % Always pass actual Y and X so the labels show the raw measurements
    % even when kcorr collapses to 1 (within threshold).
    app.setPixelsPerCm(pxlAvg, 'Y', pxlY, 'X', pxlX, 'KCorr', kcorr);
    app.status(sprintf('Calibrated: avg=%.2f, Y=%.2f, X=%.2f, X/Y diff=%.2f%%, kcorr=%.3f', ...
        pxlAvg, pxlY, pxlX, diffPct, kcorr));
end

function onPickArena(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.State.arenaGeometry;
    try
        arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry);
        app.State.arena = arena;
        app.ArenaStatusLabel.Text = sprintf('Arena: %s OK', geometry);
        app.refreshPreview();
        onZoneStrategyChanged(app);
        sphynx.util.log('info', '[App] arena geometry=%s', geometry);
        app.refocus();
    catch ME
        app.status(sprintf('Arena failed: %s', ME.message));
    end
end

function onAddObject(app)
    % Loop adding the same object until the user confirms it (Yes) or
    % asks to delete it. "No (redo)" pops the bad object first so the
    % old mask is NOT shown on preview while the user re-picks.
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.State.objectGeometry;
    while true
        try
            obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry);
            obj.type = sprintf('Object%d', numel(app.State.objects) + 1);
            if isempty(app.State.objects)
                app.State.objects = obj;
            else
                app.State.objects(end+1) = obj;
            end
            app.refreshObjectsList();
            app.refreshPreview();
            onZoneStrategyChanged(app);
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
    if isfield(preset.Options, 'pxl2sm')
        kcorr = ifNaN(getOptField(preset.Options, 'x_kcorr'), 1);
        app.setPixelsPerCm(preset.Options.pxl2sm, 'Y', preset.Options.pxl2sm, ...
            'X', preset.Options.pxl2sm / kcorr, 'KCorr', kcorr);
    end
    app.status(sprintf('Loaded preset: %s', f));
    app.refocus();
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
                Z = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                    'Strategy', 'corners-walls-center', ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'WallWidthCm', wallCm, ...
                    'CornerPoints', cornerPointsFromArena(app.State.arena));
            case 'strips'
                Z = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                    'Strategy', 'strips', ...
                    'NumStrips', app.NumStripsField.Value, ...
                    'StripDirection', app.StripDirDropDown.Value);
            case 'circle-rings'
                Z = sphynx.preset.buildZonesCircle(app.State.arena.mask, ...
                    'PixelsPerCm', app.State.pxlPerCm, ...
                    'WallWidthCm', wallCm, ...
                    'MiddleWidthCm', app.MiddleWidthField.Value);
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
    % Lightweight: outline only (lines), safe in uiaxes (no patch
    % which can collide with imshow's CData/XLim handling).
    if ~isnumeric(z.maskfilled) && ~islogical(z.maskfilled); return; end
    mask = logical(z.maskfilled);
    if ~any(mask(:)); return; end
    B = bwboundaries(mask, 'noholes');
    for k = 1:numel(B)
        b = B{k};
        if size(b, 1) < 3; continue; end
        plot(ax, b(:, 2), b(:, 1), '-', 'Color', color, 'LineWidth', 1.5);
    end
end

function drawZoneFilled(ax, z, color, alpha)
    % Heavier: filled patch + outline. For saved plots in figure axes
    % (not uiaxes), where patch behaves correctly.
    if ~isnumeric(z.maskfilled) && ~islogical(z.maskfilled); return; end
    mask = logical(z.maskfilled);
    if ~any(mask(:)); return; end
    B = bwboundaries(mask, 'noholes');
    for k = 1:numel(B)
        b = B{k};
        if size(b, 1) < 3; continue; end
        patch(ax, b(:, 2), b(:, 1), color, ...
            'FaceAlpha', alpha, 'EdgeColor', color, 'LineWidth', 1.2);
    end
end

function drawState(ax, S, drawZones)
    % Used by Make plot; ax is a regular figure axes (not uiaxes), so
    % patch + FaceAlpha works correctly here.
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

% =================== Help text ============================================

function showHelp(title, text)
    msgbox(text, title, 'help', 'modal');
end

function c = semanticColor(category)
    % Pastel button-tinting by semantic role.
    switch category
        case 'geometry'; c = [1.00, 0.97, 0.78];   % light yellow — selectors
        case 'action';   c = [1.00, 0.88, 0.85];   % light red    — do-something
        case 'info';     c = [0.85, 0.92, 1.00];   % light blue   — INFO/help
        otherwise;       c = [0.96, 0.96, 0.96];   % default grey
    end
end

function txt = helpCalibrationText()
    txt = {
        'Calibration: convert pixels to centimeters.';
        '';
        'Step 1 - "Calibration. Choose points":';
        '   Click 4 points on the preview frame in this order:';
        '     point 1 - top of vertical reference';
        '     point 2 - bottom of vertical reference';
        '     point 3 - left of horizontal reference';
        '     point 4 - right of horizontal reference';
        '   The picture closes when all 4 are clicked.';
        '';
        'Step 2 - enter the real cm distances into the cm Y / cm X';
        'fields.';
        '';
        'Step 3 - "Calibration. Calculation": computes pxl/cm for Y,';
        'X, average, and the X/Y correction factor (kcorr). If kcorr';
        'differs from 1 by more than ~3%, your camera scale is';
        'unequal between axes — keep this in mind.';
    };
end

function txt = helpArenaText()
    txt = {
        'Define the arena boundary on the current preview frame.';
        '';
        '1) Choose geometry: Polygon (clicks corners), Circle (>=3 pts on rim),';
        '   Ellipse (>=5 pts on rim), or O-maze (>=3 pts outer + >=3 pts inner).';
        '2) Click "Pick arena points".';
        '3) Click points on the temp window; press ENTER. Window closes.';
        '4) The polygon outline appears in black on the preview.';
    };
end

function txt = helpObjectsText()
    txt = {
        'Add objects (food bowls, novel objects, etc.) on the arena.';
        '';
        '1) Choose object geometry.';
        '2) Click "+ Add object", click points, ENTER. Window closes.';
        '3) Up to 4 named objects supported by downstream zone acts.';
        '4) Select an object in the list to highlight it on the preview.';
        '5) Use "Remove selected" to delete the highlighted object.';
    };
end

function txt = helpZonesText()
    txt = {
        'Build spatial-zone masks based on the arena (and objects).';
        '';
        'Strategies:';
        '  corners-walls-center : square arena split into corner, wall,';
        '       and center zones. Wall (cm) controls wall width.';
        '  strips : split arena into N equal-width strips.';
        '  circle-rings : concentric rings (wall + middle1.. + center)';
        '       for round arenas. Wall and Middle widths in cm.';
        '  none : no spatial subdivision.';
        '';
        '"Preview zones" shows the proposed partition on the preview';
        '(magenta) without committing.';
        '"Add to set" commits the previewed zones to the final set';
        '(blue). You can call it multiple times with different';
        'strategies to combine partitions.';
        '"Clear all" removes every committed zone.';
        '';
        'Object zone (cm) is the inflated radius around each object';
        'that counts as object interaction. Field is enabled only';
        'when objects are defined.';
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
        '"Make plot": always saves <videobase>_layout.png — the';
        'combined preview (arena + objects + all committed zones).';
        '';
        'Check "plot all zones" to ALSO save one PNG per individual';
        'zone (<videobase>_zone_<name>.png).';
    };
end

classdef CreatePresetApp < handle
% CREATEPRESETAPP  Single-window preset builder for sphynx.
%
%   sphynx.app.CreatePresetApp() opens a uifigure-based preset editor.
%   Layout: left column of step-panels (Load -> Calibration -> Arena
%   -> Objects -> Zones -> Save), right column with a large preview
%   axes. Each panel has a `?` help button.
%
%   Implementation: hand-written `handle` class using uifigure +
%   uigridlayout (modern alternative to App Designer .mlapp).
%   All compute/IO logic delegated to +sphynx/+preset/* and
%   +sphynx/+pipeline/*. The app is a thin shell.
%
%   Built for MATLAB R2020a.
%
%   Public-state struct (`State`) is mutable and exposed for tests.
%   Programmatic API: setVideo, setOutDir, setPixelsPerCm, setArena,
%   addObject, addZones (replaces buildZones), savePreset.

    properties
        Figure
        % Layout containers
        OuterGrid
        LeftScroll
        LeftGrid
        RightGrid
        % Panels
        LoadPanel
        CalibPanel
        ArenaPanel
        ObjectsPanel
        ZonesPanel
        SavePanel
        % Load panel components
        ProjectRootField
        VideoPathField
        OutDirField
        PresetPathField
        % Calibration components
        DistanceYField
        DistanceXField
        PxlPerCmYLabel
        PxlPerCmXLabel
        PxlPerCmAvgLabel
        XKcorrLabel
        ExpTypeDropDown
        % Arena components
        ArenaGeometryDropDown
        ArenaStatusLabel
        % Objects components
        ObjectGeometryDropDown
        ObjectsListBox
        % Zones components
        ZonesStrategyDropDown
        WallWidthField
        MiddleWidthField
        NumStripsField
        StripDirDropDown
        ObjectZoneWidthField
        AppliedZonesListBox
        % Preview
        PreviewAxes
        FrameIndexLabel
        % Status
        StatusBar
        % State (public for tests)
        State
    end

    methods
        function app = CreatePresetApp(varargin)
            app.State = sphynx.app.CreatePresetApp.emptyState();
            app.buildUI();
            sphynx.util.log('info', '[App] CreatePresetApp opened');
        end

        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                close(app.Figure);
            end
        end

        % --- Programmatic API (also used by tests) ----------------------------
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
                app.refreshPreview();
                app.status(sprintf('Loaded video: %dx%d, %d frames @ %.1f fps', ...
                    app.State.width, app.State.height, app.State.numFrames, app.State.frameRate));
                sphynx.util.log('info', '[App] setVideo path=%s w=%d h=%d frames=%d fps=%.2f', ...
                    path, app.State.width, app.State.height, app.State.numFrames, app.State.frameRate);
            catch ME
                app.status(sprintf('Video load failed: %s', ME.message));
            end
        end

        function setOutDir(app, dir)
            app.State.outDir = dir;
            if ~isempty(app.OutDirField); app.OutDirField.Value = dir; end
            sphynx.util.log('info', '[App] setOutDir %s', dir);
        end

        function setProjectRoot(app, dir)
            app.State.projectRoot = dir;
            if ~isempty(app.ProjectRootField); app.ProjectRootField.Value = dir; end
            sphynx.util.log('info', '[App] setProjectRoot %s', dir);
        end

        function setPixelsPerCm(app, pxlAvg, varargin)
            % setPixelsPerCm(avg) or setPixelsPerCm(avg, 'Y', y, 'X', x, 'KCorr', kc)
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
            sphynx.util.log('info', '[App] setPixelsPerCm avg=%.3f Y=%.3f X=%.3f kcorr=%.3f', ...
                pxlAvg, app.State.pxlPerCmY, app.State.pxlPerCmX, app.State.x_kcorr);
        end

        function setArena(app, geometry, points)
            try
                arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
                    'Points', points);
                app.State.arena = arena;
                app.ArenaStatusLabel.Text = sprintf('Arena: %s OK', geometry);
                app.refreshPreview();
                sphynx.util.log('info', '[App] setArena geometry=%s npoints=%d', geometry, size(points,1));
            catch ME
                app.status(sprintf('Arena failed: %s', ME.message));
                sphynx.util.log('warn', '[App] setArena ERROR: %s', ME.message);
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
                sphynx.util.log('info', '[App] addObject geometry=%s npoints=%d total=%d', ...
                    geometry, size(points,1), numel(app.State.objects));
            catch ME
                app.status(sprintf('Object failed: %s', ME.message));
                sphynx.util.log('warn', '[App] addObject ERROR: %s', ME.message);
            end
        end

        function addZones(app)
            % Compute zones with current strategy+params and ADD them to
            % the cumulative State.zones set (replaces buildZones — old
            % name overwrote each time).
            if isempty(app.State.arena)
                app.status('Define arena first');
                return;
            end
            try
                strategy = app.ZonesStrategyDropDown.Value;
                wallCm = app.WallWidthField.Value;        % numeric field, use directly
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
                % Append (don't overwrite) to support combined strategies
                if isempty(app.State.zones)
                    app.State.zones = Z;
                else
                    app.State.zones(end+1:end+numel(Z)) = Z;
                end
                app.refreshAppliedZonesList();
                app.refreshPreview();
                app.status(sprintf('Added %d zones (%s); total=%d', ...
                    numel(Z), strategy, numel(app.State.zones)));
                sphynx.util.log('info', '[App] addZones strategy=%s added=%d total=%d', ...
                    strategy, numel(Z), numel(app.State.zones));
            catch ME
                app.status(sprintf('Zones failed: %s', ME.message));
                sphynx.util.log('warn', '[App] addZones ERROR: %s', ME.message);
            end
        end

        function clearZones(app)
            app.State.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            app.refreshAppliedZonesList();
            app.refreshPreview();
            sphynx.util.log('info', '[App] clearZones');
        end

        function savePreset(app)
            if isempty(app.State.outDir)
                app.status('Set output directory first');
                return;
            end
            if isempty(app.State.arena)
                app.status('Define arena first');
                return;
            end
            try
                Options = app.assembleOptions();
                ArenaAndObjects = app.assembleArenaAndObjects();
                Zones = app.State.zones;
                if isempty(Zones)
                    Zones = struct('name', {}, 'type', {}, 'maskfilled', {});
                end
                [~, baseName, ~] = fileparts(app.State.videoPath);
                if isempty(baseName); baseName = 'preset'; end
                outPath = fullfile(app.State.outDir, sprintf('%s_Preset.mat', baseName));
                save(outPath, 'Options', 'Zones', 'ArenaAndObjects');
                app.status(sprintf('Saved preset: %s', outPath));
                sphynx.util.log('info', '[App] savePreset wrote %s', outPath);
            catch ME
                app.status(sprintf('Save failed: %s', ME.message));
                sphynx.util.log('warn', '[App] savePreset ERROR: %s', ME.message);
            end
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
                sphynx.util.log('info', '[App] nextFrame -> %d', app.State.frameIndex);
            catch ME
                app.status(sprintf('NextFrame failed: %s', ME.message));
            end
        end
    end

    % ====== UI builders (private) ============================================
    methods (Access = private)
        function buildUI(app)
            app.Figure = uifigure('Name', 'sphynx — Create Preset', ...
                'Position', [80, 80, 1280, 800], 'Visible', 'on');

            app.OuterGrid = uigridlayout(app.Figure, [1, 2]);
            app.OuterGrid.ColumnWidth = {520, '1x'};
            app.OuterGrid.RowHeight = {'1x'};

            % Left side: scroll-friendly grid of panels
            app.LeftGrid = uigridlayout(app.OuterGrid, [7, 1]);
            app.LeftGrid.Layout.Column = 1;
            app.LeftGrid.RowHeight = {180, 200, 90, 160, 240, 80, 30};
            app.LeftGrid.RowSpacing = 5;
            app.LeftGrid.Padding = [5 5 5 5];

            app.LoadPanel    = uipanel(app.LeftGrid, 'Title', '1. Load');
            app.CalibPanel   = uipanel(app.LeftGrid, 'Title', '2. Calibration');
            app.ArenaPanel   = uipanel(app.LeftGrid, 'Title', '3. Arena');
            app.ObjectsPanel = uipanel(app.LeftGrid, 'Title', '4. Objects');
            app.ZonesPanel   = uipanel(app.LeftGrid, 'Title', '5. Zones');
            app.SavePanel    = uipanel(app.LeftGrid, 'Title', '6. Save / Run');
            statusPanel      = uipanel(app.LeftGrid, 'Title', 'Status');

            buildLoadPanel(app);
            buildCalibPanel(app);
            buildArenaPanel(app);
            buildObjectsPanel(app);
            buildZonesPanel(app);
            buildSavePanel(app);
            buildStatusPanel(app, statusPanel);

            % Right side: large preview + NextFrame
            app.RightGrid = uigridlayout(app.OuterGrid, [2, 1]);
            app.RightGrid.Layout.Column = 2;
            app.RightGrid.RowHeight = {'1x', 40};
            previewWrap = uipanel(app.RightGrid, 'Title', 'Preview');
            previewGrid = uigridlayout(previewWrap, [1, 1]);
            app.PreviewAxes = uiaxes(previewGrid);
            app.PreviewAxes.XTick = []; app.PreviewAxes.YTick = [];

            ctrlPanel = uipanel(app.RightGrid);
            cg = uigridlayout(ctrlPanel, [1, 4]);
            cg.ColumnWidth = {120, 100, 100, '1x'};
            bNext = uibutton(cg, 'Text', 'Next frame', ...
                'ButtonPushedFcn', @(~,~) app.nextFrame());
            bNext.Layout.Row = 1; bNext.Layout.Column = 1;
            app.FrameIndexLabel = uilabel(cg, 'Text', 'Frame -- / --');
            app.FrameIndexLabel.Layout.Row = 1; app.FrameIndexLabel.Layout.Column = 2;
        end

        function status(app, msg)
            if ~isempty(app.StatusBar) && isvalid(app.StatusBar)
                app.StatusBar.Text = msg;
            end
            sphynx.util.log('info', '[App.status] %s', msg);
        end

        function refreshPreview(app)
            if isempty(app.State.frame); return; end
            cla(app.PreviewAxes);
            imshow(app.State.frame, 'Parent', app.PreviewAxes);
            hold(app.PreviewAxes, 'on');
            if ~isempty(app.State.arena) && ~isempty(app.State.arena.border_x)
                plot(app.PreviewAxes, app.State.arena.border_x(:), app.State.arena.border_y(:), ...
                    'k-', 'LineWidth', 2);
            end
            for k = 1:numel(app.State.objects)
                plot(app.PreviewAxes, app.State.objects(k).border_x(:), app.State.objects(k).border_y(:), ...
                    'g-', 'LineWidth', 2);
            end
            if ~isempty(app.State.zones)
                colors = lines(numel(app.State.zones));
                for k = 1:numel(app.State.zones)
                    z = app.State.zones(k);
                    if ~isnumeric(z.maskfilled) && ~islogical(z.maskfilled); continue; end
                    [r, c] = find(z.maskfilled);
                    if ~isempty(r)
                        scatter(app.PreviewAxes, c, r, 1, colors(k,:), 'filled', ...
                            'MarkerFaceAlpha', 0.05);
                    end
                end
            end
            hold(app.PreviewAxes, 'off');
        end

        function refreshObjectsList(app)
            if isempty(app.State.objects)
                app.ObjectsListBox.Items = {};
                return;
            end
            items = arrayfun(@(o) sprintf('%s (%s)', o.type, o.geometry), ...
                app.State.objects, 'UniformOutput', false);
            app.ObjectsListBox.Items = items;
        end

        function refreshAppliedZonesList(app)
            if isempty(app.State.zones)
                app.AppliedZonesListBox.Items = {};
                return;
            end
            items = arrayfun(@(z) sprintf('%s (%s)', z.name, z.type), ...
                app.State.zones, 'UniformOutput', false);
            app.AppliedZonesListBox.Items = items;
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
            s.arena = [];
            s.objects = struct('type', {}, 'geometry', {}, 'border_x', {}, 'border_y', {}, ...
                                'border_separate_x', {}, 'border_separate_y', {}, 'mask', {});
            s.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
        end
    end
end

% ========== Panel builders (helper local functions) =====================

function buildLoadPanel(app)
    g = uigridlayout(app.LoadPanel, [4 3]);
    g.RowHeight = {25, 25, 25, 25};
    g.ColumnWidth = {110, '1x', 50};

    addRow(g, 1, 'Project root:', @() pickDir(app, 'setProjectRoot'), ...
        @() refreshAppField(app, 'ProjectRootField'), 'projectRoot', app);
    addRow(g, 2, 'Video file:',   @() pickVideoStart(app), ...
        @() refreshAppField(app, 'VideoPathField'), 'videoPath', app);
    addRow(g, 3, 'Output dir:',   @() pickDirStart(app, 'setOutDir'), ...
        @() refreshAppField(app, 'OutDirField'), 'outDir', app);
    addRow(g, 4, 'Existing preset:', @() pickPresetStart(app), ...
        @() refreshAppField(app, 'PresetPathField'), 'presetPath', app);

    % Help button at top-right of panel — we use a 5th narrow column trick
    % by piggy-backing onto the panel border (no extra column reqd here).
end

function addRow(g, row, labelText, btnFcn, ~, fieldKey, app)
    lbl = uilabel(g, 'Text', labelText);
    lbl.Layout.Row = row; lbl.Layout.Column = 1;
    fld = uieditfield(g, 'text', 'Value', '');
    fld.Layout.Row = row; fld.Layout.Column = 2;
    btn = uibutton(g, 'Text', 'Browse', 'ButtonPushedFcn', @(~,~) btnFcn());
    btn.Layout.Row = row; btn.Layout.Column = 3;
    % Bind field handle into the app
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
    g.ColumnWidth = {130, 90, 90, '1x'};

    bCalib = uibutton(g, 'Text', 'Calibrate (4 clicks)', ...
        'ButtonPushedFcn', @(~,~) onCalibrate(app));
    bCalib.Layout.Row = 1; bCalib.Layout.Column = 1;
    bHelp = uibutton(g, 'Text', '?', ...
        'ButtonPushedFcn', @(~,~) showHelp('Calibration', helpCalibrationText()));
    bHelp.Layout.Row = 1; bHelp.Layout.Column = 4;

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
    g = uigridlayout(app.ArenaPanel, [2 4]);
    g.RowHeight = {28, 25};
    g.ColumnWidth = {110, 130, 160, 50};
    lblGeom = uilabel(g, 'Text', 'Geometry:');
    lblGeom.Layout.Row = 1; lblGeom.Layout.Column = 1;
    app.ArenaGeometryDropDown = uidropdown(g, ...
        'Items', {'Polygon', 'Circle', 'Ellipse', 'O-maze'});
    app.ArenaGeometryDropDown.Layout.Row = 1; app.ArenaGeometryDropDown.Layout.Column = 2;
    bArena = uibutton(g, 'Text', 'Pick arena points', ...
        'ButtonPushedFcn', @(~,~) onPickArena(app));
    bArena.Layout.Row = 1; bArena.Layout.Column = 3;
    bHelp = uibutton(g, 'Text', '?', ...
        'ButtonPushedFcn', @(~,~) showHelp('Arena', helpArenaText()));
    bHelp.Layout.Row = 1; bHelp.Layout.Column = 4;
    app.ArenaStatusLabel = uilabel(g, 'Text', 'Arena: <none>');
    app.ArenaStatusLabel.Layout.Row = 2; app.ArenaStatusLabel.Layout.Column = [1 4];
end

function buildObjectsPanel(app)
    g = uigridlayout(app.ObjectsPanel, [2 4]);
    g.RowHeight = {28, '1x'};
    g.ColumnWidth = {110, 130, 130, 50};
    lblObjGeom = uilabel(g, 'Text', 'Geometry:');
    lblObjGeom.Layout.Row = 1; lblObjGeom.Layout.Column = 1;
    app.ObjectGeometryDropDown = uidropdown(g, ...
        'Items', {'Polygon', 'Circle', 'Ellipse'});
    app.ObjectGeometryDropDown.Layout.Row = 1; app.ObjectGeometryDropDown.Layout.Column = 2;
    bAdd = uibutton(g, 'Text', '+ Add object', ...
        'ButtonPushedFcn', @(~,~) onAddObject(app));
    bAdd.Layout.Row = 1; bAdd.Layout.Column = 3;
    bHelp = uibutton(g, 'Text', '?', ...
        'ButtonPushedFcn', @(~,~) showHelp('Objects', helpObjectsText()));
    bHelp.Layout.Row = 1; bHelp.Layout.Column = 4;
    app.ObjectsListBox = uilistbox(g, 'Items', {});
    app.ObjectsListBox.Layout.Row = 2; app.ObjectsListBox.Layout.Column = [1 4];
end

function buildZonesPanel(app)
    g = uigridlayout(app.ZonesPanel, [6 4]);
    g.RowHeight = {28, 28, 28, 28, 28, '1x'};
    g.ColumnWidth = {110, 90, 110, 90};

    lblStrat = uilabel(g, 'Text', 'Strategy:');
    lblStrat.Layout.Row = 1; lblStrat.Layout.Column = 1;
    app.ZonesStrategyDropDown = uidropdown(g, ...
        'Items', {'corners-walls-center', 'strips', 'circle-rings', 'none'}, ...
        'ValueChangedFcn', @(~,~) onZoneStrategyChanged(app));
    app.ZonesStrategyDropDown.Layout.Row = 1; app.ZonesStrategyDropDown.Layout.Column = [2 3];
    bHelp = uibutton(g, 'Text', '?', ...
        'ButtonPushedFcn', @(~,~) showHelp('Zones', helpZonesText()));
    bHelp.Layout.Row = 1; bHelp.Layout.Column = 4;

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

    bAdd = uibutton(g, 'Text', 'Add to zones', ...
        'ButtonPushedFcn', @(~,~) app.addZones());
    bAdd.Layout.Row = 5; bAdd.Layout.Column = 1;
    bClear = uibutton(g, 'Text', 'Clear all', ...
        'ButtonPushedFcn', @(~,~) app.clearZones());
    bClear.Layout.Row = 5; bClear.Layout.Column = 2;

    app.AppliedZonesListBox = uilistbox(g, 'Items', {});
    app.AppliedZonesListBox.Layout.Row = 6; app.AppliedZonesListBox.Layout.Column = [1 4];

    onZoneStrategyChanged(app);  % set initial enable state
end

function buildSavePanel(app)
    g = uigridlayout(app.SavePanel, [1 3]);
    g.ColumnWidth = {130, 170, 50};
    bSave = uibutton(g, 'Text', 'Save preset', ...
        'ButtonPushedFcn', @(~,~) app.savePreset());
    bSave.Layout.Row = 1; bSave.Layout.Column = 1;
    bRun = uibutton(g, 'Text', 'Run analyzeSession', ...
        'ButtonPushedFcn', @(~,~) onRunAnalyze(app));
    bRun.Layout.Row = 1; bRun.Layout.Column = 2;
    bHelp = uibutton(g, 'Text', '?', ...
        'ButtonPushedFcn', @(~,~) showHelp('Save / Run', helpSaveText()));
    bHelp.Layout.Row = 1; bHelp.Layout.Column = 3;
end

function buildStatusPanel(app, parent)
    g = uigridlayout(parent, [1 1]);
    app.StatusBar = uilabel(g, 'Text', 'Ready');
end

% ========== Callbacks =====================================================

function onZoneStrategyChanged(app)
    s = app.ZonesStrategyDropDown.Value;
    set(app.WallWidthField,    'Enable', enableIfAny(s, {'corners-walls-center', 'circle-rings'}));
    set(app.MiddleWidthField,  'Enable', enableIfAny(s, {'circle-rings'}));
    set(app.NumStripsField,    'Enable', enableIfAny(s, {'strips'}));
    set(app.StripDirDropDown,  'Enable', enableIfAny(s, {'strips'}));
    set(app.ObjectZoneWidthField, 'Enable', toOnOff(~isempty(app.State.objects)));
end

function v = enableIfAny(s, list)
    v = toOnOff(any(strcmp(s, list)));
end

function s = toOnOff(b)
    if b; s = 'on'; else; s = 'off'; end
end

function onCalibrate(app)
    if isempty(app.State.frame)
        app.status('Load video first');
        return;
    end
    % Use sphynx.preset.pixelsPerCm with GUI-supplied distances (no command-line)
    [pxlAvg, kcorr] = sphynx.preset.pixelsPerCm(app.State.frame, ...
        'DistancesCm', [app.DistanceYField.Value, app.DistanceXField.Value]);
    % Recompute Y and X separately for display
    app.setPixelsPerCm(pxlAvg, 'Y', pxlAvg, 'X', pxlAvg / kcorr, 'KCorr', kcorr);
end

function onPickArena(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.ArenaGeometryDropDown.Value;
    try
        arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry);
        app.State.arena = arena;
        app.ArenaStatusLabel.Text = sprintf('Arena: %s OK', geometry);
        app.refreshPreview();
        sphynx.util.log('info', '[App] arena defined geometry=%s', geometry);
        % Re-run zone enable logic in case object-zone field state changed
        onZoneStrategyChanged(app);
    catch ME
        app.status(sprintf('Arena failed: %s', ME.message));
    end
end

function onAddObject(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.ObjectGeometryDropDown.Value;
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
        sphynx.util.log('info', '[App] object added geometry=%s total=%d', geometry, numel(app.State.objects));
        onZoneStrategyChanged(app);  % object-zone field becomes enabled
    catch ME
        app.status(sprintf('Object failed: %s', ME.message));
    end
end

function onRunAnalyze(app)
    app.status('Run analyzeSession from CLI: cfg = sphynx.pipeline.defaultConfig(); see docs.');
end

function pickDir(app, methodName)
    startDir = pickStart(app, '');
    d = uigetdir(startDir, 'Select directory');
    if isequal(d, 0); return; end
    app.(methodName)(d);
end

function pickDirStart(app, methodName)
    startDir = pickStart(app, '');
    d = uigetdir(startDir, 'Select directory');
    if isequal(d, 0); return; end
    app.(methodName)(d);
end

function pickVideoStart(app)
    startDir = pickStart(app, '');
    [f, p] = uigetfile({'*.mp4;*.avi;*.mov', 'Video files'}, 'Select video', startDir);
    if isequal(f, 0); return; end
    app.setVideo(fullfile(p, f));
end

function pickPresetStart(app)
    startDir = pickStart(app, '');
    [f, p] = uigetfile({'*.mat', 'Preset .mat'}, 'Select preset', startDir);
    if isequal(f, 0); return; end
    app.State.presetPath = fullfile(p, f);
    app.PresetPathField.Value = app.State.presetPath;
    preset = sphynx.io.readPreset(app.State.presetPath);
    if isfield(preset.Options, 'pxl2sm')
        kcorr = ifNaN(getOptField(preset.Options, 'x_kcorr'), 1);
        app.setPixelsPerCm(preset.Options.pxl2sm, 'Y', preset.Options.pxl2sm, ...
            'X', preset.Options.pxl2sm / kcorr, 'KCorr', kcorr);
    end
    app.status(sprintf('Loaded preset: %s', f));
end

function startDir = pickStart(app, fallback)
    if ~isempty(app.State.projectRoot) && isfolder(app.State.projectRoot)
        startDir = app.State.projectRoot;
    else
        startDir = fallback;
    end
end

function refreshAppField(~, ~)
    % Hook for binding refresh; no-op (the field updates via setter)
end

% ========== Help text and dialog =========================================

function showHelp(title, text)
    msgbox(text, title, 'help', 'modal');
end

function txt = helpCalibrationText()
    txt = {
        'Calibration: convert pixels to centimeters.';
        '';
        'You need to know the REAL distance in cm between two pairs';
        'of points on the video — typically along arena walls.';
        '';
        '1) Enter the cm distance for vertical pair (points 1 -> 2)';
        '   into the "cm Y" field.';
        '2) Enter the cm distance for horizontal pair (3 -> 4) into "cm X".';
        '3) Click "Calibrate (4 clicks)".';
        '4) Click 4 points on the preview frame in the order:';
        '   point 1 (top), point 2 (bottom), point 3 (left), point 4 (right).';
        '5) Read the resulting Y, X, avg pxl/cm and kcorr (X/Y ratio).';
        '';
        'If kcorr deviates from 1 by more than ~3% the camera has';
        'unequal vertical/horizontal scale — keep this in mind.';
    };
end

function txt = helpArenaText()
    txt = {
        'Define the arena boundary on the current preview frame.';
        '';
        '1) Choose geometry: Polygon (clicks corners), Circle (>=3 pts on rim),';
        '   Ellipse (>=5 pts on rim), or O-maze (>=3 pts outer + >=3 pts inner).';
        '2) Click "Pick arena points".';
        '3) Click points on the preview, then press ENTER.';
        '4) The polygon outline appears in black.';
    };
end

function txt = helpObjectsText()
    txt = {
        'Add objects (food bowls, novel objects, etc.) on the arena.';
        '';
        '1) Choose object geometry.';
        '2) Click "+ Add object", then click points + ENTER.';
        '3) Repeat for each object. Up to 4 named objects supported by';
        '   downstream zone acts.';
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
        'You can ADD multiple strategies (e.g., corners-walls-center';
        'PLUS strips). Use "Clear all" to reset.';
        '';
        'Object zone (cm): inflated radius around each object that counts';
        'as object interaction. Enabled only when objects are defined.';
        '';
        'Implicit "outside-wall" 10 cm offset is always applied internally';
        'to wall/corner/center calculations (matches legacy default). It';
        'is not exposed in the UI.';
    };
end

function txt = helpSaveText()
    txt = {
        'Save the assembled preset to <output_dir>/<videobase>_Preset.mat.';
        '';
        '"Run analyzeSession" is a placeholder reminder: launch the';
        'pipeline from the MATLAB Command Window with:';
        '   cfg = sphynx.pipeline.defaultConfig();';
        '   cfg.paths.dlc = ''.../DLC/<file>.csv'';';
        '   cfg.paths.preset = ''<the saved preset>'';';
        '   sphynx.pipeline.analyzeSession(cfg);';
    };
end

% ========== Helpers =========================================================

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

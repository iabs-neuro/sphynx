classdef CreatePresetApp < handle
% CREATEPRESETAPP  Single-window preset builder for sphynx.
%
%   sphynx.app.CreatePresetApp() opens a uifigure-based preset editor.
%   Layout is inspired by Ziv lab's CellReg: a single window with
%   sequential panels (Load -> Calibration -> Arena -> Objects ->
%   Zones -> Preview -> Save), parameter fields per panel, and a
%   live preview of the current state.
%
%   Implementation: a hand-written class derived from `handle`,
%   not an App Designer .mlapp. Reasons:
%     - .mlapp is binary; harder to diff in git
%     - All logic lives in +sphynx/+preset/* (pure functions); the
%       app is just a thin UI shell over them
%
%   Built for MATLAB R2020a (uifigure / uigridlayout supported since
%   R2018a).
%
%   The app instance is returned so it can be programmatically driven
%   by tests (call methods directly, then `delete(app)`).

    properties
        Figure
        Grid
        % Panels
        LoadPanel
        CalibPanel
        ArenaPanel
        ObjectsPanel
        ZonesPanel
        PreviewPanel
        SavePanel
        % Component handles needed by callbacks
        VideoPathLabel
        OutDirLabel
        PxlPerCmLabel
        ExpTypeDropDown
        ArenaGeometryDropDown
        ArenaStatusLabel
        ObjectsListBox
        ObjectGeometryDropDown
        ZonesStrategyDropDown
        WallWidthField
        MiddleWidthField
        NumStripsField
        StripDirDropDown
        PreviewAxes
        StatusBar
    end

    properties
        % Mutable state — a single struct that captures the in-progress preset.
        % Public so tests can inject synthetic frames; ordinary callers
        % should use the setVideo/setOutDir/setArena/etc methods.
        State
    end

    methods
        function app = CreatePresetApp(varargin)
            app.State = sphynx.app.CreatePresetApp.emptyState();
            app.buildUI();
        end

        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                close(app.Figure);
            end
        end

        % --- Programmatic API for tests ---------------------------------------
        function setVideo(app, path)
            app.State.videoPath = path;
            try
                gframe = sphynx.preset.pickGoodFrame(path, 'FrameIndex', 1);
                app.State.frame = gframe.frame;
                app.State.frameRate = gframe.frameRate;
                app.State.numFrames = gframe.numFrames;
                app.State.height = gframe.height;
                app.State.width = gframe.width;
                app.VideoPathLabel.Text = sprintf('Video: %s (%dx%d, %d fr)', ...
                    pathTail(path), app.State.width, app.State.height, app.State.numFrames);
                app.refreshPreview();
                app.status('Video loaded');
            catch ME
                app.status(sprintf('Video load failed: %s', ME.message));
            end
        end

        function setOutDir(app, dir)
            app.State.outDir = dir;
            app.OutDirLabel.Text = sprintf('Output: %s', dir);
        end

        function setPixelsPerCm(app, value)
            app.State.pxlPerCm = value;
            app.PxlPerCmLabel.Text = sprintf('px/cm: %.2f', value);
        end

        function setArena(app, geometry, points)
            % Skip the dialog by passing 'Points' override
            arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
                'Points', points);
            app.State.arena = arena;
            app.ArenaStatusLabel.Text = sprintf('Arena: %s OK', geometry);
            app.refreshPreview();
        end

        function addObject(app, geometry, points)
            obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, 'Points', points);
            obj.type = sprintf('Object%d', numel(app.State.objects) + 1);
            if isempty(app.State.objects)
                app.State.objects = obj;
            else
                app.State.objects(end+1) = obj;
            end
            app.refreshObjectsList();
            app.refreshPreview();
        end

        function buildZones(app)
            if isempty(app.State.arena)
                app.status('Define arena first');
                return;
            end
            strategy = app.ZonesStrategyDropDown.Value;
            switch strategy
                case 'corners-walls-center'
                    Zones = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                        'Strategy', 'corners-walls-center', ...
                        'PixelsPerCm', app.State.pxlPerCm, ...
                        'WallWidthCm', str2double(app.WallWidthField.Value), ...
                        'CornerPoints', cornerPointsFromArena(app.State.arena));
                case 'strips'
                    Zones = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                        'Strategy', 'strips', ...
                        'NumStrips', str2double(app.NumStripsField.Value), ...
                        'StripDirection', app.StripDirDropDown.Value);
                case 'circle-rings'
                    Zones = sphynx.preset.buildZonesCircle(app.State.arena.mask, ...
                        'PixelsPerCm', app.State.pxlPerCm, ...
                        'WallWidthCm', str2double(app.WallWidthField.Value), ...
                        'MiddleWidthCm', str2double(app.MiddleWidthField.Value));
                case 'none'
                    Zones = sphynx.preset.buildZonesSquare(app.State.arena.mask, ...
                        'Strategy', 'none');
            end
            app.State.zones = Zones;
            app.refreshPreview();
            app.status(sprintf('Zones built: %d zones (%s)', numel(Zones), strategy));
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
            % Assemble legacy-shape preset
            Options = struct();
            Options.ExperimentType = app.ExpTypeDropDown.Value;
            Options.pxl2sm = app.State.pxlPerCm;
            Options.x_kcorr = 1;
            Options.FrameRate = app.State.frameRate;
            Options.NumFrames = app.State.numFrames;
            Options.Height = app.State.height;
            Options.Width = app.State.width;
            Options.LikelihoodThreshold = 0.95;
            Options.velocity_rest = 1;
            Options.velocity_locomotion = 5;
            Options.BodyPart.Velocity = 'bodycenter';

            ArenaAndObjects = struct( ...
                'type', {}, 'geometry', {}, 'maskborder', {}, 'maskfilled', {}, ...
                'border_x', {}, 'border_y', {}, 'border_separate_x', {}, 'border_separate_y', {});
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

            Zones = app.State.zones;
            if isempty(Zones)
                Zones = struct('name', {}, 'type', {}, 'maskfilled', {});
            end

            [~, baseName, ~] = fileparts(app.State.videoPath);
            outPath = fullfile(app.State.outDir, sprintf('%s_Preset.mat', baseName));
            save(outPath, 'Options', 'Zones', 'ArenaAndObjects');
            app.status(sprintf('Saved preset to %s', outPath));
        end
    end

    methods (Access = private)
        function buildUI(app)
            app.Figure = uifigure('Name', 'sphynx — Create Preset', ...
                'Position', [100, 100, 1000, 720], 'Visible', 'on');

            app.Grid = uigridlayout(app.Figure, [7, 2]);
            app.Grid.RowHeight = {70, 60, 60, 80, 110, '1x', 50};
            app.Grid.ColumnWidth = {'1x', 380};

            % Row 1: Load panel (full width)
            app.LoadPanel = uipanel(app.Grid, 'Title', '1. Load');
            app.LoadPanel.Layout.Row = 1; app.LoadPanel.Layout.Column = [1 2];
            buildLoadPanel(app);

            % Row 2: Calibration
            app.CalibPanel = uipanel(app.Grid, 'Title', '2. Calibration');
            app.CalibPanel.Layout.Row = 2; app.CalibPanel.Layout.Column = [1 2];
            buildCalibPanel(app);

            % Row 3: Arena
            app.ArenaPanel = uipanel(app.Grid, 'Title', '3. Arena');
            app.ArenaPanel.Layout.Row = 3; app.ArenaPanel.Layout.Column = [1 2];
            buildArenaPanel(app);

            % Row 4: Objects
            app.ObjectsPanel = uipanel(app.Grid, 'Title', '4. Objects');
            app.ObjectsPanel.Layout.Row = 4; app.ObjectsPanel.Layout.Column = [1 2];
            buildObjectsPanel(app);

            % Row 5: Zones
            app.ZonesPanel = uipanel(app.Grid, 'Title', '5. Zones');
            app.ZonesPanel.Layout.Row = 5; app.ZonesPanel.Layout.Column = [1 2];
            buildZonesPanel(app);

            % Row 6: Preview
            app.PreviewPanel = uipanel(app.Grid, 'Title', 'Preview');
            app.PreviewPanel.Layout.Row = 6; app.PreviewPanel.Layout.Column = [1 2];
            pg = uigridlayout(app.PreviewPanel, [1 1]);
            app.PreviewAxes = uiaxes(pg);

            % Row 7: Save (full width)
            app.SavePanel = uipanel(app.Grid, 'Title', 'Save');
            app.SavePanel.Layout.Row = 7; app.SavePanel.Layout.Column = [1 2];
            buildSavePanel(app);
        end

        function status(app, msg)
            app.StatusBar.Text = msg;
            sphynx.util.log('info', '[CreatePresetApp] %s', msg);
        end

        function refreshPreview(app)
            if isempty(app.State.frame); return; end
            cla(app.PreviewAxes);
            imshow(app.State.frame, 'Parent', app.PreviewAxes);
            hold(app.PreviewAxes, 'on');
            if ~isempty(app.State.arena)
                plot(app.PreviewAxes, app.State.arena.border_x, app.State.arena.border_y, ...
                    'k-', 'LineWidth', 2);
            end
            for k = 1:numel(app.State.objects)
                plot(app.PreviewAxes, app.State.objects(k).border_x, app.State.objects(k).border_y, ...
                    'g-', 'LineWidth', 2);
            end
            for k = 1:numel(app.State.zones)
                z = app.State.zones(k);
                if isnumeric(z.maskfilled) || islogical(z.maskfilled)
                    [r, c] = find(z.maskfilled);
                    if ~isempty(r)
                        scatter(app.PreviewAxes, c, r, 1, 'b', 'filled', 'MarkerFaceAlpha', 0.05);
                    end
                end
            end
            hold(app.PreviewAxes, 'off');
        end

        function refreshObjectsList(app)
            items = arrayfun(@(o) sprintf('%s (%s)', o.type, o.geometry), ...
                app.State.objects, 'UniformOutput', false);
            app.ObjectsListBox.Items = items;
        end
    end

    methods (Static)
        function s = emptyState()
            s.videoPath = '';
            s.outDir = '';
            s.frame = [];
            s.frameRate = NaN;
            s.numFrames = NaN;
            s.height = NaN;
            s.width = NaN;
            s.pxlPerCm = NaN;
            s.arena = [];
            s.objects = struct('type', {}, 'geometry', {}, 'border_x', {}, 'border_y', {}, ...
                                'border_separate_x', {}, 'border_separate_y', {}, 'mask', {});
            s.zones = struct('name', {}, 'type', {}, 'maskfilled', {});
        end
    end
end

% ========== Panel builders (separate functions for readability) ==========

function buildLoadPanel(app)
    g = uigridlayout(app.LoadPanel, [2 4]);
    g.RowHeight = {25, 25};
    g.ColumnWidth = {130, 130, 130, '1x'};
    bLoadVid = uibutton(g, 'Text', 'Load video...', ...
        'ButtonPushedFcn', @(~,~) onLoadVideo(app));
    bLoadVid.Layout.Row = 1; bLoadVid.Layout.Column = 1;
    bOutDir = uibutton(g, 'Text', 'Output dir...', ...
        'ButtonPushedFcn', @(~,~) onPickOutDir(app));
    bOutDir.Layout.Row = 1; bOutDir.Layout.Column = 2;
    bLoadPreset = uibutton(g, 'Text', 'Load preset...', ...
        'ButtonPushedFcn', @(~,~) onLoadPreset(app));
    bLoadPreset.Layout.Row = 1; bLoadPreset.Layout.Column = 3;
    app.VideoPathLabel = uilabel(g, 'Text', 'Video: <none>');
    app.VideoPathLabel.Layout.Row = 2; app.VideoPathLabel.Layout.Column = [1 2];
    app.OutDirLabel = uilabel(g, 'Text', 'Output: <none>');
    app.OutDirLabel.Layout.Row = 2; app.OutDirLabel.Layout.Column = [3 4];
end

function buildCalibPanel(app)
    g = uigridlayout(app.CalibPanel, [2 4]);
    g.RowHeight = {25, 25};
    g.ColumnWidth = {180, 100, 200, '1x'};
    bCalib = uibutton(g, 'Text', 'Calibrate from frame', ...
        'ButtonPushedFcn', @(~,~) onCalibrate(app));
    bCalib.Layout.Row = 1; bCalib.Layout.Column = 1;
    app.PxlPerCmLabel = uilabel(g, 'Text', 'px/cm: ?');
    app.PxlPerCmLabel.Layout.Row = 1; app.PxlPerCmLabel.Layout.Column = 2;
    lblExp = uilabel(g, 'Text', 'Experiment type:');
    lblExp.Layout.Row = 2; lblExp.Layout.Column = 1;
    app.ExpTypeDropDown = uidropdown(g, ...
        'Items', {'Novelty OF','BowlsOpenField','NOL','Holes Track','Odor Track', ...
                  'Freezing Track','New Track','Complex Context','OF_Obj','3DM'});
    app.ExpTypeDropDown.Layout.Row = 2; app.ExpTypeDropDown.Layout.Column = 2;
end

function buildArenaPanel(app)
    g = uigridlayout(app.ArenaPanel, [2 4]);
    g.RowHeight = {25, 25};
    g.ColumnWidth = {130, 150, 200, '1x'};
    lblGeom = uilabel(g, 'Text', 'Geometry:');
    lblGeom.Layout.Row = 1; lblGeom.Layout.Column = 1;
    app.ArenaGeometryDropDown = uidropdown(g, ...
        'Items', {'Polygon', 'Circle', 'Ellipse', 'O-maze'});
    app.ArenaGeometryDropDown.Layout.Row = 1; app.ArenaGeometryDropDown.Layout.Column = 2;
    bArena = uibutton(g, 'Text', 'Pick arena points', ...
        'ButtonPushedFcn', @(~,~) onPickArena(app));
    bArena.Layout.Row = 1; bArena.Layout.Column = 3;
    app.ArenaStatusLabel = uilabel(g, 'Text', 'Arena: <none>');
    app.ArenaStatusLabel.Layout.Row = 2; app.ArenaStatusLabel.Layout.Column = [1 4];
end

function buildObjectsPanel(app)
    g = uigridlayout(app.ObjectsPanel, [2 4]);
    g.RowHeight = {25, '1x'};
    g.ColumnWidth = {130, 150, 100, '1x'};
    lblObjGeom = uilabel(g, 'Text', 'Geometry:');
    lblObjGeom.Layout.Row = 1; lblObjGeom.Layout.Column = 1;
    app.ObjectGeometryDropDown = uidropdown(g, ...
        'Items', {'Polygon', 'Circle', 'Ellipse'});
    app.ObjectGeometryDropDown.Layout.Row = 1; app.ObjectGeometryDropDown.Layout.Column = 2;
    bAdd = uibutton(g, 'Text', '+ Add object', ...
        'ButtonPushedFcn', @(~,~) onAddObject(app));
    bAdd.Layout.Row = 1; bAdd.Layout.Column = 3;
    app.ObjectsListBox = uilistbox(g, 'Items', {});
    app.ObjectsListBox.Layout.Row = 2; app.ObjectsListBox.Layout.Column = [1 4];
end

function buildZonesPanel(app)
    g = uigridlayout(app.ZonesPanel, [3 6]);
    g.RowHeight = {25, 25, 30};
    g.ColumnWidth = {120, 180, 90, 80, 90, 80};
    lblStrat = uilabel(g, 'Text', 'Strategy:');
    lblStrat.Layout.Row = 1; lblStrat.Layout.Column = 1;
    app.ZonesStrategyDropDown = uidropdown(g, ...
        'Items', {'corners-walls-center', 'strips', 'circle-rings', 'none'});
    app.ZonesStrategyDropDown.Layout.Row = 1; app.ZonesStrategyDropDown.Layout.Column = 2;

    lblWall = uilabel(g, 'Text', 'Wall (cm):');
    lblWall.Layout.Row = 2; lblWall.Layout.Column = 3;
    app.WallWidthField = uieditfield(g, 'text', 'Value', '3');
    app.WallWidthField.Layout.Row = 2; app.WallWidthField.Layout.Column = 4;
    lblMid = uilabel(g, 'Text', 'Middle (cm):');
    lblMid.Layout.Row = 2; lblMid.Layout.Column = 5;
    app.MiddleWidthField = uieditfield(g, 'text', 'Value', '20');
    app.MiddleWidthField.Layout.Row = 2; app.MiddleWidthField.Layout.Column = 6;

    lblN = uilabel(g, 'Text', 'N strips:');
    lblN.Layout.Row = 3; lblN.Layout.Column = 1;
    app.NumStripsField = uieditfield(g, 'text', 'Value', '3');
    app.NumStripsField.Layout.Row = 3; app.NumStripsField.Layout.Column = 2;
    lblDir = uilabel(g, 'Text', 'Strip dir:');
    lblDir.Layout.Row = 3; lblDir.Layout.Column = 3;
    app.StripDirDropDown = uidropdown(g, 'Items', {'horizontal','vertical'});
    app.StripDirDropDown.Layout.Row = 3; app.StripDirDropDown.Layout.Column = 4;
    bCompute = uibutton(g, 'Text', 'Compute zones', ...
        'ButtonPushedFcn', @(~,~) app.buildZones());
    bCompute.Layout.Row = 3; bCompute.Layout.Column = [5 6];
end

function buildSavePanel(app)
    g = uigridlayout(app.SavePanel, [1 3]);
    g.ColumnWidth = {150, 200, '1x'};
    bSave = uibutton(g, 'Text', 'Save preset', ...
        'ButtonPushedFcn', @(~,~) app.savePreset());
    bSave.Layout.Row = 1; bSave.Layout.Column = 1;
    bRun = uibutton(g, 'Text', 'Run analyzeSession', ...
        'ButtonPushedFcn', @(~,~) onRunAnalyze(app));
    bRun.Layout.Row = 1; bRun.Layout.Column = 2;
    app.StatusBar = uilabel(g, 'Text', 'Ready');
    app.StatusBar.Layout.Row = 1; app.StatusBar.Layout.Column = 3;
end

% ========== Button callbacks ==========

function onLoadVideo(app)
    [f, p] = uigetfile({'*.mp4;*.avi;*.mov', 'Video files'}, 'Select video', '');
    if isequal(f, 0); return; end
    app.setVideo(fullfile(p, f));
end

function onPickOutDir(app)
    d = uigetdir('', 'Select output directory');
    if isequal(d, 0); return; end
    app.setOutDir(d);
end

function onLoadPreset(app)
    [f, p] = uigetfile({'*.mat', 'Preset .mat'}, 'Select preset', '');
    if isequal(f, 0); return; end
    preset = sphynx.io.readPreset(fullfile(p, f));
    if isfield(preset.Options, 'pxl2sm')
        app.setPixelsPerCm(preset.Options.pxl2sm);
    end
    app.status(sprintf('Loaded preset: %s', f));
end

function onCalibrate(app)
    if isempty(app.State.frame)
        app.status('Load video first');
        return;
    end
    [pxl, ~] = sphynx.preset.pixelsPerCm(app.State.frame);
    app.setPixelsPerCm(pxl);
end

function onPickArena(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.ArenaGeometryDropDown.Value;
    arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry);
    app.State.arena = arena;
    app.ArenaStatusLabel.Text = sprintf('Arena: %s OK', geometry);
    app.refreshPreview();
end

function onAddObject(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    geometry = app.ObjectGeometryDropDown.Value;
    obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry);
    obj.type = sprintf('Object%d', numel(app.State.objects) + 1);
    if isempty(app.State.objects)
        app.State.objects = obj;
    else
        app.State.objects(end+1) = obj;
    end
    app.refreshObjectsList();
    app.refreshPreview();
end

function onRunAnalyze(app)
    if isempty(app.State.outDir)
        app.status('Set output directory and save preset first');
        return;
    end
    app.savePreset();
    cfg = sphynx.pipeline.defaultConfig();
    [~, baseName, ~] = fileparts(app.State.videoPath);
    cfg.paths.dlc = fullfile(app.State.outDir, sprintf('%sDLC*.csv', baseName));
    cfg.paths.preset = fullfile(app.State.outDir, sprintf('%s_Preset.mat', baseName));
    cfg.paths.outDir = app.State.outDir;
    app.status('Running analyzeSession... (placeholder — wire DLC path manually)');
end

% ========== Helpers ==========

function p = pathTail(fullPath)
    [~, name, ext] = fileparts(fullPath);
    p = [name ext];
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

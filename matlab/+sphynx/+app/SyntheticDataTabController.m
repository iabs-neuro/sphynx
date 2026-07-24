classdef SyntheticDataTabController < handle
% SYNTHETICDATATABCONTROLLER  Controller for the "Synthetic Data" tab.
%
%   Generates DLC-style traces and an accompanying minimal preset for
%   testing the preprocess pipeline on controlled inputs (clean baselines,
%   spike storms, long gaps, poor-likelihood scenarios).

    properties
        Tab
        Figure
        ParentApp

        % Settings widgets
        NFramesField
        NPartsField
        WField
        HField
        FpsField
        PpcField
        MotionDropDown
        OutlierDropDown
        SeedField
        OutDirField

        % Preview
        PreviewAxes
        PartDropDown

        % Internal
        Data    % last generated struct
    end

    methods
        function obj = SyntheticDataTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.buildUI();
        end

        function delete(~)
            % uifigure cleanup is handled by CreatePresetApp
        end

        function generate(obj)
            opts = obj.collectOpts();
            try
                obj.Data = sphynx.preprocess.makeSyntheticDLC(opts{:});
            catch ME
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    uialert(obj.Figure, ME.message, 'Generate failed', 'Icon', 'error');
                end
                return;
            end
            obj.refreshPartDropDown();
            obj.refreshPreview();
        end

        function saveToFolder(obj)
            if isempty(obj.Data)
                obj.generate();
                if isempty(obj.Data); return; end
            end
            outDir = obj.OutDirField.Value;
            if isempty(outDir)
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    uialert(obj.Figure, 'Pick an output dir first', 'Save', 'Icon', 'warning');
                end
                return;
            end
            if ~isfolder(outDir); mkdir(outDir); end
            csvPath = fullfile(outDir, 'synthetic_DLC.csv');
            opts = obj.collectOpts();
            opts{end+1} = 'CsvPath';
            opts{end+1} = csvPath;
            obj.Data = sphynx.preprocess.makeSyntheticDLC(opts{:});
            % Minimal preset: just enough for analyzeSession bounds + units
            Options.Width = obj.Data.frameWidth;
            Options.Height = obj.Data.frameHeight;
            Options.FrameRate = obj.Data.frameRate;
            Options.pxl2sm = obj.Data.pixelsPerCm;
            Options.GoodVideoFrame = uint8(zeros(obj.Data.frameHeight, obj.Data.frameWidth, 3) + 64);
            Zones = struct('name', {}, 'type', {}, 'maskfilled', {}); %#ok<NASGU>
            ArenaAndObjects = struct('type', {}, 'geometry', {}); %#ok<NASGU>
            presetPath = fullfile(outDir, 'synthetic_Preset.mat');
            save(presetPath, 'Options', 'Zones', 'ArenaAndObjects');
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                uialert(obj.Figure, ...
                    sprintf('Saved:\n%s\n%s', csvPath, presetPath), ...
                    'Saved', 'Icon', 'success');
            end
        end
    end

    methods (Access = private)
        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [1, 2]);
            outer.ColumnWidth = {360, '1x'};
            outer.RowHeight = {'1x'};
            outer.Padding = [4 4 4 4];

            % LEFT: settings
            left = uigridlayout(outer, [13, 2]);
            left.RowHeight = repmat({28}, 1, 13);
            left.ColumnWidth = {120, '1x'};
            left.RowSpacing = 4;
            left.ColumnSpacing = 4;
            left.Padding = [4 4 4 4];

            row = 0;
            row = row+1; uilabel(left, 'Text', 'Synthetic Data Generator', 'FontWeight', 'bold');
            uilabel(left, 'Text', '');

            row = row+1; uilabel(left, 'Text', 'N frames:'); ...
                obj.NFramesField = uieditfield(left, 'numeric', 'Value', 6000, 'Limits', [10 1e7], 'RoundFractionalValues', 'on');
            row = row+1; uilabel(left, 'Text', 'N body parts:'); ...
                obj.NPartsField = uieditfield(left, 'numeric', 'Value', 10, 'Limits', [1 50], 'RoundFractionalValues', 'on');
            row = row+1; uilabel(left, 'Text', 'Frame W (px):'); ...
                obj.WField = uieditfield(left, 'numeric', 'Value', 800, 'Limits', [50 8000], 'RoundFractionalValues', 'on');
            row = row+1; uilabel(left, 'Text', 'Frame H (px):'); ...
                obj.HField = uieditfield(left, 'numeric', 'Value', 600, 'Limits', [50 8000], 'RoundFractionalValues', 'on');
            row = row+1; uilabel(left, 'Text', 'Frame rate:'); ...
                obj.FpsField = uieditfield(left, 'numeric', 'Value', 30, 'Limits', [1 1000]);
            row = row+1; uilabel(left, 'Text', 'pxl/cm:'); ...
                obj.PpcField = uieditfield(left, 'numeric', 'Value', 5, 'Limits', [0.1 1000]);
            row = row+1; uilabel(left, 'Text', 'Motion model:'); ...
                obj.MotionDropDown = uidropdown(left, 'Items', {'random_walk', 'circular', 'OU'}, 'Value', 'random_walk');
            row = row+1; uilabel(left, 'Text', 'Outlier mode:'); ...
                obj.OutlierDropDown = uidropdown(left, 'Items', {'none', 'spikes', 'long_gap', 'poor_likelihood', 'mixed'}, 'Value', 'mixed');
            row = row+1; uilabel(left, 'Text', 'Seed:'); ...
                obj.SeedField = uieditfield(left, 'numeric', 'Value', 42, 'RoundFractionalValues', 'on');

            row = row+1; uilabel(left, 'Text', 'Output dir:');
            obj.OutDirField = uieditfield(left, 'text', 'Value', '');

            row = row+1;
            bGen = uibutton(left, 'Text', 'Generate', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.generate());
            bGen.Layout.Row = row; bGen.Layout.Column = 1;
            bSave = uibutton(left, 'Text', 'Save to folder', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.saveToFolder());
            bSave.Layout.Row = row; bSave.Layout.Column = 2;

            row = row+1;
            bPickDir = uibutton(left, 'Text', 'Browse output dir', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickDir());
            bPickDir.Layout.Row = row; bPickDir.Layout.Column = [1 2];

            % RIGHT: preview
            right = uigridlayout(outer, [3, 1]);
            right.RowHeight = {'1x', 30, '1x'};
            right.RowSpacing = 4;
            right.Padding = [2 2 2 2];

            obj.PreviewAxes = uiaxes(right);
            obj.PreviewAxes.Layout.Row = 1;
            title(obj.PreviewAxes, 'X(t) for selected part');
            grid(obj.PreviewAxes, 'on');

            partRow = uigridlayout(right, [1, 2]);
            partRow.Layout.Row = 2;
            partRow.RowHeight = {28};
            partRow.ColumnWidth = {80, '1x'};
            uilabel(partRow, 'Text', 'preview part:');
            obj.PartDropDown = uidropdown(partRow, 'Items', {'(none)'}, 'Value', '(none)', ...
                'ValueChangedFcn', @(~,~) obj.refreshPreview());

            obj.PreviewAxes2 = uiaxes(right); %#ok<MCNPN>
            obj.PreviewAxes2.Layout.Row = 3;
            title(obj.PreviewAxes2, 'Likelihood histogram');
            grid(obj.PreviewAxes2, 'on');
        end

        function pickDir(obj)
            sel = uigetdir(pwd, 'Select output dir for synthetic data');
            if isequal(sel, 0); return; end
            obj.OutDirField.Value = sel;
        end

        function refreshPartDropDown(obj)
            if isempty(obj.Data); return; end
            obj.PartDropDown.Items = obj.Data.bodyPartsNames;
            obj.PartDropDown.Value = obj.Data.bodyPartsNames{1};
        end

        function refreshPreview(obj)
            if isempty(obj.Data); return; end
            idx = find(strcmp(obj.PartDropDown.Items, obj.PartDropDown.Value), 1);
            if isempty(idx); return; end
            cla(obj.PreviewAxes);
            plot(obj.PreviewAxes, obj.Data.X(idx, :), 'Color', [0.10 0.40 0.80]);
            title(obj.PreviewAxes, sprintf('%s — X (px)', obj.Data.bodyPartsNames{idx}), 'Interpreter', 'none');
            xlabel(obj.PreviewAxes, 'frame'); ylabel(obj.PreviewAxes, 'X');
            grid(obj.PreviewAxes, 'on');

            cla(obj.PreviewAxes2);
            histogram(obj.PreviewAxes2, obj.Data.likelihood(idx, :), 'BinWidth', 0.01, ...
                'FaceColor', [0.30 0.60 0.30], 'EdgeColor', 'none');
            title(obj.PreviewAxes2, sprintf('%s — likelihood', obj.Data.bodyPartsNames{idx}), 'Interpreter', 'none');
            xlim(obj.PreviewAxes2, [0 1]); grid(obj.PreviewAxes2, 'on');
        end

        function opts = collectOpts(obj)
            % Keep only the first N parts from the default list (since the
            % user picks the count, not the names).
            allParts = {'nose', 'leftear', 'rightear', 'headcenter', ...
                       'leftforelimb', 'rightforelimb', ...
                       'leftbody', 'rightbody', ...
                       'lefthindlimb', 'righthindlimb', ...
                       'tailbase', 'bodycenter', ...
                       'extra1', 'extra2', 'extra3', 'extra4', 'extra5', ...
                       'extra6', 'extra7', 'extra8', 'extra9', 'extra10'};
            nP = max(1, min(numel(allParts), obj.NPartsField.Value));
            parts = allParts(1:nP);
            opts = { ...
                'NFrames',     obj.NFramesField.Value, ...
                'BodyParts',   parts, ...
                'FrameWidth',  obj.WField.Value, ...
                'FrameHeight', obj.HField.Value, ...
                'FrameRate',   obj.FpsField.Value, ...
                'PixelsPerCm', obj.PpcField.Value, ...
                'MotionModel', obj.MotionDropDown.Value, ...
                'OutlierMode', obj.OutlierDropDown.Value, ...
                'Seed',        obj.SeedField.Value};
        end
    end

    properties (Access = private)
        PreviewAxes2
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

classdef PreprocessVideoTabController < handle
% PREPROCESSVIDEOTABCONTROLLER  Video preprocessing utilities — wrappers
% around the existing scripts in /Preprocess (getVideoMetadata,
% getTimestampMetadata, fixFPSmetadata, recodeVideoToFPS).
%
% MVP scope:
%   * Pick a folder of videos (or a single file).
%   * Inspect metadata (FPS / duration / resolution) in a table.
%   * Buttons: fix FPS, recode to FPS, batch process.

    properties
        Tab
        Figure
        ParentApp

        FolderField
        TargetFpsField
        VideoTable
        LogTextArea

        State
    end

    methods
        function obj = PreprocessVideoTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = struct('files', {{}});
            obj.buildUI();
        end

        function delete(~)
        end

        function pickFolder(obj)
            startDir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                startDir = obj.ParentApp.State.projectRoot;
            end
            d = uigetdir(startDir, 'Pick video folder');
            if isequal(d, 0); return; end
            obj.FolderField.Value = d;
            obj.scanFolder();
        end

        function scanFolder(obj)
            d = obj.FolderField.Value;
            if isempty(d) || ~isfolder(d)
                obj.applog('warn', 'Folder not found: %s', d);
                return;
            end
            files = [dir(fullfile(d, '*.mp4')); dir(fullfile(d, '*.avi'));
                     dir(fullfile(d, '*.mov'))];
            obj.State.files = arrayfun(@(f) fullfile(f.folder, f.name), files, ...
                'UniformOutput', false);
            obj.refreshTable();
        end

        function refreshTable(obj)
            n = numel(obj.State.files);
            data = cell(n, 5);
            for k = 1:n
                p = obj.State.files{k};
                [~, base, ext] = fileparts(p);
                row = {[base ext], '?', '?', '?', '?'};
                try
                    v = VideoReader(p);
                    row{2} = sprintf('%.2f', v.FrameRate);
                    row{3} = v.NumFrames;
                    row{4} = sprintf('%dx%d', v.Width, v.Height);
                    row{5} = sprintf('%.1f s', v.Duration);
                catch
                end
                data(k, :) = row;
            end
            obj.VideoTable.Data = data;
        end

        function fixFPS(obj)
            tgt = obj.TargetFpsField.Value;
            if isempty(obj.State.files)
                obj.applog('warn', 'No videos. Pick a folder first.'); return;
            end
            obj.applog('info', 'fixFPSmetadata @ %.2f fps for %d files', tgt, numel(obj.State.files));
            for k = 1:numel(obj.State.files)
                try
                    if exist('fixFPSmetadata', 'file')
                        fixFPSmetadata(obj.State.files{k}, tgt);
                    end
                    obj.applog('info', '  ok: %s', obj.basename(obj.State.files{k}));
                catch ME
                    obj.applog('error', '  fail %s: %s', ...
                        obj.basename(obj.State.files{k}), ME.message);
                end
            end
            obj.refreshTable();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            outer = uigridlayout(obj.Tab, [4, 4]);
            outer.RowHeight = {32, 32, '1x', 110};
            outer.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            outer.RowSpacing = 4;
            outer.ColumnSpacing = 4;
            outer.Padding = [4 4 4 4];

            % Row 1: folder
            uilabel(outer, 'Text', 'Video folder:');
            obj.FolderField = uieditfield(outer, 'text', 'Value', '');
            uibutton(outer, 'Text', 'Browse', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickFolder());
            uibutton(outer, 'Text', 'Scan', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.scanFolder());

            % Row 2: target FPS + actions
            uilabel(outer, 'Text', 'Target FPS:');
            obj.TargetFpsField = uieditfield(outer, 'numeric', 'Value', 30, 'Limits', [1 240]);
            uibutton(outer, 'Text', 'Fix FPS metadata', 'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) obj.fixFPS());
            uilabel(outer, 'Text', '');

            % Row 3: video table spanning all 4 columns
            obj.VideoTable = uitable(outer, ...
                'ColumnName', {'file', 'fps', 'frames', 'resolution', 'duration'});
            obj.VideoTable.Layout.Row = 3;
            obj.VideoTable.Layout.Column = [1 4];

            % Row 4: log spanning all 4 columns
            obj.LogTextArea = uitextarea(outer, 'Editable', 'off', 'Value', {''});
            obj.LogTextArea.Layout.Row = 4;
            obj.LogTextArea.Layout.Column = [1 4];
        end

        function s = basename(~, p)
            [~, b, e] = fileparts(p);
            s = [b e];
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[PreprocVid] ' fmt], varargin{:});
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

classdef DefineActsTabController < handle
% DEFINEACTSTABCONTROLLER  Build, edit and persist a library of behavioral
% acts for an experiment. Two construction modes:
%
%   * Simple act: name + zone(s) (with logical op between them) + body
%     part + speed range. Yields a per-frame boolean array.
%
%   * Complex act: combine N already-defined acts via a logical
%     operation: intersect / union / exclude / sequence (act A then B
%     within delta seconds).
%
% Acts are stored as a struct array and persisted as
%   <root>/<expType>_acts.mat   (Settings.acts struct array)
% so the same act library can be reused across sessions of the same
% experiment.

    properties
        Tab
        Figure
        ParentApp

        % Layout
        OuterGrid
        ActsListBox
        InfoTextArea

        % Simple constructor
        SimpleNameField
        SimpleZoneListBox
        SimpleZoneOpDropDown      % AND / OR / EXCLUDE among selected zones
        SimpleBodyPartDropDown
        SimpleSpeedMinField
        SimpleSpeedMaxField

        % Complex constructor
        ComplexNameField
        ComplexComponentListBox
        ComplexOpDropDown         % intersect / union / exclude / sequence
        ComplexSeqDelayField

        % Library save/load
        LibraryPathField

        % Preset (for zones + body parts)
        PresetPathField
        LoadedPresetData

        % State
        State
    end

    methods
        function obj = DefineActsTabController(parentTab, parentApp)
            if nargin < 2; parentApp = []; end
            obj.Tab = parentTab;
            obj.ParentApp = parentApp;
            obj.Figure = ancestor(parentTab, 'figure');
            obj.State = sphynx.app.DefineActsTabController.emptyState();
            obj.buildUI();
            obj.loadDefaults();
        end

        function delete(~)
        end

        % --- Public API ---------------------------------------------------
        function loadDefaults(obj)
            % Seed the library with rest / walk / locomotion / freezing /
            % rears, mirroring the legacy BehaviorAnalyzer thresholds.
            obj.State.acts = sphynx.acts.actsLibraryDefaults();
            obj.refreshActsListBox();
        end

        function loadPreset(obj)
            % Read a preset .mat and pull its zone names + a sensible
            % bodyparts list into the simple-act constructor.
            path = obj.PresetPathField.Value;
            if isempty(path) || ~isfile(path)
                obj.applog('warn', 'Preset not found: %s', path); return;
            end
            try
                pd = sphynx.io.readPreset(path);
            catch ME
                obj.applog('error', 'readPreset failed: %s', ME.message); return;
            end
            obj.LoadedPresetData = pd;
            % Zones
            if isfield(pd, 'Zones') && ~isempty(pd.Zones)
                names = {pd.Zones.name};
                obj.SimpleZoneListBox.Items = names;
                obj.applog('info', 'Loaded %d zones from preset', numel(names));
            else
                obj.SimpleZoneListBox.Items = {};
                obj.applog('warn', 'Preset has no Zones');
            end
            % Body parts — derive from common DLC defaults; can be edited.
            obj.SimpleBodyPartDropDown.Items = ...
                {'bodycenter', 'tailbase', 'nose', 'headcenter', ...
                 'leftear', 'rightear', 'leftforelimb', 'righforelimb', ...
                 'leftbody', 'rightbody', 'lefthindlimb', 'righthindlimb'};
        end

        function addSimpleAct(obj)
            name = strtrim(obj.SimpleNameField.Value);
            if isempty(name)
                obj.applog('warn', 'Simple act needs a name');
                return;
            end
            act = sphynx.acts.buildSimpleAct( ...
                'Name',     name, ...
                'Zones',    obj.SimpleZoneListBox.Value, ...
                'ZoneOp',   obj.SimpleZoneOpDropDown.Value, ...
                'BodyPart', obj.SimpleBodyPartDropDown.Value, ...
                'SpeedMin', obj.SimpleSpeedMinField.Value, ...
                'SpeedMax', obj.SimpleSpeedMaxField.Value);
            obj.State.acts(end+1) = act;
            obj.refreshActsListBox();
            obj.applog('info', 'Added simple act: %s', name);
        end

        function addComplexAct(obj)
            name = strtrim(obj.ComplexNameField.Value);
            if isempty(name)
                obj.applog('warn', 'Complex act needs a name');
                return;
            end
            comps = obj.ComplexComponentListBox.Value;
            if ischar(comps); comps = {comps}; end
            if numel(comps) < 2
                obj.applog('warn', 'Complex act needs at least 2 component acts');
                return;
            end
            act = sphynx.acts.buildComplexAct( ...
                'Name',       name, ...
                'Components', comps, ...
                'Operation',  obj.ComplexOpDropDown.Value, ...
                'SeqDelaySec', obj.ComplexSeqDelayField.Value);
            obj.State.acts(end+1) = act;
            obj.refreshActsListBox();
            obj.applog('info', 'Added complex act: %s (%s)', name, act.operation);
        end

        function deleteSelectedAct(obj)
            sel = obj.ActsListBox.Value;
            if isempty(sel); return; end
            idx = find(strcmp({obj.State.acts.name}, sel), 1);
            if isempty(idx); return; end
            obj.State.acts(idx) = [];
            obj.refreshActsListBox();
            obj.applog('info', 'Deleted act: %s', sel);
        end

        function saveLibrary(obj)
            path = obj.LibraryPathField.Value;
            if isempty(path)
                obj.applog('warn', 'Library path is empty');
                return;
            end
            sphynx.io.saveActsSet(path, obj.State.acts, obj.expType());
            obj.applog('info', 'Saved acts library: %s', path);
        end

        function loadLibrary(obj)
            path = obj.LibraryPathField.Value;
            if isempty(path) || ~isfile(path)
                obj.applog('warn', 'Library file not found: %s', path);
                return;
            end
            obj.State.acts = sphynx.io.loadActsSet(path);
            obj.refreshActsListBox();
            obj.applog('info', 'Loaded acts library: %s (%d acts)', path, numel(obj.State.acts));
        end
    end

    methods (Static)
        function s = emptyState()
            s.acts = sphynx.acts.emptyActsArray();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            obj.OuterGrid = uigridlayout(obj.Tab, [1, 2]);
            obj.OuterGrid.ColumnWidth = {360, '1x'};
            obj.OuterGrid.RowHeight = {'1x'};
            obj.OuterGrid.Padding = [4 4 4 4];
            obj.OuterGrid.ColumnSpacing = 6;

            obj.buildLeftLibraryColumn();
            obj.buildRightConstructorColumn();
        end

        function buildLeftLibraryColumn(obj)
            left = uigridlayout(obj.OuterGrid, [5, 1]);
            left.Layout.Column = 1;
            left.RowHeight = {32, 28, '1x', 32, 100};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            % Row 1: preset path + browse + load
            pr = uigridlayout(left, [1, 4]);
            pr.Layout.Row = 1;
            pr.RowHeight = {28};
            pr.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            pr.Padding = [0 0 0 0];
            pr.ColumnSpacing = 4;
            uilabel(pr, 'Text', 'Preset:');
            obj.PresetPathField = uieditfield(pr, 'text', 'Value', '');
            uibutton(pr, 'Text', 'Browse', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickPresetPath());
            uibutton(pr, 'Text', 'Load preset', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.loadPreset());

            % Row 2: load defaults / delete selected
            tb = uigridlayout(left, [1, 2]);
            tb.Layout.Row = 2;
            tb.RowHeight = {28};
            tb.ColumnWidth = {'1x', 'fit'};
            tb.Padding = [0 0 0 0];
            tb.ColumnSpacing = 4;
            uibutton(tb, 'Text', 'Load defaults', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadDefaults());
            uibutton(tb, 'Text', 'Delete', ...
                'BackgroundColor', [0.92 0.55 0.55], ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelectedAct());

            % Acts library listbox
            obj.ActsListBox = uilistbox(left, 'Items', {}, ...
                'ValueChangedFcn', @(~,~) obj.refreshInfoForSelected());
            obj.ActsListBox.Layout.Row = 3;

            % Save/load row
            srow = uigridlayout(left, [1, 3]);
            srow.Layout.Row = 4;
            srow.RowHeight = {28};
            srow.ColumnWidth = {'fit', '1x', 'fit'};
            srow.Padding = [0 0 0 0];
            srow.ColumnSpacing = 4;
            bBrowse = uibutton(srow, 'Text', 'Browse', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.pickLibraryPath());
            bBrowse.Layout.Column = 1; %#ok<NASGU>
            obj.LibraryPathField = uieditfield(srow, 'text', 'Value', '');
            obj.LibraryPathField.Layout.Column = 2;
            bSave = uibutton(srow, 'Text', 'Save', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.saveLibrary());
            bSave.Layout.Column = 3; %#ok<NASGU>

            % Info / log
            obj.InfoTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
            obj.InfoTextArea.Layout.Row = 5;
        end

        function pickPresetPath(obj)
            startDir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                startDir = obj.ParentApp.State.projectRoot;
            end
            [f, p] = uigetfile({'*.mat', 'Preset .mat'}, 'Pick preset', startDir);
            if isequal(f, 0); return; end
            obj.PresetPathField.Value = fullfile(p, f);
        end

        function buildRightConstructorColumn(obj)
            right = uitabgroup(obj.OuterGrid);
            right.Layout.Column = 2;
            tabSimple = uitab(right, 'Title', 'Simple act');
            tabComplex = uitab(right, 'Title', 'Complex act');
            obj.buildSimpleConstructor(tabSimple);
            obj.buildComplexConstructor(tabComplex);
        end

        function buildSimpleConstructor(obj, tab)
            g = uigridlayout(tab, [7, 2]);
            g.RowHeight = repmat({30}, 1, 7);
            g.ColumnWidth = {120, '1x'};
            g.RowSpacing = 4;
            g.ColumnSpacing = 4;
            g.Padding = [6 6 6 6];

            uilabel(g, 'Text', 'Name:');
            obj.SimpleNameField = uieditfield(g, 'text', 'Value', '');

            uilabel(g, 'Text', 'Zones:');
            obj.SimpleZoneListBox = uilistbox(g, 'Items', {}, 'Multiselect', 'on');

            uilabel(g, 'Text', 'Zone op:');
            obj.SimpleZoneOpDropDown = uidropdown(g, ...
                'Items', {'AND', 'OR', 'EXCLUDE'}, 'Value', 'OR', ...
                'Tooltip', 'AND = all zones; OR = any zone; EXCLUDE = first zone but not the rest');

            uilabel(g, 'Text', 'Body part:');
            obj.SimpleBodyPartDropDown = uidropdown(g, ...
                'Items', {'bodycenter', 'tailbase', 'nose', 'headcenter'}, ...
                'Value', 'bodycenter');

            uilabel(g, 'Text', 'Speed min (cm/s):');
            obj.SimpleSpeedMinField = uieditfield(g, 'numeric', 'Value', 0);

            uilabel(g, 'Text', 'Speed max (cm/s):');
            obj.SimpleSpeedMaxField = uieditfield(g, 'numeric', 'Value', 1000);

            uilabel(g, 'Text', '');
            uibutton(g, 'Text', 'Add to library', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.addSimpleAct());
        end

        function buildComplexConstructor(obj, tab)
            g = uigridlayout(tab, [5, 2]);
            g.RowHeight = {30, '1x', 30, 30, 30};
            g.ColumnWidth = {120, '1x'};
            g.RowSpacing = 4;
            g.ColumnSpacing = 4;
            g.Padding = [6 6 6 6];

            uilabel(g, 'Text', 'Name:');
            obj.ComplexNameField = uieditfield(g, 'text', 'Value', '');

            uilabel(g, 'Text', 'Components:');
            obj.ComplexComponentListBox = uilistbox(g, 'Items', {}, 'Multiselect', 'on');

            uilabel(g, 'Text', 'Operation:');
            obj.ComplexOpDropDown = uidropdown(g, ...
                'Items', {'intersect', 'union', 'exclude', 'sequence'}, 'Value', 'intersect', ...
                'Tooltip', 'sequence = act A then act B within delay');

            uilabel(g, 'Text', 'Seq. delay (s):');
            obj.ComplexSeqDelayField = uieditfield(g, 'numeric', 'Value', 1.0, 'Limits', [0 60]);

            uilabel(g, 'Text', '');
            uibutton(g, 'Text', 'Add to library', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.addComplexAct());
        end

        function refreshActsListBox(obj)
            if isempty(obj.State.acts)
                obj.ActsListBox.Items = {};
                obj.ComplexComponentListBox.Items = {};
                return;
            end
            names = {obj.State.acts.name};
            obj.ActsListBox.Items = names;
            obj.ComplexComponentListBox.Items = names;
            obj.refreshZoneAndBodypartFromPreset();
        end

        function refreshZoneAndBodypartFromPreset(obj)
            % Pull zones/bodyparts from the parent app's CreatePreset state
            % (when available) so the user sees real names, not placeholders.
            if isempty(obj.ParentApp); return; end
            try
                if ~isempty(obj.ParentApp.State.zones)
                    obj.SimpleZoneListBox.Items = {obj.ParentApp.State.zones.name};
                end
            catch; end
        end

        function refreshInfoForSelected(obj)
            sel = obj.ActsListBox.Value;
            if isempty(sel); obj.InfoTextArea.Value = {''}; return; end
            idx = find(strcmp({obj.State.acts.name}, sel), 1);
            if isempty(idx); return; end
            obj.InfoTextArea.Value = sphynx.acts.actToDescription(obj.State.acts(idx));
        end

        function pickLibraryPath(obj)
            startDir = '';
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.State.projectRoot)
                startDir = obj.ParentApp.State.projectRoot;
            end
            [f, p] = uiputfile({'*.mat', 'Acts library .mat'}, ...
                'Save acts library as', fullfile(startDir, 'acts_library.mat'));
            if isequal(f, 0); return; end
            obj.LibraryPathField.Value = fullfile(p, f);
        end

        function s = expType(obj)
            s = '';
            if isempty(obj.ParentApp); return; end
            try
                if ~isempty(obj.ParentApp.ExpTypeDropDown)
                    s = obj.ParentApp.ExpTypeDropDown.Value;
                end
            catch; end
        end

        function applog(obj, level, fmt, varargin)
            sphynx.util.log(level, ['[Acts] ' fmt], varargin{:});
            if isempty(obj.InfoTextArea) || ~isvalid(obj.InfoTextArea); return; end
            line = sprintf(['[' upper(level) '] ' fmt], varargin{:});
            current = obj.InfoTextArea.Value;
            if isempty(current); current = {}; end
            if ~iscell(current); current = cellstr(current); end
            obj.InfoTextArea.Value = [{line}; current(:)];
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

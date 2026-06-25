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
        SimpleMinDurationField
        SimpleMaxGapField

        % Complex constructor
        ComplexNameField
        ComplexComponentListBox
        ComplexOpDropDown         % intersect / union / exclude / sequence
        ComplexSeqDelayField

        % Library save/load
        LibraryPathField

        % Loader column resources: 5 buttons + 5 editable path fields
        % (mirrors the Preprocess tab pattern — fields can be edited
        % manually; Root auto-pulls from ParentApp.State.projectRoot).
        RootPathField
        PresetPathField
        VideoPathField
        DLCPathField
        PreprocessPathField
        RootButton
        PresetButton
        VideoButton
        DLCButton
        PreprocessButton
        LoadedPresetData
        LoadedPreprocessSettings

        % Simple act preview + make-video
        PreviewAxes
        MakeVideoDurationField
        MakeVideoButton

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
            obj.inheritRootFromParentApp();
            obj.loadDefaults();
        end

        function delete(~)
        end

        % --- Public API ---------------------------------------------------
        function loadDefaults(obj)
            % Seed the library with rest / walk / locomotion / freezing /
            % rears, mirroring the legacy BehaviorAnalyzer thresholds.
            obj.appendDefaultsWithChoice( ...
                sphynx.acts.actsLibraryDefaults(), 'default');
        end

        function loadBarnesDefaults(obj)
            % Seed the library with the Barnes-paradigm act set
            % (at_target / at_platform / at_any_hole / at_mistake /
            % per-hole at_objectN / arena-frame acts). Hardcoded to
            % 19 mistake objects matching the Demo/BARNES_v2 layout.
            obj.appendDefaultsWithChoice( ...
                sphynx.acts.actsLibraryBarnesDefaults(), 'Barnes default');
        end

        function appendDefaultsWithChoice(obj, defaults, label)
            % Shared loader for library-default buttons. If the library
            % already has user-added acts, asks Append / Replace / Cancel
            % so silent overwrite never happens.
            if isempty(obj.State.acts)
                obj.State.acts = defaults;
                obj.refreshActsListBox();
                obj.applog('info', 'Loaded %d %s acts', numel(defaults), label);
                return;
            end
            choice = uiconfirm(obj.ParentApp.Figure, ...
                sprintf(['Library already has %d act(s). Add %s acts on top, ', ...
                         'or replace the whole library?'], ...
                        numel(obj.State.acts), label), ...
                sprintf('Load %s acts', label), ...
                'Options', {'Append', 'Replace', 'Cancel'}, ...
                'DefaultOption', 'Append', 'CancelOption', 'Cancel');
            switch choice
                case 'Append'
                    existing = {obj.State.acts.name};
                    keep = ~ismember({defaults.name}, existing);
                    skipped = sum(~keep);
                    obj.State.acts = [obj.State.acts, defaults(keep)];
                    obj.applog('info', ['Appended %d %s acts ', ...
                        '(%d skipped -- name already exists)'], ...
                        sum(keep), label, skipped);
                case 'Replace'
                    obj.State.acts = defaults;
                    obj.applog('info', 'Replaced library with %d %s acts', ...
                        numel(defaults), label);
                case 'Cancel'
                    return;
            end
            obj.refreshActsListBox();
        end

        function loadRoot(obj)
            % Pick a project root folder. Used as default start directory
            % for the other Load buttons. Auto-filled from
            % ParentApp.State.projectRoot when this tab is built.
            startDir = obj.resourceStartDir();
            sel = uigetdir(startDir, 'Select project root');
            obj.restoreFocus();
            if isequal(sel, 0); return; end
            obj.RootPathField.Value = sel;
            obj.RootButton.Tooltip = sprintf('Root: %s', sel);
            obj.applog('info', 'Project root: %s', sel);
        end

        function loadPreset(obj)
            % Open file dialog → read a preset .mat → pull zone names +
            % a sensible bodyparts list into the simple-act constructor.
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mat', 'Preset .mat'}, ...
                'Load preset', startDir);
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            obj.applyPresetPath(path);
        end

        function applyPresetPath(obj, path)
            % Read a preset and populate UI from it. Used by both the
            % button (after uigetfile) and manual edits to PresetPathField.
            if ~isfile(path)
                obj.applog('warn', 'Preset path does not exist: %s', path);
                return;
            end
            try
                pd = sphynx.io.readPreset(path);
            catch ME
                obj.applog('error', 'readPreset failed: %s', ME.message); return;
            end
            obj.PresetPathField.Value = path;
            obj.PresetButton.Tooltip = sprintf('Loaded: %s', path);
            obj.LoadedPresetData = pd;
            % Zones — prepend '<any zone>' sentinel meaning "no zone gate".
            % Composites (walls_and_corners*) are dropped by the helper.
            if isfield(pd, 'Zones') && ~isempty(pd.Zones)
                keep = sphynx.util.filterZoneListForActs(pd.Zones);
                nFiltered = numel(pd.Zones) - numel(keep);
                obj.SimpleZoneListBox.Items = [{'<any zone>'}, keep];
                obj.SimpleZoneListBox.Value = {'<any zone>'};
                if nFiltered > 0
                    obj.applog('info', 'Loaded %d zones from preset (filtered %d composite)', ...
                        numel(keep), nFiltered);
                else
                    obj.applog('info', 'Loaded %d zones from preset', numel(keep));
                end
            else
                obj.SimpleZoneListBox.Items = {'<any zone>'};
                obj.SimpleZoneListBox.Value = {'<any zone>'};
                obj.applog('warn', 'Preset has no Zones');
            end
            % Body parts — derive from common DLC defaults; can be edited.
            obj.SimpleBodyPartDropDown.Items = ...
                {'bodycenter', 'tailbase', 'nose', 'headcenter', ...
                 'leftear', 'rightear', 'leftforelimb', 'righforelimb', ...
                 'leftbody', 'rightbody', 'lefthindlimb', 'righthindlimb'};
            obj.refreshZonePreview();
        end

        function loadVideo(obj)
            % Pick a video file (used by Make-video preview).
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mp4;*.avi;*.mov;*.mkv', 'Video files'; ...
                                '*.*', 'All files'}, 'Load video', startDir);
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            obj.VideoPathField.Value = path;
            obj.VideoButton.Tooltip = sprintf('Loaded: %s', path);
            obj.applog('info', 'Video loaded: %s', f);
        end

        function loadDLC(obj)
            % Pick a DLC csv with body-part tracks (used by Make-video).
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.csv', 'DLC csv (*.csv)'; ...
                                '*.*', 'All files'}, 'Load DLC csv', startDir);
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            obj.DLCPathField.Value = path;
            obj.DLCButton.Tooltip = sprintf('Loaded: %s', path);
            obj.applog('info', 'DLC csv loaded: %s', f);
        end

        function loadPreprocessSettings(obj)
            % Load the per-experiment preprocess settings .mat saved by
            % the Preprocess Tracking tab. Used by Make-video to clean
            % traces before evaluating the act.
            startDir = obj.resourceStartDir();
            [f, p] = uigetfile({'*.mat', 'Preprocess settings .mat'}, ...
                'Load preprocess settings', startDir);
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            obj.applyPreprocessPath(path);
        end

        function applyPreprocessPath(obj, path)
            if ~isfile(path)
                obj.applog('warn', 'Preprocess path does not exist: %s', path);
                return;
            end
            try
                s = load(path);
            catch ME
                obj.applog('error', 'Load failed: %s', ME.message); return;
            end
            obj.PreprocessPathField.Value = path;
            obj.PreprocessButton.Tooltip = sprintf('Loaded: %s', path);
            obj.LoadedPreprocessSettings = s;
            [~, fname] = fileparts(path);
            obj.applog('info', 'Preprocess settings loaded: %s', fname);
        end

        function addSimpleAct(obj)
            name = strtrim(obj.SimpleNameField.Value);
            if isempty(name)
                obj.applog('warn', 'Simple act needs a name');
                return;
            end
            zones = obj.SimpleZoneListBox.Value;
            if ischar(zones); zones = {zones}; end
            % '<any zone>' sentinel = no zone gate
            zones = zones(~strcmp(zones, '<any zone>'));
            act = sphynx.acts.buildSimpleAct( ...
                'Name',           name, ...
                'Zones',          zones, ...
                'ZoneOp',         'OR', ...
                'BodyPart',       obj.SimpleBodyPartDropDown.Value, ...
                'SpeedMin',       obj.SimpleSpeedMinField.Value, ...
                'SpeedMax',       obj.SimpleSpeedMaxField.Value, ...
                'MinDurationSec', obj.SimpleMinDurationField.Value, ...
                'MaxGapSec',      obj.SimpleMaxGapField.Value);
            obj.State.acts(end+1) = act;
            obj.refreshActsListBox();
            obj.applog('info', 'Added simple act: %s (zones=%d)', name, numel(zones));
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
            if ischar(sel); sel = {sel}; end
            if numel(sel) > 1
                choice = uiconfirm(obj.ParentApp.Figure, ...
                    sprintf('Delete %d selected acts?', numel(sel)), ...
                    'Delete acts', ...
                    'Options', {'Delete', 'Cancel'}, ...
                    'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', ...
                    'Icon', 'warning');
                if ~strcmp(choice, 'Delete'); return; end
            end
            keep = ~ismember({obj.State.acts.name}, sel);
            removed = sum(~keep);
            obj.State.acts = obj.State.acts(keep);
            obj.refreshActsListBox();
            obj.applog('info', 'Deleted %d act(s): %s', removed, strjoin(sel, ', '));
        end

        function clearAllActs(obj)
            if isempty(obj.State.acts)
                obj.applog('info', 'Library is already empty');
                return;
            end
            choice = uiconfirm(obj.ParentApp.Figure, ...
                sprintf('Wipe the entire library (%d acts)? This cannot be undone.', ...
                    numel(obj.State.acts)), ...
                'Clear all acts', ...
                'Options', {'Wipe', 'Cancel'}, ...
                'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', ...
                'Icon', 'warning');
            if ~strcmp(choice, 'Wipe'); return; end
            n = numel(obj.State.acts);
            obj.State.acts = sphynx.acts.emptyActsArray();
            obj.refreshActsListBox();
            obj.applog('info', 'Cleared library (%d acts removed)', n);
        end

        function saveLibrary(obj)
            if isempty(obj.State.acts)
                obj.applog('warn', 'Library is empty — nothing to save');
                return;
            end
            startDir = obj.libraryStartDir();
            startName = obj.LibraryPathField.Value;
            if isempty(startName); startName = 'acts_library.mat'; end
            [f, p] = uiputfile({'*.mat', 'Acts library (*.mat)'}, ...
                'Save acts library', fullfile(startDir, startName));
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            try
                sphynx.io.saveActsSet(path, obj.State.acts, obj.expType());
            catch ME
                obj.applog('error', 'saveActsSet failed: %s', ME.message);
                return;
            end
            obj.LibraryPathField.Value = path;
            obj.applog('info', 'Saved acts library (%d acts): %s', ...
                numel(obj.State.acts), path);
        end

        function loadLibrary(obj)
            startDir = obj.libraryStartDir();
            [f, p] = uigetfile({'*.mat', 'Acts library (*.mat)'}, ...
                'Load acts library', startDir);
            obj.restoreFocus();
            if isequal(f, 0); return; end
            path = fullfile(p, f);
            try
                incoming = sphynx.io.loadActsSet(path);
            catch ME
                obj.applog('error', 'loadActsSet failed: %s', ME.message);
                return;
            end
            obj.LibraryPathField.Value = path;
            obj.mergeIntoLibrary(incoming, sprintf('"%s"', f));
        end

        function dir = libraryStartDir(obj)
            % Prefer existing library path → Root field → project root → cwd.
            cur = obj.LibraryPathField.Value;
            if ~isempty(cur) && isfolder(fileparts(cur))
                dir = fileparts(cur); return;
            end
            dir = obj.resourceStartDir();
        end

        function dir = resourceStartDir(obj)
            % Prefer Root field → ParentApp.State.projectRoot → cwd. Used
            % as the starting folder for all Load buttons except Library.
            if ~isempty(obj.RootPathField) ...
                    && ~isempty(obj.RootPathField.Value) ...
                    && isfolder(obj.RootPathField.Value)
                dir = obj.RootPathField.Value; return;
            end
            if ~isempty(obj.ParentApp) ...
                    && isprop(obj.ParentApp, 'State') ...
                    && isfield(obj.ParentApp.State, 'projectRoot') ...
                    && ~isempty(obj.ParentApp.State.projectRoot) ...
                    && isfolder(obj.ParentApp.State.projectRoot)
                dir = obj.ParentApp.State.projectRoot; return;
            end
            dir = pwd;
        end

        function inheritRootFromParentApp(obj)
            % Pull project root from the parent app (set during the
            % CreatePreset / Preprocess tabs). Manual edits in this tab
            % override the inherited value.
            if isempty(obj.ParentApp); return; end
            try
                if isprop(obj.ParentApp, 'State') ...
                        && isfield(obj.ParentApp.State, 'projectRoot') ...
                        && ~isempty(obj.ParentApp.State.projectRoot) ...
                        && isfolder(obj.ParentApp.State.projectRoot) ...
                        && isempty(obj.RootPathField.Value)
                    obj.RootPathField.Value = obj.ParentApp.State.projectRoot;
                    obj.RootButton.Tooltip = sprintf('Root: %s', ...
                        obj.ParentApp.State.projectRoot);
                end
            catch
                % parent app state may not be ready yet — silent
            end
        end

        function onRootPathEdited(obj, val)
            if ~isempty(val) && ~isfolder(val)
                obj.applog('warn', 'Root folder does not exist: %s', val);
            end
            if ~isempty(val)
                obj.RootButton.Tooltip = sprintf('Root: %s', val);
            end
        end

        function onPresetPathEdited(obj, val)
            % Manual edit of preset path → re-load if the file resolves.
            if isempty(val); return; end
            obj.applyPresetPath(val);
        end

        function onPreprocessPathEdited(obj, val)
            if isempty(val); return; end
            obj.applyPreprocessPath(val);
        end

        function mergeIntoLibrary(obj, incoming, sourceLabel)
            % Merge a set of acts into the current library. Strategies for
            % name conflicts: Rename (suffix _2/_3/...), Skip, Replace.
            % Empty current library or no conflicts → silent append.
            if isempty(incoming)
                obj.applog('warn', 'Nothing to merge from %s', sourceLabel);
                return;
            end
            if isempty(obj.State.acts)
                obj.State.acts = incoming;
                obj.refreshActsListBox();
                obj.applog('info', 'Loaded %d acts from %s', ...
                    numel(incoming), sourceLabel);
                return;
            end
            existing = {obj.State.acts.name};
            incomingNames = {incoming.name};
            conflicts = ismember(incomingNames, existing);
            nConflict = sum(conflicts);

            if nConflict == 0
                obj.State.acts = [obj.State.acts, incoming];
                obj.refreshActsListBox();
                obj.applog('info', 'Appended %d acts from %s (no conflicts)', ...
                    numel(incoming), sourceLabel);
                return;
            end

            choice = uiconfirm(obj.ParentApp.Figure, ...
                sprintf(['Loading %s would create %d name conflict(s) ', ...
                         'with existing acts (%d total incoming).\n\n', ...
                         'Rename: append _2/_3/... suffix to incoming duplicates.\n', ...
                         'Skip: drop incoming duplicates, keep existing.\n', ...
                         'Replace: incoming duplicates overwrite existing.'], ...
                    sourceLabel, nConflict, numel(incoming)), ...
                'Resolve conflicts', ...
                'Options', {'Rename', 'Skip', 'Replace', 'Cancel'}, ...
                'DefaultOption', 'Rename', 'CancelOption', 'Cancel');
            switch choice
                case 'Rename'
                    renamed = incoming;
                    pool = existing;
                    nRenamed = 0;
                    for k = 1:numel(renamed)
                        if ismember(renamed(k).name, pool)
                            renamed(k).name = uniqueName(renamed(k).name, pool);
                            nRenamed = nRenamed + 1;
                        end
                        pool{end+1} = renamed(k).name; %#ok<AGROW>
                    end
                    obj.State.acts = [obj.State.acts, renamed];
                    obj.applog('info', ...
                        'Merged %d acts from %s (%d renamed)', ...
                        numel(renamed), sourceLabel, nRenamed);
                case 'Skip'
                    kept = incoming(~conflicts);
                    obj.State.acts = [obj.State.acts, kept];
                    obj.applog('info', ...
                        'Merged %d acts from %s (%d duplicates skipped)', ...
                        numel(kept), sourceLabel, nConflict);
                case 'Replace'
                    keepExisting = ~ismember(existing, incomingNames);
                    obj.State.acts = [obj.State.acts(keepExisting), incoming];
                    obj.applog('info', ...
                        'Merged %d acts from %s (%d existing replaced)', ...
                        numel(incoming), sourceLabel, nConflict);
                case 'Cancel'
                    obj.applog('info', 'Load cancelled (conflicts unresolved)');
                    return;
            end
            obj.refreshActsListBox();
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
            left = uigridlayout(obj.OuterGrid, [6, 1]);
            left.Layout.Column = 1;
            left.RowHeight = {28, 26, 28, '1x', 32, 80};
            left.RowSpacing = 4;
            left.Padding = [0 0 0 0];

            % Row 1: 5 load buttons (Root + Preset + Video + DLC + Preproc).
            loadRow = uigridlayout(left, [1, 5]);
            loadRow.Layout.Row = 1;
            loadRow.RowHeight = {26};
            loadRow.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            loadRow.ColumnSpacing = 4;
            loadRow.Padding = [0 0 0 0];
            obj.RootButton = uibutton(loadRow, 'Text', 'Root', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Pick project root folder (auto-fills from previous tabs)', ...
                'ButtonPushedFcn', @(~,~) obj.loadRoot());
            obj.PresetButton = uibutton(loadRow, 'Text', 'Preset', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Pick preset .mat (zones + frame)', ...
                'ButtonPushedFcn', @(~,~) obj.loadPreset());
            obj.VideoButton = uibutton(loadRow, 'Text', 'Video', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Pick session video for make-video preview', ...
                'ButtonPushedFcn', @(~,~) obj.loadVideo());
            obj.DLCButton = uibutton(loadRow, 'Text', 'DLC', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Pick DLC csv with body-part tracks', ...
                'ButtonPushedFcn', @(~,~) obj.loadDLC());
            obj.PreprocessButton = uibutton(loadRow, 'Text', 'Preproc', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Pick preprocess settings .mat (optional)', ...
                'ButtonPushedFcn', @(~,~) obj.loadPreprocessSettings());

            % Row 2: 5 editable path fields aligned under the buttons.
            % Manual edits trigger a re-load if the new path resolves.
            pathRow = uigridlayout(left, [1, 5]);
            pathRow.Layout.Row = 2;
            pathRow.RowHeight = {24};
            pathRow.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            pathRow.ColumnSpacing = 4;
            pathRow.Padding = [0 0 0 0];
            obj.RootPathField = uieditfield(pathRow, 'text', 'Value', '', ...
                'Tooltip', 'Project root folder', ...
                'ValueChangedFcn', @(s,~) obj.onRootPathEdited(s.Value));
            obj.PresetPathField = uieditfield(pathRow, 'text', 'Value', '', ...
                'Tooltip', 'Preset .mat', ...
                'ValueChangedFcn', @(s,~) obj.onPresetPathEdited(s.Value));
            obj.VideoPathField = uieditfield(pathRow, 'text', 'Value', '', ...
                'Tooltip', 'Session video');
            obj.DLCPathField = uieditfield(pathRow, 'text', 'Value', '', ...
                'Tooltip', 'DLC csv');
            obj.PreprocessPathField = uieditfield(pathRow, 'text', 'Value', '', ...
                'Tooltip', 'Preprocess settings .mat', ...
                'ValueChangedFcn', @(s,~) obj.onPreprocessPathEdited(s.Value));

            % Row 3: load defaults / load Barnes / delete selected / clear all
            tb = uigridlayout(left, [1, 4]);
            tb.Layout.Row = 3;
            tb.RowHeight = {28};
            tb.ColumnWidth = {'1x', '1x', 'fit', 'fit'};
            tb.Padding = [0 0 0 0];
            tb.ColumnSpacing = 4;
            uibutton(tb, 'Text', 'Load defaults', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Append speed/posture defaults (rest/walk/locomotion/freezing/rear)', ...
                'ButtonPushedFcn', @(~,~) obj.loadDefaults());
            uibutton(tb, 'Text', 'Load Barnes', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Append Barnes-paradigm acts (at_target/at_platform/at_object1..19/at_mistake/arena-frame)', ...
                'ButtonPushedFcn', @(~,~) obj.loadBarnesDefaults());
            uibutton(tb, 'Text', 'Delete', ...
                'BackgroundColor', [0.92 0.55 0.55], ...
                'Tooltip', 'Delete selected act(s) -- multi-select supported', ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelectedAct());
            uibutton(tb, 'Text', 'Clear all', ...
                'BackgroundColor', [0.85 0.30 0.30], ...
                'FontColor', [1 1 1], ...
                'Tooltip', 'Wipe the entire library (asks for confirmation)', ...
                'ButtonPushedFcn', @(~,~) obj.clearAllActs());

            % Row 4: Acts library listbox — multi-select for batch delete
            obj.ActsListBox = uilistbox(left, 'Items', {}, ...
                'Multiselect', 'on', ...
                'ValueChangedFcn', @(~,~) obj.refreshInfoForSelected());
            obj.ActsListBox.Layout.Row = 4;

            % Row 5: Save/Load library row.
            srow = uigridlayout(left, [1, 3]);
            srow.Layout.Row = 5;
            srow.RowHeight = {28};
            srow.ColumnWidth = {'1x', 'fit', 'fit'};
            srow.Padding = [0 0 0 0];
            srow.ColumnSpacing = 4;
            obj.LibraryPathField = uieditfield(srow, 'text', 'Value', '', ...
                'Editable', 'off', ...
                'Tooltip', 'Most recently used library file');
            obj.LibraryPathField.Layout.Column = 1;
            bLoad = uibutton(srow, 'Text', 'Load', ...
                'BackgroundColor', semanticColor('action'), ...
                'Tooltip', 'Append library from file (resolves name conflicts)', ...
                'ButtonPushedFcn', @(~,~) obj.loadLibrary());
            bLoad.Layout.Column = 2; %#ok<NASGU>
            bSave = uibutton(srow, 'Text', 'Save', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.saveLibrary());
            bSave.Layout.Column = 3; %#ok<NASGU>

            % Row 6: Info / log
            obj.InfoTextArea = uitextarea(left, 'Editable', 'off', 'Value', {''});
            obj.InfoTextArea.Layout.Row = 6;
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
            % Make Simple acts the default visible tab — otherwise the
            % tab-group highlight is hard to spot against the panel bg.
            try
                right.SelectedTab = tabSimple;
            catch
            end
        end

        function buildSimpleConstructor(obj, tab)
            % Round-7d layout: 2x2 outer grid.
            %   top-left  : compact form (name / bodypart / speed / add)
            %   top-right : Zones listbox (large)
            %   bottom    : zone preview axes + Make-video controls
            outer = uigridlayout(tab, [2, 2]);
            % Top row fixed shorter so Zones listbox is ~half height of
            % the bottom preview area.
            outer.RowHeight = {230, '1x'};
            outer.ColumnWidth = {360, '1x'};
            outer.RowSpacing = 6;
            outer.ColumnSpacing = 6;
            outer.Padding = [6 6 6 6];

            % --- TOP-LEFT: compact form ----------------------------------
            form = uigridlayout(outer, [7, 2]);
            form.Layout.Row = 1; form.Layout.Column = 1;
            form.RowHeight = repmat({28}, 1, 7);
            form.ColumnWidth = {130, '1x'};
            form.RowSpacing = 4;
            form.ColumnSpacing = 6;
            form.Padding = [0 0 0 0];

            uilabel(form, 'Text', 'Name:');
            obj.SimpleNameField = uieditfield(form, 'text', 'Value', '');

            uilabel(form, 'Text', 'Body part:');
            obj.SimpleBodyPartDropDown = uidropdown(form, ...
                'Items', {'bodycenter', 'tailbase', 'nose', 'headcenter'}, ...
                'Value', 'bodycenter');

            uilabel(form, 'Text', 'Speed min, cm/s:');
            obj.SimpleSpeedMinField = uieditfield(form, 'numeric', 'Value', 0, ...
                'Tooltip', '0 = no lower limit');

            uilabel(form, 'Text', 'Speed max, cm/s:');
            obj.SimpleSpeedMaxField = uieditfield(form, 'numeric', 'Value', Inf, ...
                'Tooltip', 'Inf = no upper limit');

            uilabel(form, 'Text', 'Min duration, s:');
            obj.SimpleMinDurationField = uieditfield(form, 'numeric', ...
                'Value', 0.25, 'Limits', [0 600], ...
                'Tooltip', ['Drop activations shorter than this. ' ...
                            '0 = keep every active frame.']);

            uilabel(form, 'Text', 'Max gap, s:');
            obj.SimpleMaxGapField = uieditfield(form, 'numeric', ...
                'Value', 0.25, 'Limits', [0 600], ...
                'Tooltip', ['Holes inside the act shorter than this ' ...
                            'still count as part of the act (filled ' ...
                            'before the duration check). 0 = never fill.']);

            uilabel(form, 'Text', '');
            uibutton(form, 'Text', 'Add to library', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.addSimpleAct());

            % Hidden — back-compat, always 'OR'. Parked off-grid in
            % obj.Tab (Visible='off') so .Value still resolves but it
            % no longer eats a row from the form's 7-row layout.
            obj.SimpleZoneOpDropDown = uidropdown(obj.Tab, ...
                'Items', {'OR'}, 'Value', 'OR', 'Visible', 'off');

            % --- TOP-RIGHT: Zones listbox --------------------------------
            zoneGrid = uigridlayout(outer, [2, 1]);
            zoneGrid.Layout.Row = 1; zoneGrid.Layout.Column = 2;
            zoneGrid.RowHeight = {22, '1x'};
            zoneGrid.RowSpacing = 2;
            zoneGrid.Padding = [0 0 0 0];
            uilabel(zoneGrid, 'Text', 'Zones (multi-select = OR):', ...
                'FontWeight', 'bold');
            obj.SimpleZoneListBox = uilistbox(zoneGrid, ...
                'Items', {'<any zone>'}, 'Value', '<any zone>', ...
                'Multiselect', 'on', ...
                'ValueChangedFcn', @(s, ~) obj.onZoneSelectionChanged(s));

            % --- BOTTOM (spans both columns): preview + make-video -------
            bot = uigridlayout(outer, [2, 1]);
            bot.Layout.Row = 2; bot.Layout.Column = [1 2];
            bot.RowHeight = {'1x', 36};
            bot.RowSpacing = 4;
            bot.Padding = [0 0 0 0];

            obj.PreviewAxes = uiaxes(bot);
            obj.PreviewAxes.Layout.Row = 1;
            obj.PreviewAxes.XTick = []; obj.PreviewAxes.YTick = [];
            obj.PreviewAxes.Box = 'on';
            obj.PreviewAxes.YDir = 'reverse';
            title(obj.PreviewAxes, 'Preview — load preset to see frame + selected zone');

            mv = uigridlayout(bot, [1, 5]);
            mv.Layout.Row = 2;
            mv.RowHeight = {30};
            mv.ColumnWidth = {70, 70, '1x', 110, 200};
            mv.ColumnSpacing = 6;
            mv.Padding = [0 0 0 0];
            uilabel(mv, 'Text', 'Duration:');
            obj.MakeVideoDurationField = uieditfield(mv, 'numeric', ...
                'Value', 5, 'Limits', [0.1 600], ...
                'Tooltip', 'Seconds of stitched active-act footage to render');
            uilabel(mv, 'Text', 's', ...
                'HorizontalAlignment', 'left');
            obj.MakeVideoButton = uibutton(mv, 'Text', 'Make video', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'Tooltip', 'Render selected library act in memory and open in implay', ...
                'ButtonPushedFcn', @(~,~) obj.makeActVideo());
            uibutton(mv, 'Text', 'Render & save all videos', ...
                'BackgroundColor', [0.55 0.85 1.00], 'FontWeight', 'bold', ...
                'Tooltip', 'For every act in the library, save a per-act mp4 to <root>/Acts_video/', ...
                'ButtonPushedFcn', @(~,~) obj.renderAndSaveAllActs());
        end

        function onZoneSelectionChanged(obj, src)
            % Auto-suggest the act name from the first selected zone
            % (only if the name field is empty — don't overwrite manual
            % input). Then refresh the preview.
            v = src.Value;
            if iscell(v) && ~isempty(v); v = v{1}; end
            if ~isempty(v) && isempty(strtrim(obj.SimpleNameField.Value)) ...
                    && ~strcmp(v, '<any zone>')
                obj.SimpleNameField.Value = v;
            end
            obj.refreshZonePreview();
        end

        function refreshZonePreview(obj)
            % Show the preset's GoodVideoFrame (Options.GoodVideoFrame in
            % the legacy preset shape) with the zone(s) selected in the
            % Zones listbox overlaid as filled translucent regions plus
            % a boundary line, mimicking the BehaviorAnalyzer style.
            ax = obj.PreviewAxes;
            if isempty(ax) || ~isvalid(ax); return; end
            cla(ax); ax.XTick = []; ax.YTick = [];
            pd = obj.LoadedPresetData;
            if isempty(pd)
                title(ax, 'Preview — load preset first');
                return;
            end
            frame = obj.extractPresetFrame(pd);
            sel = obj.SimpleZoneListBox.Value;
            if ischar(sel); sel = {sel}; end
            sel = sel(~strcmp(sel, '<any zone>'));
            zones = [];
            if isfield(pd, 'Zones'); zones = pd.Zones; end
            if isempty(frame)
                title(ax, 'Preview — preset has no GoodVideoFrame');
                return;
            end
            % Compose: blend zone masks with the frame (BA-style 50/50)
            % so the zone tint is visible even on bright background.
            if ~isempty(sel) && ~isempty(zones)
                mask = false(size(frame, 1), size(frame, 2));
                for k = 1:numel(sel)
                    idx = find(strcmp({zones.name}, sel{k}), 1);
                    if isempty(idx); continue; end
                    if isfield(zones(idx), 'maskfilled') ...
                            && ~isempty(zones(idx).maskfilled)
                        mask = mask | logical(zones(idx).maskfilled);
                    end
                end
                if any(mask(:))
                    frame = blendZoneMask(frame, mask);
                end
            end
            imshow(frame, 'Parent', ax); hold(ax, 'on');
            % Boundary lines for clarity
            if ~isempty(sel) && ~isempty(zones)
                colors = lines(max(1, numel(sel)));
                for k = 1:numel(sel)
                    idx = find(strcmp({zones.name}, sel{k}), 1);
                    if isempty(idx); continue; end
                    if isfield(zones(idx), 'maskfilled') ...
                            && ~isempty(zones(idx).maskfilled)
                        B = bwboundaries(logical(zones(idx).maskfilled));
                        for b = 1:numel(B)
                            plot(ax, B{b}(:,2), B{b}(:,1), ...
                                'Color', colors(k,:), 'LineWidth', 2);
                        end
                    end
                end
                title(ax, sprintf('Preview — %s', strjoin(sel, ', ')));
            else
                title(ax, 'Preview — select zone(s) to overlay');
            end
            hold(ax, 'off');
        end

        function frame = extractPresetFrame(~, pd)
            % Find the reference frame in a legacy preset struct.
            % Color GoodVideoFrame > GoodVideoFrameGray > top-level
            % fallbacks (defensive — older presets may differ).
            frame = [];
            if isfield(pd, 'Options') && ~isempty(pd.Options)
                opts = pd.Options;
                for fld = {'GoodVideoFrame', 'GoodVideoFrameGray'}
                    if isfield(opts, fld{1}) && ~isempty(opts.(fld{1}))
                        frame = opts.(fld{1}); return;
                    end
                end
            end
            for fld = {'GoodVideoFrame', 'GoodVideoFrameGray', ...
                       'Frame', 'frame', 'PresetFrame', 'image'}
                if isfield(pd, fld{1}) && ~isempty(pd.(fld{1}))
                    frame = pd.(fld{1}); return;
                end
            end
        end

        function makeActVideo(obj)
            % Render a short clip showing where the selected library act
            % is active and open it in an in-memory player window
            % (no file written). Pipeline:
            %   1. Run analyzeSession on the loaded paths with a temp
            %      library that contains only the selected act.
            %   2. Find the first window of `duration` seconds with
            %      activity for that act.
            %   3. Render BA-style: zone tinting (if act has a zone),
            %      a dot per body part, the act's body part highlighted
            %      in red.
            %   4. Pass the resulting 4D uint8 stack to implay.
            sel = obj.ActsListBox.Value;
            if isempty(sel)
                obj.applog('warn', 'Select a library act first'); return;
            end
            if iscell(sel); sel = sel{1}; end
            presetPath = obj.PresetPathField.Value;
            videoPath  = obj.VideoPathField.Value;
            if isempty(presetPath) || ~isfile(presetPath)
                obj.applog('warn', 'Load preset first'); return;
            end
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Load video first'); return;
            end
            dlcPath = obj.DLCPathField.Value;
            if isempty(dlcPath) || ~isfile(dlcPath)
                dlcPath = obj.findDLCPath(presetPath, videoPath);
            end
            if isempty(dlcPath) || ~isfile(dlcPath)
                obj.applog('error', ...
                    'No DLC csv — load one explicitly via "DLC"');
                return;
            end
            actIdx = find(strcmp({obj.State.acts.name}, sel), 1);
            if isempty(actIdx); obj.applog('warn', 'Act not found'); return; end
            durSec = obj.MakeVideoDurationField.Value;

            dlg = uiprogressdlg(obj.ParentApp.Figure, ...
                'Title', sprintf('Make-video: %s', sel), ...
                'Message', 'Preprocessing tracks...', ...
                'Indeterminate', 'on', 'Cancelable', 'off');
            cleaner = onCleanup(@() closeIfValid(dlg)); %#ok<NASGU>
            try
                % --- 1. analyzeSession with single-act temp library ----
                tmpLib = [tempname '.mat'];
                sphynx.io.saveActsSet(tmpLib, obj.State.acts(actIdx), '');
                cleanLib = onCleanup(@() deleteIfExists(tmpLib)); %#ok<NASGU>

                cfg = sphynx.pipeline.defaultConfig();
                cfg.paths.dlc = dlcPath;
                cfg.paths.preset = presetPath;
                cfg.paths.outDir = tempdir;
                cfg.acts.libraryPath = tmpLib;
                cfg.viz.headless = true;
                cfg.io.saveWorkspace = false;

                result = sphynx.pipeline.analyzeSession(cfg);

                % --- 2. Locate the act + first active window ----------
                rIdx = find(strcmp({result.Acts.ActName}, sel), 1);
                if isempty(rIdx)
                    error('Act "%s" missing from result', sel);
                end
                bool = logical(result.Acts(rIdx).ActArrayRefine);
                fps  = result.Options.FrameRate;
                % durSec*fps is rarely integer (29.97 fps, fractional
                % durations); cast explicitly to a positive integer.
                nWin = max(1, round(double(durSec) * double(fps)));

                % --- 2b. Stitch ONLY active frames (bool=1). The act is
                %        a 0/1 timeseries over DLC frames; the player
                %        should show the moments where the act fires,
                %        back-to-back, capped at duration*fps.
                activeFrames = find(bool);
                nActive = numel(activeFrames);
                if nActive == 0
                    obj.applog('warn', ...
                        'Act "%s" has zero active frames in this session', sel);
                    return;
                end
                nTake = min(nActive, nWin);
                selFrames = activeFrames(1:nTake);

                % Event ID per active frame: 1,1,1, 2,2, 3, ... — increments
                % each time we cross a gap between contiguous runs.
                gaps = [true, diff(activeFrames(:)') > 1];
                eventIds = cumsum(gaps);
                selEventIds = eventIds(1:nTake);
                nEvents = max(eventIds);

                % Video frame index = DLC index + StartFrame offset.
                % By default cfg.range.startFrame = 1 → offset = 0.
                videoOffset = 0;
                try
                    videoOffset = result.config.range.startFrame - 1;
                catch
                end

                % --- 3. Render BA-style into a 4D uint8 stack ---------
                dlg.Indeterminate = 'off';
                dlg.Message = 'Rendering frames...';
                frames = obj.renderActFramesInMemory( ...
                    videoPath, result, actIdx, selFrames, ...
                    selEventIds, videoOffset, dlg);
                if isempty(frames)
                    obj.applog('warn', 'No frames rendered'); return;
                end

                % --- 4. Open in implay window -------------------------
                hPlay = implay(frames, fps);
                try
                    set(hPlay.Parent, 'Name', sprintf( ...
                        'Act: %s — %d / %d active frames (%d events, %.1fs / %.1fs in session)', ...
                        sel, nTake, nActive, nEvents, nTake/fps, nActive/fps));
                    set(hPlay.Parent, 'Position', [80 80 1280 960]);
                    if isprop(hPlay, 'Visual') && isprop(hPlay.Visual, 'ScaleFactor')
                        hPlay.Visual.ScaleFactor = 0.5;
                    end
                catch
                end
                obj.applog('info', ...
                    'Made video (in memory): %s, stitched %d/%d active frames, %d events (%.1fs)', ...
                    sel, nTake, nActive, nEvents, nTake/fps);
            catch ME
                obj.applog('error', 'Make-video failed: %s', ME.message);
            end
        end

        function frames = renderActFramesInMemory(obj, videoPath, ...
                result, actIdx, dlcFrames, eventIds, videoOffset, dlg)
            % Build the 4D uint8 stack used by the Make-video preview.
            % For batch rendering to disk see renderAndSaveAllActs which
            % streams frame-by-frame to a VideoWriter.
            if nargin < 6 || isempty(eventIds); eventIds = []; end
            if nargin < 7 || isempty(videoOffset); videoOffset = 0; end
            reader = VideoReader(videoPath);
            cleaner = onCleanup(@() delete(reader)); %#ok<NASGU>
            ctx = obj.buildRenderContext(result, actIdx, ...
                reader.Height, reader.Width);
            nFrames = numel(dlcFrames);
            frames = zeros(reader.Height, reader.Width, 3, nFrames, 'uint8');
            for i = 1:nFrames
                f = dlcFrames(i);
                vF = f + videoOffset;
                try
                    img = read(reader, vF);
                catch
                    continue;
                end
                eId = [];
                if ~isempty(eventIds); eId = eventIds(i); end
                img = renderOneFrame(img, f, eId, ctx);
                frames(:, :, :, i) = img;
                if mod(i, 10) == 0 && ~isempty(dlg) && isvalid(dlg)
                    dlg.Value = i / nFrames;
                    dlg.Message = sprintf('Rendering %d / %d', i, nFrames);
                end
            end
        end

        function ctx = buildRenderContext(obj, result, actIdx, H, W)
            % Precompute everything renderOneFrame needs: bodypart
            % colours, the act's highlighted bodypart, the zone mask,
            % whether to show velocity. Same struct is reused for both
            % the in-memory preview and the on-disk batch render.
            ctx.bps = result.BodyPartsTraces;
            ctx.nBP = numel(ctx.bps);
            ctx.bpColors = uint8(round(lines(max(1, ctx.nBP)) * 255));
            ctx.hiColor = uint8([255 0 0]);
            ctx.markSize = 5;

            actBPName = '';
            if isfield(obj.State.acts(actIdx), 'bodyPart')
                actBPName = obj.State.acts(actIdx).bodyPart;
            end
            ctx.hiIdx = [];
            if ~isempty(actBPName)
                ctx.hiIdx = find(strcmpi({ctx.bps.BodyPartName}, actBPName), 1);
            end

            zoneMask = obj.actZoneMaskFromPreset(obj.State.acts(actIdx));
            if ~isempty(zoneMask) && (size(zoneMask,1) ~= H || size(zoneMask,2) ~= W)
                zoneMask = [];
            end
            ctx.zoneMask = zoneMask;

            ctx.showVelocity = false;
            ctx.velocityTrace = [];
            act = obj.State.acts(actIdx);
            if ~isempty(ctx.hiIdx) && isfield(act, 'speedMin') && isfield(act, 'speedMax')
                hasGate = (act.speedMin > 0) || isfinite(act.speedMax);
                if hasGate && isfield(ctx.bps(ctx.hiIdx), 'VelocitySmoothed') ...
                        && ~isempty(ctx.bps(ctx.hiIdx).VelocitySmoothed)
                    ctx.showVelocity = true;
                    ctx.velocityTrace = ctx.bps(ctx.hiIdx).VelocitySmoothed;
                end
            end
        end

        function renderAndSaveAllActs(obj)
            % For every act in the library, stitch its active frames and
            % stream them to a per-act .mp4 under <root>/Acts_video/.
            % Streaming (no in-memory 4D stack) so a 10-act run doesn't
            % balloon to 10 * H * W * 3 * nFrames bytes.
            if isempty(obj.State.acts)
                obj.applog('warn', 'Library is empty — nothing to render');
                return;
            end
            presetPath = obj.PresetPathField.Value;
            videoPath  = obj.VideoPathField.Value;
            if isempty(presetPath) || ~isfile(presetPath)
                obj.applog('warn', 'Load preset first'); return;
            end
            if isempty(videoPath) || ~isfile(videoPath)
                obj.applog('warn', 'Load video first'); return;
            end
            dlcPath = obj.DLCPathField.Value;
            if isempty(dlcPath) || ~isfile(dlcPath)
                dlcPath = obj.findDLCPath(presetPath, videoPath);
            end
            if isempty(dlcPath) || ~isfile(dlcPath)
                obj.applog('error', 'No DLC csv — load one explicitly'); return;
            end

            startDir = obj.resourceStartDir();
            root = uigetdir(startDir, 'Pick output root (Acts_video/ will be created inside)');
            obj.restoreFocus();
            if isequal(root, 0); return; end
            outDir = fullfile(root, 'Acts_video');
            if ~isfolder(outDir); mkdir(outDir); end

            durSec = obj.MakeVideoDurationField.Value;
            [~, sessionStem] = fileparts(videoPath);

            dlg = uiprogressdlg(obj.ParentApp.Figure, ...
                'Title', 'Render & save all acts', ...
                'Message', 'Preprocessing tracks...', ...
                'Indeterminate', 'on', 'Cancelable', 'on');
            cleaner = onCleanup(@() closeIfValid(dlg)); %#ok<NASGU>

            try
                tmpLib = [tempname '.mat'];
                sphynx.io.saveActsSet(tmpLib, obj.State.acts, '');
                cleanLib = onCleanup(@() deleteIfExists(tmpLib)); %#ok<NASGU>

                cfg = sphynx.pipeline.defaultConfig();
                cfg.paths.dlc    = dlcPath;
                cfg.paths.preset = presetPath;
                cfg.paths.outDir = tempdir;
                cfg.acts.libraryPath = tmpLib;
                cfg.viz.headless = true;
                cfg.io.saveWorkspace = false;
                result = sphynx.pipeline.analyzeSession(cfg);

                fps = result.Options.FrameRate;
                nWin = max(1, round(double(durSec) * double(fps)));
                videoOffset = 0;
                try; videoOffset = result.config.range.startFrame - 1; catch; end

                reader = VideoReader(videoPath);
                cleanerR = onCleanup(@() delete(reader)); %#ok<NASGU>
                H = reader.Height; W = reader.Width;

                nActs = numel(obj.State.acts);
                saved = 0;
                for k = 1:nActs
                    if dlg.CancelRequested
                        obj.applog('info', 'Render-all cancelled at act %d/%d', k, nActs);
                        break;
                    end
                    actName = obj.State.acts(k).name;
                    rIdx = find(strcmp({result.Acts.ActName}, actName), 1);
                    if isempty(rIdx)
                        obj.applog('warn', 'Act "%s" missing in result, skip', actName);
                        continue;
                    end
                    bool = logical(result.Acts(rIdx).ActArrayRefine);
                    activeFrames = find(bool);
                    if isempty(activeFrames)
                        obj.applog('info', '"%s" — 0 active frames, skip', actName);
                        continue;
                    end
                    nTake = min(numel(activeFrames), nWin);
                    selFrames = activeFrames(1:nTake);
                    gaps = [true, diff(activeFrames(:)') > 1];
                    eventIds = cumsum(gaps);
                    selEventIds = eventIds(1:nTake);

                    ctx = obj.buildRenderContext(result, k, H, W);

                    safe = matlab.lang.makeValidName(actName);
                    outPath = fullfile(outDir, sprintf('%s_%s.mp4', sessionStem, safe));
                    writer = VideoWriter(outPath, 'MPEG-4');
                    writer.FrameRate = fps;
                    open(writer);
                    cleanerW = onCleanup(@() closeWriter(writer)); %#ok<NASGU>

                    dlg.Indeterminate = 'off';
                    for i = 1:nTake
                        if dlg.CancelRequested; break; end
                        f = selFrames(i);
                        vF = f + videoOffset;
                        try
                            img = read(reader, vF);
                        catch
                            continue;
                        end
                        img = renderOneFrame(img, f, selEventIds(i), ctx);
                        writeVideo(writer, img);
                        if mod(i, 10) == 0
                            dlg.Value = ((k - 1) + i / nTake) / nActs;
                            dlg.Message = sprintf( ...
                                'Act %d/%d "%s": frame %d/%d', ...
                                k, nActs, actName, i, nTake);
                        end
                    end
                    clear cleanerW;  % closes writer
                    saved = saved + 1;
                    obj.applog('info', '"%s" -> %s (%d frames)', actName, outPath, nTake);
                end
                obj.applog('info', 'Render-all done: %d / %d acts saved -> %s', ...
                    saved, nActs, outDir);
            catch ME
                obj.applog('error', 'Render-all failed: %s', ME.message);
            end
        end

        function mask = actZoneMaskFromPreset(obj, act)
            % Union of act.zones lookup in LoadedPresetData.Zones.
            % Complex acts may not have a `zones` field — return empty.
            mask = [];
            if isempty(obj.LoadedPresetData) ...
                    || ~isfield(obj.LoadedPresetData, 'Zones') ...
                    || isempty(obj.LoadedPresetData.Zones); return; end
            if ~isfield(act, 'zones'); return; end
            zones = act.zones;
            if ischar(zones); zones = {zones}; end
            if isempty(zones); return; end
            allZones = obj.LoadedPresetData.Zones;
            for k = 1:numel(zones)
                idx = find(strcmp({allZones.name}, zones{k}), 1);
                if isempty(idx); continue; end
                if isfield(allZones(idx), 'maskfilled') ...
                        && ~isempty(allZones(idx).maskfilled)
                    m = logical(allZones(idx).maskfilled);
                    if isempty(mask); mask = m;
                    else; mask = mask | m; end
                end
            end
        end

        function dlcPath = findDLCPath(~, presetPath, videoPath)
            % Look for *DLC*.csv next to preset, then next to video.
            dlcPath = '';
            for d = {fileparts(presetPath), fileparts(videoPath)}
                hits = dir(fullfile(d{1}, '*DLC*.csv'));
                if ~isempty(hits)
                    dlcPath = fullfile(hits(1).folder, hits(1).name); return;
                end
            end
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
                    obj.SimpleZoneListBox.Items = ...
                        [{'<any zone>'}, {obj.ParentApp.State.zones.name}];
                    obj.SimpleZoneListBox.Value = {'<any zone>'};
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

        function restoreFocus(obj)
            % Workaround for R2020a: native uigetfile/uiputfile dialogs
            % steal focus and the parent uifigure becomes unresponsive
            % until the user clicks it. Calling figure(uifig) restores it.
            try
                if ~isempty(obj.ParentApp) && isvalid(obj.ParentApp.Figure)
                    figure(obj.ParentApp.Figure);
                    drawnow;
                end
            catch; end
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

function updateMakeVideoDlg(dlg, frac, msg)
    if isvalid(dlg)
        dlg.Value = max(0, min(1, frac));
        dlg.Message = msg;
    end
end

function closeIfValid(h)
    if ~isempty(h) && isvalid(h); try; close(h); catch; end; end
end

function deleteIfExists(p)
    if isfile(p); try; delete(p); catch; end; end
end

function newName = uniqueName(base, taken)
    % Append _2/_3/... to `base` until the result is not in `taken`.
    if ~ismember(base, taken); newName = base; return; end
    n = 2;
    while true
        candidate = sprintf('%s_%d', base, n);
        if ~ismember(candidate, taken); newName = candidate; return; end
        n = n + 1;
    end
end

function [runs, lengths] = findActiveRuns(bool)
    % Run-length encode a 1xN logical. `runs` is Mx2: each row is
    % [startIdx endIdx] of a contiguous true-run. `lengths` is Mx1.
    bool = bool(:)';
    if isempty(bool); runs = zeros(0,2); lengths = zeros(0,1); return; end
    d = diff([false, bool, false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;
    runs = [starts(:), ends(:)];
    lengths = ends(:) - starts(:) + 1;
end

function img = renderOneFrame(img, f, eventId, ctx)
    % Apply BA-style overlays to a single source frame:
    %   * zone tint (50/50 blend) where the act has zones,
    %   * filled circle at every body part (lines colormap), the
    %     act's bodypart drawn in red and slightly larger,
    %   * event-counter in the top-right corner,
    %   * velocity readout in the bottom-right corner for speed-gated
    %     acts.
    if size(img, 3) == 1
        img = repmat(img, [1 1 3]);
    end
    if ~isempty(ctx.zoneMask)
        img = uint8(round((single(img) + single(ctx.zoneMask) * 255) / 2));
    end
    for b = 1:ctx.nBP
        bp = ctx.bps(b);
        if ~isfield(bp, 'TraceSmoothed') || isempty(bp.TraceSmoothed)
            continue;
        end
        tr = bp.TraceSmoothed;
        if f > numel(tr.X); continue; end
        xb = tr.X(f); yb = tr.Y(f);
        if ~(isfinite(xb) && isfinite(yb)); continue; end
        isHi = ~isempty(ctx.hiIdx) && b == ctx.hiIdx;
        if isHi
            rad = ctx.markSize + 2; col = ctx.hiColor;
        else
            rad = ctx.markSize; col = ctx.bpColors(b, :);
        end
        img = stampCircle(img, xb, yb, rad, col);
    end
    if ~isempty(eventId)
        img = stampNumberCorner(img, sprintf('%d', eventId), 'top-right');
    end
    if ctx.showVelocity && f <= numel(ctx.velocityTrace) ...
            && isfinite(ctx.velocityTrace(f))
        img = stampNumberCorner(img, ...
            sprintf('%.1f cm/s', ctx.velocityTrace(f)), 'bottom-right');
    end
end

function closeWriter(w)
    try
        if isvalid(w); close(w); end
    catch
    end
end

function img = stampNumberCorner(img, txt, corner)
    % Stamp a short text label in one of the image corners.
    % Uses a persistent cache so identical strings aren't re-rendered.
    % Supports corners: 'top-right' (default), 'bottom-right',
    % 'top-left', 'bottom-left'.
    persistent cache
    if isempty(cache); cache = containers.Map(); end
    if nargin < 3 || isempty(corner); corner = 'top-right'; end
    key = sprintf('%s|24', txt);
    if isKey(cache, key)
        bm = cache(key);
    else
        bm = renderTextBitmap(txt, 24);
        cache(key) = bm;
    end
    if isempty(bm); return; end
    [H, W, ~] = size(img);
    [bh, bw, ~] = size(bm);
    margin = 10;
    switch corner
        case 'bottom-right'
            x0 = max(1, W - bw - margin);
            y0 = max(1, H - bh - margin);
        case 'top-left'
            x0 = margin; y0 = margin;
        case 'bottom-left'
            x0 = margin; y0 = max(1, H - bh - margin);
        otherwise % top-right
            x0 = max(1, W - bw - margin);
            y0 = margin;
    end
    x1 = min(W, x0 + bw - 1);
    y1 = min(H, y0 + bh - 1);
    sub = bm(1:(y1-y0+1), 1:(x1-x0+1), :);
    % Stamp pixels brighter than threshold (text is rendered white on
    % black, so the threshold isolates the glyph foreground).
    gray = sum(single(sub), 3);
    mask = gray > 90;
    if ~any(mask(:)); return; end
    region = img(y0:y1, x0:x1, :);
    for c = 1:3
        rc = region(:, :, c);
        bc = sub(:, :, c);
        rc(mask) = bc(mask);
        region(:, :, c) = rc;
    end
    img(y0:y1, x0:x1, :) = region;
end

function bm = renderTextBitmap(txt, fontSize)
    % Render `txt` to an RGB uint8 image via an off-screen figure and
    % crop to the glyph bounding box. White-on-black so the caller can
    % threshold cleanly when stamping.
    bm = uint8([]);
    try
        fig = figure('Visible', 'off', 'Color', 'k', ...
            'Units', 'pixels', 'Position', [0 0 200 max(40, fontSize+16)]);
        ax = axes('Parent', fig, 'Position', [0 0 1 1], ...
            'Color', 'k', 'XLim', [0 1], 'YLim', [0 1], ...
            'XTick', [], 'YTick', [], 'Visible', 'off');
        text(ax, 0.5, 0.5, txt, 'Color', 'w', ...
            'FontSize', fontSize, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle');
        drawnow;
        cdata = print(fig, '-RGBImage');
        close(fig);
        gray = sum(single(cdata), 3);
        rows = find(any(gray > 90, 2));
        cols = find(any(gray > 90, 1));
        if ~isempty(rows) && ~isempty(cols)
            bm = cdata(min(rows):max(rows), min(cols):max(cols), :);
        end
    catch
        bm = uint8([]);
    end
end

function img = stampCircle(img, cx, cy, r, color)
    % Paint a filled disc onto an HxWx3 uint8 image at (cx, cy) with
    % radius r and the given uint8 RGB color. Drop-in replacement for
    % insertShape(...,'filledcircle',...) which lives in Computer
    % Vision Toolbox (not available in this MATLAB instance).
    [H, W, C] = size(img);
    if C == 1; img = repmat(img, [1 1 3]); C = 3; end
    cx = round(cx); cy = round(cy); r = round(r);
    if ~isfinite(cx) || ~isfinite(cy) || r <= 0; return; end
    x0 = max(1, cx - r); x1 = min(W, cx + r);
    y0 = max(1, cy - r); y1 = min(H, cy + r);
    if x0 > x1 || y0 > y1; return; end
    [xg, yg] = meshgrid(x0:x1, y0:y1);
    inside = (xg - cx).^2 + (yg - cy).^2 <= r^2;
    sub = img(y0:y1, x0:x1, :);
    for c = 1:C
        slice = sub(:, :, c);
        slice(inside) = color(c);
        sub(:, :, c) = slice;
    end
    img(y0:y1, x0:x1, :) = sub;
end

function out = blendZoneMask(frame, mask)
    % BA-style 50/50 blend: where the zone mask is true, pixels are
    % averaged with full-intensity tint. Works for grayscale and RGB.
    if size(frame, 3) == 1
        frame = repmat(frame, [1 1 3]);
    end
    out = frame;
    m3 = repmat(mask, [1 1 size(out, 3)]);
    tint = uint8(255);
    out(m3) = uint8(round( ...
        (single(out(m3)) + single(tint)) / 2));
end

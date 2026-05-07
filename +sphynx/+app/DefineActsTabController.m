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
            % If the library already has user-added acts, ask whether to
            % append, replace, or cancel — silent overwrite is destructive.
            defaults = sphynx.acts.actsLibraryDefaults();
            if isempty(obj.State.acts)
                obj.State.acts = defaults;
                obj.refreshActsListBox();
                obj.applog('info', 'Loaded %d default acts', numel(defaults));
                return;
            end
            choice = uiconfirm(obj.ParentApp.Figure, ...
                sprintf(['Library already has %d act(s). Add defaults on top, ', ...
                         'or replace the whole library?'], numel(obj.State.acts)), ...
                'Load defaults', ...
                'Options', {'Append', 'Replace', 'Cancel'}, ...
                'DefaultOption', 'Append', 'CancelOption', 'Cancel');
            switch choice
                case 'Append'
                    existing = {obj.State.acts.name};
                    keep = ~ismember({defaults.name}, existing);
                    skipped = sum(~keep);
                    obj.State.acts = [obj.State.acts, defaults(keep)];
                    obj.applog('info', ['Appended %d default acts ', ...
                        '(%d skipped — name already exists)'], sum(keep), skipped);
                case 'Replace'
                    obj.State.acts = defaults;
                    obj.applog('info', 'Replaced library with %d defaults', numel(defaults));
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
            % Zones — prepend '<any zone>' sentinel meaning "no zone gate"
            if isfield(pd, 'Zones') && ~isempty(pd.Zones)
                names = [{'<any zone>'}, {pd.Zones.name}];
                obj.SimpleZoneListBox.Items = names;
                obj.SimpleZoneListBox.Value = {'<any zone>'};
                obj.applog('info', 'Loaded %d zones from preset', numel(pd.Zones));
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
                'Name',     name, ...
                'Zones',    zones, ...
                'ZoneOp',   'OR', ...
                'BodyPart', obj.SimpleBodyPartDropDown.Value, ...
                'SpeedMin', obj.SimpleSpeedMinField.Value, ...
                'SpeedMax', obj.SimpleSpeedMaxField.Value);
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

            % Row 3: load defaults / delete selected / clear all
            tb = uigridlayout(left, [1, 3]);
            tb.Layout.Row = 3;
            tb.RowHeight = {28};
            tb.ColumnWidth = {'1x', 'fit', 'fit'};
            tb.Padding = [0 0 0 0];
            tb.ColumnSpacing = 4;
            uibutton(tb, 'Text', 'Load defaults', ...
                'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.loadDefaults());
            uibutton(tb, 'Text', 'Delete', ...
                'BackgroundColor', [0.92 0.55 0.55], ...
                'Tooltip', 'Delete selected act(s) — multi-select supported', ...
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
        end

        function buildSimpleConstructor(obj, tab)
            % Round-7d layout: 2x2 outer grid.
            %   top-left  : compact form (name / bodypart / speed / add)
            %   top-right : Zones listbox (large)
            %   bottom    : zone preview axes + Make-video controls
            outer = uigridlayout(tab, [2, 2]);
            % Top row fixed shorter so Zones listbox is ~half height of
            % the bottom preview area.
            outer.RowHeight = {180, '1x'};
            outer.ColumnWidth = {220, '1x'};
            outer.RowSpacing = 6;
            outer.ColumnSpacing = 6;
            outer.Padding = [6 6 6 6];

            % --- TOP-LEFT: compact form ----------------------------------
            form = uigridlayout(outer, [6, 2]);
            form.Layout.Row = 1; form.Layout.Column = 1;
            form.RowHeight = repmat({28}, 1, 6);
            form.ColumnWidth = {90, '1x'};
            form.RowSpacing = 4;
            form.ColumnSpacing = 4;
            form.Padding = [0 0 0 0];

            uilabel(form, 'Text', 'Name:');
            obj.SimpleNameField = uieditfield(form, 'text', 'Value', '');

            uilabel(form, 'Text', 'Body part:');
            obj.SimpleBodyPartDropDown = uidropdown(form, ...
                'Items', {'bodycenter', 'tailbase', 'nose', 'headcenter'}, ...
                'Value', 'bodycenter');

            uilabel(form, 'Text', 'Speed min:');
            obj.SimpleSpeedMinField = uieditfield(form, 'numeric', 'Value', 0, ...
                'Tooltip', '0 = no lower limit (cm/s)');

            uilabel(form, 'Text', 'Speed max:');
            obj.SimpleSpeedMaxField = uieditfield(form, 'numeric', 'Value', Inf, ...
                'Tooltip', 'Inf = no upper limit (cm/s)');

            % Hidden — back-compat, always 'OR'
            obj.SimpleZoneOpDropDown = uidropdown(form, ...
                'Items', {'OR'}, 'Value', 'OR', 'Visible', 'off');
            uilabel(form, 'Text', '', 'Visible', 'off');

            uilabel(form, 'Text', '');
            uibutton(form, 'Text', 'Add to library', ...
                'BackgroundColor', [1.00 0.55 0.55], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.addSimpleAct());

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
            mv.ColumnWidth = {110, 70, 110, 'fit', '1x'};
            mv.ColumnSpacing = 6;
            mv.Padding = [0 0 0 0];
            uilabel(mv, 'Text', 'Make video — duration:');
            obj.MakeVideoDurationField = uieditfield(mv, 'numeric', ...
                'Value', 30, 'Limits', [1 600], ...
                'Tooltip', 'Seconds of footage to render around the act');
            uilabel(mv, 'Text', 'sec, act =');
            uilabel(mv, 'Text', '(use selected in library)', ...
                'FontAngle', 'italic', 'FontColor', [0.4 0.4 0.4]);
            obj.MakeVideoButton = uibutton(mv, 'Text', 'Make video', ...
                'BackgroundColor', [1.00 0.55 0.55], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.makeActVideo());
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
                nWin = max(1, round(durSec * fps));
                idx0 = find(bool, 1, 'first');
                if isempty(idx0)
                    obj.applog('warn', ...
                        'Act "%s" has zero active frames in this session', sel);
                    return;
                end
                startF = idx0;
                endF   = min(numel(bool), startF + nWin - 1);

                % --- 3. Render BA-style into a 4D uint8 stack ---------
                dlg.Indeterminate = 'off';
                dlg.Message = 'Rendering frames...';
                frames = obj.renderActFramesInMemory( ...
                    videoPath, result, actIdx, startF, endF, dlg);
                if isempty(frames)
                    obj.applog('warn', 'No frames rendered'); return;
                end

                % --- 4. Open in implay window -------------------------
                hPlay = implay(frames, fps);
                try
                    set(hPlay.Parent, 'Name', sprintf( ...
                        'Act: %s — frames %d..%d (%.1fs @ %.1f fps)', ...
                        sel, startF, endF, size(frames,4)/fps, fps));
                catch
                end
                obj.applog('info', ...
                    'Made video (in memory): %s, frames %d..%d (%.1fs)', ...
                    sel, startF, endF, size(frames,4)/fps);
            catch ME
                obj.applog('error', 'Make-video failed: %s', ME.message);
            end
        end

        function frames = renderActFramesInMemory(obj, videoPath, ...
                result, actIdx, startF, endF, dlg)
            % BA-style overlay: optional zone tint (50/50 blend) +
            % per-bodypart dots; the act's bodypart drawn larger and
            % in red so it stands out from the others.
            reader = VideoReader(videoPath);
            cleaner = onCleanup(@() delete(reader)); %#ok<NASGU>
            H = reader.Height; W = reader.Width;
            bps = result.BodyPartsTraces;
            nBP = numel(bps);
            bpColors = uint8(round(lines(max(1, nBP)) * 255));

            % Highlight bodypart for this act
            actBPName = '';
            if isfield(obj.State.acts(actIdx), 'bodyPart')
                actBPName = obj.State.acts(actIdx).bodyPart;
            end
            hiIdx = [];
            if ~isempty(actBPName)
                hiIdx = find(strcmpi({bps.BodyPartName}, actBPName), 1);
            end
            hiColor = uint8([255 0 0]);

            % Zone mask (union of act's zones) — for tint only.
            zoneMask = obj.actZoneMaskFromPreset(obj.State.acts(actIdx));
            if ~isempty(zoneMask) ...
                    && (size(zoneMask,1) ~= H || size(zoneMask,2) ~= W)
                zoneMask = []; % size mismatch — drop quietly
            end

            nFrames = endF - startF + 1;
            frames = zeros(H, W, 3, nFrames, 'uint8');
            markSize = 5;
            for i = 1:nFrames
                f = startF + i - 1;
                try
                    img = read(reader, f);
                catch
                    continue;
                end
                if size(img, 3) == 1
                    img = repmat(img, [1 1 3]);
                end
                if ~isempty(zoneMask)
                    tinted = uint8(round( ...
                        (single(img) + single(zoneMask) * 255) / 2));
                    img = tinted;
                end
                for b = 1:nBP
                    if ~isfield(bps(b), 'TraceSmoothed') ...
                            || isempty(bps(b).TraceSmoothed); continue;
                    end
                    tr = bps(b).TraceSmoothed;
                    if f > numel(tr.X); continue; end
                    xb = tr.X(f); yb = tr.Y(f);
                    if ~(isfinite(xb) && isfinite(yb)); continue; end
                    isHi = ~isempty(hiIdx) && b == hiIdx;
                    if isHi
                        rad = markSize + 2; col = hiColor;
                    else
                        rad = markSize; col = bpColors(b, :);
                    end
                    img = insertShape(img, 'filledcircle', ...
                        [xb yb rad], 'Color', col, ...
                        'Opacity', 1, 'SmoothEdges', false);
                end
                frames(:, :, :, i) = img;
                if mod(i, 10) == 0 && ~isempty(dlg) && isvalid(dlg)
                    dlg.Value = i / nFrames;
                    dlg.Message = sprintf('Rendering %d / %d', i, nFrames);
                end
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

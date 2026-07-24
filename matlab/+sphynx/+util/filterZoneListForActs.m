function names = filterZoneListForActs(Zones)
% FILTERZONELISTFORACTS  Return zone names suitable for the
%   "act target zone" listbox in DefineActs.
%
%   names = sphynx.util.filterZoneListForActs(Zones)
%
%   Drops composite zones whose mask is the union of other zones
%   already in the list -- naming an act after them would be
%   redundant with picking the components, and CreatePresetApp's
%   semantic-color render skips them too (NaN sentinel) since
%   they would overpaint their components in the combined layout.
%
%   Currently filters: walls_and_corners, walls_and_corners_realout.
%
%   Returns 1xN cellstr in the original input order, minus the
%   filtered names. Returns {} for empty or non-struct input.

    if isempty(Zones) || ~isstruct(Zones)
        names = {};
        return;
    end
    allNames = {Zones.name};
    isComposite = strcmp(allNames, 'walls_and_corners') | ...
                  strcmp(allNames, 'walls_and_corners_realout');
    names = allNames(~isComposite);
    if isempty(names); names = {}; end
end

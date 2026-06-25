function bk = actBucket(name)
% ACTBUCKET  Classify an act-name into one of four buckets.
%
%   bk = sphynx.util.actBucket(name)
%
%   Returns one of: 'speed' | 'spatial' | 'posture' | 'composite'.
%   Matching is case-insensitive. Buckets drive etogram ordering and
%   the overlay sections in AnalyzeSessionTabController + renderActsVideo:
%     speed   -- rest, walk, locomotion
%     spatial -- act named after a preset zone (see below)
%     posture -- freezing, rear
%     composite -- everything else
%
%   "Spatial" covers the union of zone names emitted by every
%   CreatePresetApp strategy (square corners-walls-center, circle,
%   circle-with-center, circle-rings, strips, none, Barnes-style
%   object/target/start with object zones). Matching is by literal
%   name for the legacy fixed zones, by regex for the per-region and
%   per-object families:
%     legacy fixed : wall, walls, corners, center, middle,
%                    middle_zone, arena, walls_and_corners
%     per-region   : <prefix>_realout (walls_realout, corners_realout,
%                    arena_realout, walls_and_corners_realout)
%     numbered     : middle\d+, strip\d+(_realout)?, arenacorner\d+
%     per-object   : <name>_(real|realout|out|center)
%                    -- catches object1_real, objectall_realout,
%                       target_center, start_out, etc.
%     at-prefix    : at_<name> -- the readable-name convention for
%                    paradigm-default zone-presence acts (e.g.
%                    at_target, at_mistake, at_platform, at_object3)
%
%   See +sphynx/+app/CreatePresetApp.m::zoneColorMap for the
%   authoritative semantic-color list and +sphynx/+zones/* for the
%   strategy emitters.

    if ~ischar(name) && ~isstring(name)
        bk = 'composite'; return;
    end
    nm = lower(char(name));

    if any(strcmp(nm, {'rest', 'walk', 'locomotion'}))
        bk = 'speed';
    elseif any(strcmp(nm, {'freezing', 'rear'}))
        bk = 'posture';
    elseif isSpatialName(nm)
        bk = 'spatial';
    else
        bk = 'composite';
    end
end

function tf = isSpatialName(nm)
    legacy = {'corners', 'walls', 'walls_and_corners', 'center', ...
              'middle_zone', 'wall', 'middle', 'arena'};
    if any(strcmp(nm, legacy)); tf = true; return; end

    patterns = { ...
        '^walls_realout$', ...
        '^corners_realout$', ...
        '^arena_realout$', ...
        '^walls_and_corners_realout$', ...
        '^middle\d+$', ...
        '^strip\d+(_realout)?$', ...
        '^arenacorner\d+$', ...
        '^[a-z_][a-z0-9_]*_(real|realout|out|center)$', ...
        '^at_[a-z_][a-z0-9_]*$' ...
    };
    for i = 1:numel(patterns)
        if ~isempty(regexp(nm, patterns{i}, 'once'))
            tf = true; return;
        end
    end
    tf = false;
end

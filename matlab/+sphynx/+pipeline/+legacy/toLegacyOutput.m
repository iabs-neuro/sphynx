function legacy = toLegacyOutput(result)
% TOLEGACYOUTPUT  Convert new-pipeline result to legacy field shape.
%
%   legacy = sphynx.pipeline.legacy.toLegacyOutput(result) takes the
%   struct returned by sphynx.pipeline.analyzeSession and remaps a
%   subset of its fields to the legacy {Acts, BodyPartsTraces, Point,
%   Options, Zones, ArenaAndObjects, n_frames} shape so that downstream
%   legacy scripts (Commander_*) can consume the new pipeline's output
%   without modification.
%
%   Note: only fields that exist in both shapes are populated. The
%   new pipeline does NOT compute every legacy field (some are
%   visualization-only and excluded by design).

    legacy.Acts = result.Acts;
    legacy.BodyPartsTraces = result.BodyPartsTraces;
    legacy.Point = result.Point;
    legacy.Options = result.Options;
    legacy.Zones = result.Zones;
    legacy.ArenaAndObjects = result.ArenaAndObjects;
    legacy.n_frames = result.n_frames;
end

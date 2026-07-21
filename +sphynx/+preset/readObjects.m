function objects = readObjects(frame, geometries, varargin)
% READOBJECTS  Interactively define objects on `frame`.
%
%   objects = sphynx.preset.readObjects(frame, geometries, ...)
%
%   Inputs:
%     frame      - HxWxC display image
%     geometries - cell array of 'Polygon'|'Circle'|'Ellipse', one per object
%
%   Optional name-value:
%     'PointsPerObject' - cell array of pre-clicked Nx2 matrices, one
%                         per object (for testing)
%
%   Output: 1xK struct array (K = numel(geometries)) with same shape
%   as readArenaGeometry's output but type='ObjectN'.
%
%   Decomposition of legacy CreatePreset.m:350-407.

    p = inputParser;
    addRequired(p, 'frame');
    addRequired(p, 'geometries');
    addParameter(p, 'PointsPerObject', {});
    parse(p, frame, geometries, varargin{:});

    K = numel(geometries);
    % Field set must match sphynx.preset.readArenaGeometry's output
    % (which always sets .class); otherwise objects(k) = a throws
    % "dissimilar structures" on the first assignment.
    objects = struct('type', {}, 'geometry', {}, 'class', {}, ...
                     'border_x', {}, 'border_y', {}, ...
                     'border_separate_x', {}, 'border_separate_y', {}, 'mask', {});

    for k = 1:K
        if k <= numel(p.Results.PointsPerObject)
            pts = p.Results.PointsPerObject{k};
            extraArgs = {'Points', pts};
        else
            extraArgs = {};
        end
        a = sphynx.preset.readArenaGeometry(frame, geometries{k}, extraArgs{:});
        a.type = sprintf('object%d', k);
        objects(k) = a;
    end
end

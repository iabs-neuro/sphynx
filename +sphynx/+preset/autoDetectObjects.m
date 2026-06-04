function objs = autoDetectObjects(gray, arenaMask, cfg)
% AUTODETECTOBJECTS  Detect objects inside arena via local-threshold or Hough.
%
%   objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg)
%
%   gray       HxW grayscale uint8/uint16/double
%   arenaMask  HxW logical
%   cfg fields (struct):
%     mode         'free-form' | 'all-circles' | 'all-polygons' | 'all-ellipses'
%     algorithm    'threshold' | 'hough'  (hough only for all-circles)
%     sensitivity  0..1
%     minAreaCm2, maxAreaCm2  scalar
%     pxlPerCm     scalar
%     radiusRangePx  (hough only) [rMin rMax]
%
%   Returns struct array with fields type/geometry/border_x/border_y/mask/class.

    objs = struct('type', {}, 'geometry', {}, 'border_x', {}, ...
        'border_y', {}, 'mask', {}, 'class', {});
    if isempty(arenaMask) || ~any(arenaMask(:))
        return;
    end
    if size(gray, 3) > 1
        gray = rgb2gray(gray);
    end
    gray = im2uint8(gray);
    [H, W] = size(arenaMask);
    minAreaPx = cfg.minAreaCm2 * (cfg.pxlPerCm^2);
    maxAreaPx = cfg.maxAreaCm2 * (cfg.pxlPerCm^2);

    % 50% area cap: no single detected object may exceed 50% of arena area.
    arenaArea    = sum(arenaMask(:));
    maxAreaPxEff = min(maxAreaPx, arenaArea * 0.5);

    if strcmp(cfg.mode, 'all-circles') && strcmp(cfg.algorithm, 'hough')
        [centers, radii] = imfindcircles(gray, cfg.radiusRangePx, ...
            'Sensitivity', cfg.sensitivity, 'ObjectPolarity', 'dark');
        for k = 1:size(centers, 1)
            cx = centers(k, 1); cy = centers(k, 2); r = radii(k);
            % Clamp to valid indices before centroid-in-arena check
            cyIdx = max(1, min(H, round(cy)));
            cxIdx = max(1, min(W, round(cx)));
            if ~arenaMask(cyIdx, cxIdx); continue; end
            ang = linspace(0, 2*pi, 60)';
            bx = cx + r * cos(ang);
            by = cy + r * sin(ang);
            mask = imfill(sphynx.preset.maskFromBorder( ...
                H, W, bx, by), 'holes');
            area = sum(mask(:));
            if area < minAreaPx || area > maxAreaPxEff; continue; end
            objs(end + 1) = mkObj('Circle', bx, by, mask); %#ok<AGROW>
        end
        return;
    end

    % Erode arena mask by ~1 cm so detected objects don't touch the boundary.
    % This prevents a darkened boundary ring from being returned as a blob.
    erosionRadius = max(3, round(cfg.pxlPerCm));
    arenaMaskEroded = imerode(arenaMask, strel('disk', erosionRadius));
    if ~any(arenaMaskEroded(:))
        % Fall back to unEroded mask if arena is too small for erosion
        arenaMaskEroded = arenaMask;
    end

    % Compute arena-floor-based threshold to prevent adaptthresh boundary
    % artifacts on synthetic/uniform backgrounds. Use the 75th percentile
    % of arena pixels as the floor level; sensitivity scales how far below
    % floor a pixel must be to count as an object (higher sens = catch more).
    arenaVals = double(gray(arenaMask));
    floorLevel = prctile(arenaVals, 75);
    floorFrac  = 1 - (1 - cfg.sensitivity) * 0.4;
    floorThresh = floorLevel / 255 * floorFrac;

    threshMap = adaptthresh(gray, cfg.sensitivity);
    % Use the stricter (lower) of adaptthresh and floor-based threshold so
    % that adaptthresh boundary artefacts on uniform backgrounds are suppressed.
    combinedThresh = min(threshMap, floorThresh);
    binary = imbinarize(gray, combinedThresh);
    % Objects are typically darker than the floor -> invert; use eroded mask
    binary = ~binary & arenaMaskEroded;
    binary = imopen(binary, strel('disk', 2));
    cc = bwconncomp(binary);
    stats = regionprops(cc, 'Centroid', 'Area', 'PixelIdxList', ...
        'MajorAxisLength', 'MinorAxisLength', 'Orientation');
    for k = 1:numel(stats)
        if stats(k).Area < minAreaPx || stats(k).Area > maxAreaPxEff; continue; end
        c = stats(k).Centroid;
        % Clamp centroid to valid indices before mask lookup
        cyIdx = max(1, min(H, round(c(2))));
        cxIdx = max(1, min(W, round(c(1))));
        if ~arenaMask(cyIdx, cxIdx); continue; end

        compMask = false(H, W);
        compMask(cc.PixelIdxList{k}) = true;

        switch cfg.mode
            case {'free-form', 'all-polygons'}
                B = bwboundaries(compMask, 'noholes');
                if isempty(B); continue; end
                v = B{1};
                bx = v(:, 2); by = v(:, 1);
                if strcmp(cfg.mode, 'all-polygons') && exist('reducepoly', 'file') == 2
                    rv = reducepoly([bx by], 0.02);
                    bx = rv(:, 1); by = rv(:, 2);
                end
                mask = imfill(sphynx.preset.maskFromBorder(H, W, bx, by), 'holes');
                geom = 'Polygon';
            case 'all-circles'
                B = bwboundaries(compMask, 'noholes');
                if isempty(B); continue; end
                v = B{1};
                [xc, yc, R] = sphynx.util.circleFit(v(:, 2), v(:, 1));
                ang = linspace(0, 2*pi, 60)';
                bx = xc + R*cos(ang);
                by = yc + R*sin(ang);
                mask = imfill(sphynx.preset.maskFromBorder(H, W, bx, by), 'holes');
                geom = 'Circle';
            case 'all-ellipses'
                a = stats(k).MajorAxisLength / 2;
                b = stats(k).MinorAxisLength / 2;
                rot = deg2rad(-stats(k).Orientation);
                ang = linspace(0, 2*pi, 60)';
                xx = a*cos(ang); yy = b*sin(ang);
                bx = c(1) + xx*cos(rot) - yy*sin(rot);
                by = c(2) + xx*sin(rot) + yy*cos(rot);
                mask = imfill(sphynx.preset.maskFromBorder(H, W, bx, by), 'holes');
                geom = 'Ellipse';
            otherwise
                error('sphynx:autoDetectObjects:unknownMode', ...
                    'Unknown mode: %s', cfg.mode);
        end
        objs(end + 1) = mkObj(geom, bx, by, mask); %#ok<AGROW>
    end
end

function o = mkObj(geometry, bx, by, mask)
    o.type = '';
    o.geometry = geometry;
    o.border_x = bx(:);
    o.border_y = by(:);
    o.mask = mask;
    o.class = '';
end

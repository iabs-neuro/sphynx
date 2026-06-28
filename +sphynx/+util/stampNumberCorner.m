function img = stampNumberCorner(img, txt, corner)
%STAMPNUMBERCORNER  Burn a short text label into one corner of `img`.
%   img = sphynx.util.stampNumberCorner(img, txt, corner)
%
% Renders `txt` (e.g. an event counter or a velocity readout) on a
% SOLID YELLOW square plate with BLACK text. The plate is
% `side = max(12, round(0.05 * H))` pixels per side so it scales
% with video height (R22: was 10% of min(H,W)). High contrast vs.
% any underlying video pixel.
%
% Inputs:
%   img    - HxWx[1|3] uint8
%   txt    - char/string to render
%   corner - 'top-right' (default) | 'bottom-right' | 'top-left' |
%            'bottom-left'
%
% The text bitmap is cached per (txt, fontSize) across calls so the
% same counter value is rasterised once per video.

    persistent cache
    if isempty(cache); cache = containers.Map(); end
    if nargin < 3 || isempty(corner); corner = 'top-right'; end

    [H, W, C] = size(img);
    if C == 1; img = repmat(img, [1 1 3]); end
    side = max(12, round(0.05 * H));   % 5% of video height
    side = min(side, min(H, W));

    switch corner
        case 'bottom-right'
            x0 = W - side + 1; y0 = H - side + 1;
        case 'top-left'
            x0 = 1;            y0 = 1;
        case 'bottom-left'
            x0 = 1;            y0 = H - side + 1;
        otherwise % top-right
            x0 = W - side + 1; y0 = 1;
    end
    x1 = x0 + side - 1; y1 = y0 + side - 1;

    yellow = uint8([255 220 0]);
    region = img(y0:y1, x0:x1, :);
    region(:, :, 1) = yellow(1);
    region(:, :, 2) = yellow(2);
    region(:, :, 3) = yellow(3);
    img(y0:y1, x0:x1, :) = region;

    fontSize = max(8, round(0.55 * side));
    key = sprintf('%s|%d', char(txt), fontSize);
    if isKey(cache, key)
        bm = cache(key);
    else
        bm = renderTextBitmap(char(txt), fontSize);
        cache(key) = bm;
    end
    if isempty(bm); return; end

    [bh, bw, ~] = size(bm);
    bh = min(bh, side); bw = min(bw, side);
    bm = bm(1:bh, 1:bw, :);
    tx0 = x0 + floor((side - bw) / 2);
    ty0 = y0 + floor((side - bh) / 2);
    tx1 = tx0 + bw - 1; ty1 = ty0 + bh - 1;

    gray = sum(single(bm), 3);
    mask = gray > 90;
    if ~any(mask(:)); return; end
    region = img(ty0:ty1, tx0:tx1, :);
    for c = 1:3
        rc = region(:, :, c);
        rc(mask) = 0;
        region(:, :, c) = rc;
    end
    img(ty0:ty1, tx0:tx1, :) = region;
end

function bm = renderTextBitmap(txt, fontSize)
    bm = uint8([]);
    try
        fig = figure('Visible', 'off', 'Color', 'k', ...
            'Units', 'pixels', 'Position', [0 0 240 max(40, fontSize+16)]);
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

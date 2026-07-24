function outPath = renderActStitched(result, videoPath, outDir, actNameOrIdx, varargin)
% RENDERACTSTITCHED  Per-act video built by stitching only the frames
% where the act fires, with BA-style overlays. Streams frame-by-frame
% via VideoWriter (no in-memory 4D stack).
%
%   outPath = sphynx.pipeline.renderActStitched(result, videoPath, ...
%                                               outDir, actNameOrIdx, ...)
%
% Same visual style as Define Acts' Make-video preview:
%   * optional 50/50 zone tint where the act has a zone,
%   * one filled circle per body part (lines colormap),
%   * the act's body part drawn slightly larger and red,
%   * event counter (1, 1, 1, 2, 2, 3, ...) in the top-right corner,
%   * velocity readout in the bottom-right corner for speed-gated acts.
%
% Inputs:
%   result        - struct from sphynx.pipeline.analyzeSession; each
%                   Acts(k) entry must carry Definition.zones /
%                   Definition.bodyPart for the highlight + tint.
%   videoPath     - source mp4 (read frame-by-frame).
%   outDir        - destination dir (created if missing).
%   actNameOrIdx  - act name (char) or 1-based index into result.Acts.
%
% Optional name-value:
%   'DurationSec' - cap stitched length, in seconds. Default Inf
%                   (every active frame in the session).
%   'OutputName'  - file name. Default
%                   '<videostem>_<safeActName>.mp4'.
%   'PresetData'  - struct from sphynx.io.readPreset; supplies the
%                   zone masks for the optional tint. Pass [] to skip
%                   tinting even when the act references zones.
%   'VideoOffset' - DLC frame index -> video frame offset (the
%                   video might start later than the DLC trace if
%                   cfg.range.startFrame > 1). Default 0.
%   'ProgressDlg' - uiprogressdlg handle; updated every 10 frames
%                   and honoured for CancelRequested.
%
% Returns the path of the written mp4, or '' when the act has no
% active frames in the session.

    p = inputParser;
    p.addRequired('result');
    p.addRequired('videoPath', @(s) ischar(s) || isstring(s));
    p.addRequired('outDir', @(s) ischar(s) || isstring(s));
    p.addRequired('actNameOrIdx');
    p.addParameter('DurationSec', Inf, @(v) isnumeric(v) && v > 0);
    p.addParameter('OutputName', '', @(s) ischar(s) || isstring(s));
    p.addParameter('PresetData', [], @(s) isempty(s) || isstruct(s));
    p.addParameter('VideoOffset', 0, @isnumeric);
    % uiprogressdlg returns matlab.ui.dialog.ProgressDialog, which
    % isgraphics() rejects in R2020a. Accept any non-empty handle and
    % defensively use isvalid()/CancelRequested inside the loop.
    p.addParameter('ProgressDlg', [], @(d) isempty(d) || (isscalar(d) && isvalid(d)));
    parse(p, result, videoPath, outDir, actNameOrIdx, varargin{:});

    % --- Resolve act ----------------------------------------------------
    if ischar(actNameOrIdx) || isstring(actNameOrIdx)
        actIdx = find(strcmp({result.Acts.ActName}, char(actNameOrIdx)), 1);
    else
        actIdx = actNameOrIdx;
    end
    if isempty(actIdx) || actIdx < 1 || actIdx > numel(result.Acts)
        error('sphynx:renderActStitched:missingAct', ...
            'Act "%s" not found in result.Acts', char(actNameOrIdx));
    end
    actName = result.Acts(actIdx).ActName;
    bool = logical(result.Acts(actIdx).ActArrayRefine);
    activeFrames = find(bool);
    if isempty(activeFrames)
        outPath = ''; return;
    end

    fps = result.Options.FrameRate;
    durSec = p.Results.DurationSec;
    if isfinite(durSec)
        nWin = max(1, round(double(durSec) * double(fps)));
        nTake = min(numel(activeFrames), nWin);
    else
        nTake = numel(activeFrames);
    end
    selFrames = activeFrames(1:nTake);
    gaps = [true, diff(activeFrames(:)') > 1];
    eventIds = cumsum(gaps);
    selEventIds = eventIds(1:nTake);

    % --- Output path ----------------------------------------------------
    [~, baseStem, ~] = fileparts(videoPath);
    outName = char(p.Results.OutputName);
    if isempty(outName)
        outName = sprintf('%s_%s.mp4', baseStem, ...
            matlab.lang.makeValidName(actName));
    end
    if ~endsWith(lower(outName), '.mp4'); outName = [outName '.mp4']; end
    if ~isfolder(outDir); mkdir(outDir); end
    outPath = fullfile(outDir, outName);

    % --- Reader / writer / context -------------------------------------
    reader = VideoReader(videoPath);
    cleanerR = onCleanup(@() delete(reader)); %#ok<NASGU>
    H = reader.Height; W = reader.Width;

    writer = VideoWriter(outPath, 'MPEG-4');
    writer.FrameRate = fps;
    open(writer);
    cleanerW = onCleanup(@() closeWriterIfValid(writer)); %#ok<NASGU>

    bps = result.BodyPartsTraces;
    nBP = numel(bps);
    bpColors = uint8(round(lines(max(1, nBP)) * 255));
    hiColor  = uint8([255 0 0]);
    markSize = 5;

    actDef = struct();
    if isfield(result.Acts(actIdx), 'Definition')
        actDef = result.Acts(actIdx).Definition;
    end
    actBPName = '';
    if isfield(actDef, 'bodyPart'); actBPName = actDef.bodyPart; end
    hiIdx = [];
    if ~isempty(actBPName)
        hiIdx = find(strcmpi({bps.BodyPartName}, actBPName), 1);
    end

    zoneMask = [];
    pd = p.Results.PresetData;
    if ~isempty(pd) && isfield(actDef, 'zones') && ~isempty(actDef.zones) ...
            && isfield(pd, 'Zones') && ~isempty(pd.Zones)
        zoneNames = actDef.zones;
        if ischar(zoneNames); zoneNames = {zoneNames}; end
        for zi = 1:numel(zoneNames)
            idx = find(strcmp({pd.Zones.name}, zoneNames{zi}), 1);
            if isempty(idx); continue; end
            if isfield(pd.Zones(idx), 'maskfilled') ...
                    && ~isempty(pd.Zones(idx).maskfilled)
                m = logical(pd.Zones(idx).maskfilled);
                if isempty(zoneMask); zoneMask = m;
                else; zoneMask = zoneMask | m; end
            end
        end
        if ~isempty(zoneMask) && (size(zoneMask, 1) ~= H || size(zoneMask, 2) ~= W)
            zoneMask = [];
        end
    end

    showVelocity = false;
    velocityTrace = [];
    if ~isempty(hiIdx)
        hasGate = false;
        if isfield(actDef, 'speedMin') && actDef.speedMin > 0; hasGate = true; end
        if isfield(actDef, 'speedMax') && isfinite(actDef.speedMax); hasGate = true; end
        if hasGate && isfield(bps(hiIdx), 'VelocitySmoothed') ...
                && ~isempty(bps(hiIdx).VelocitySmoothed)
            showVelocity = true;
            velocityTrace = bps(hiIdx).VelocitySmoothed;
        end
    end

    videoOffset = p.Results.VideoOffset;
    dlg = p.Results.ProgressDlg;

    % --- Stream frames --------------------------------------------------
    for i = 1:nTake
        if ~isempty(dlg) && isvalid(dlg) && isprop(dlg, 'CancelRequested') ...
                && dlg.CancelRequested
            break;
        end
        f  = selFrames(i);
        vF = f + videoOffset;
        try
            img = read(reader, vF);
        catch
            continue;
        end
        if size(img, 3) == 1; img = repmat(img, [1 1 3]); end
        if ~isempty(zoneMask)
            img = uint8(round((single(img) + single(zoneMask) * 255) / 2));
        end
        for b = 1:nBP
            if ~isfield(bps(b), 'TraceSmoothed') ...
                    || isempty(bps(b).TraceSmoothed); continue; end
            tr = bps(b).TraceSmoothed;
            if f > numel(tr.X); continue; end
            xb = tr.X(f); yb = tr.Y(f);
            if ~(isfinite(xb) && isfinite(yb)); continue; end
            isHi = ~isempty(hiIdx) && b == hiIdx;
            if isHi; rad = markSize + 2; col = hiColor;
            else;    rad = markSize;     col = bpColors(b, :); end
            img = stampCircleLocal(img, xb, yb, rad, col);
        end
        img = sphynx.util.stampNumberCorner(img, sprintf('%d', selEventIds(i)), 'top-right');
        if showVelocity && f <= numel(velocityTrace) ...
                && isfinite(velocityTrace(f))
            img = sphynx.util.stampNumberCorner(img, ...
                sprintf('%.1f cm/s', velocityTrace(f)), 'bottom-right');
        end
        writeVideo(writer, img);
        if ~isempty(dlg) && isvalid(dlg) && mod(i, 10) == 0
            try
                dlg.Value = i / nTake;
                dlg.Message = sprintf('"%s": %d / %d', actName, i, nTake);
            catch
            end
        end
    end
end

% --- File-scope helpers (mirror DefineActsTabController) ---------------

function closeWriterIfValid(w)
    try
        if isvalid(w); close(w); end
    catch
    end
end

function img = stampCircleLocal(img, cx, cy, r, color)
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

% R22: stampNumberLocal / renderTextBitmapLocal removed -- both
% callers above now use sphynx.util.stampNumberCorner so the corner
% counter style (5%H yellow square + BLACK text) is identical to
% Make-video in Define Acts.

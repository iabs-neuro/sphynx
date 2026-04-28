function out = pickGoodFrame(videoPath, varargin)
% PICKGOODFRAME  Show frames from `videoPath` until user accepts one.
%
%   out = sphynx.preset.pickGoodFrame(videoPath, ...)
%
%   Interactive: opens the video, shows the middle frame, asks
%   "good frame?". On 'No', picks a random frame and repeats.
%
%   Optional name-value:
%     'FrameIndex' - if supplied, skip the dialog and return that frame
%
%   Output struct:
%     frame      - HxWx3 uint8 image
%     frameGray  - HxW uint8 image
%     frameIndex - chosen index
%     frameRate, numFrames, height, width  - video metadata

    p = inputParser;
    addRequired(p, 'videoPath');
    addParameter(p, 'FrameIndex', []);
    parse(p, videoPath, varargin{:});

    v = VideoReader(videoPath);
    out.frameRate = v.FrameRate;
    out.numFrames = v.NumFrames;
    out.height = v.Height;
    out.width = v.Width;

    if ~isempty(p.Results.FrameIndex)
        idx = p.Results.FrameIndex;
    else
        idx = round(out.numFrames / 2);
        prmt = 0;
        while prmt == 0
            frame = read(v, idx);
            h = figure;
            imshow(frame); hold on;
            answer = questdlg('Is this a good frame?', 'Pick frame', 'Yes', 'No', 'Yes');
            delete(h);
            if strcmp(answer, 'Yes')
                prmt = 1;
            else
                idx = randi([1, out.numFrames]);
            end
        end
    end

    out.frame = read(v, idx);
    out.frameGray = out.frame(:, :, 1);
    out.frameIndex = idx;
end

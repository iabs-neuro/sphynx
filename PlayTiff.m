function [numframe] = PlayBadTiff(path, filename, PlayMode, SaveAviMode, NormMode)
% made by VVP 18.11.22
% to view the tif files
% just run and select the file (but before point the PathOut, PlayMode and SaveAviMode)

%% 
PathOut = 'g:\_Projects\FOS-GFP\exp4\';

if nargin<5
    [filename, path]  = uigetfile('*.*','Select video file','g:\_Projects\FOS-GFP\exp3\data\');     
    PlayMode = 1;
    SaveAviMode = 0;
    NormMode = 0;
end

Length_path = 27; %number of first symbol of "good" path

FullPath = fullfile(path, filename);
info = imfinfo(FullPath);
numframe = length(info);
h = waitbar(1/numframe, sprintf('Loading video, frame %d of %d', 0,  numframe));
for frame = 1 : numframe
    if ~mod(frame, 20)
        h = waitbar(frame/numframe, h, sprintf('Loading video, frame %d of %d', frame,  numframe));        
    end
    if NormMode
        rawframes(:,:,:,frame) = mat2gray(imread(FullPath, frame));
    else
        rawframes(:,:,:,frame) = imread(FullPath, frame);
    end
end
delete(h);

if PlayMode
    implay(rawframes) 
end

%% saving mp4
if SaveAviMode
    FrameRate = 20;
    Speed = 1;
    OutputName = sprintf('%s.mp4', strrep(path(Length_path:end), '\','_')); 
    YourVideo = VideoWriter(sprintf('%s%s',PathOut, OutputName), 'MPEG-4');
    YourVideo.FrameRate = round(FrameRate*Speed);

    open(YourVideo);
    h = waitbar(0, sprintf('Saving video file %d of %d', 0,  numframe)); 
    for frame = 1 : numframe
        if ~mod(frame, 20)
            waitbar(frame/(numframe), h, sprintf('Saving video file %d of %d', frame,  numframe));
        end  
        writeVideo(YourVideo,rawframes(:,:,:,frame));
    end
    delete(h);
    close(YourVideo);
end

end
%% paths and filenames
ExpID = 'NOF';
PathMat = 'e:\Projects\NOF\BehaviorData\5.1_matfiles\';
PathOut = 'e:\Projects\NOF\BehaviorData\8_Video_acts\';

FileNames = {
    'H01_1D','H02_1D','H03_1D','H06_1D','H07_1D','H08_1D','H09_1D','H14_1D','H23_1D',...
    'H26_1D','H27_1D','H31_1D','H32_1D','H33_1D','H36_1D','H39_1D',...
    'H01_2D','H02_2D','H03_2D','H06_2D','H07_2D','H08_2D','H09_2D','H14_2D','H23_2D'...
    'H26_2D','H27_2D','H31_2D','H32_2D','H33_2D','H36_2D','H39_2D',...
    'H01_3D','H02_3D','H03_3D','H06_3D','H07_3D','H08_3D','H09_3D','H14_3D','H23_3D',...
    'H26_3D','H27_3D','H31_3D','H32_3D','H33_3D','H36_3D','H39_3D',...
    'H01_4D','H02_4D','H03_4D','H06_4D','H07_4D','H08_4D','H09_4D','H14_4D','H23_4D',...  
    'H26_4D','H27_4D','H31_4D','H32_4D','H33_4D','H36_4D','H39_4D',...
    };

FilesNumber = length(FileNames);

%% collect data

for filef = 1:length(FileNames)
    filef
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{filef});
    
%     load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'n_frames', 'Options');
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{filef}));
    PathOut = 'e:\Projects\NOF\BehaviorData\8_Video_acts\';
    
    % reading video file
    PathVideo = 'e:\Projects\NOF\BehaviorData\2_RawCombineVideo\';
    FilenameVideo = sprintf('NOF_%s.mp4', FileNames{filef});
    readerobj = VideoReader(sprintf('%s%s', PathVideo, FilenameVideo));
    
    MaxPoints = 10000000;
    
%     for act = 1:size(Acts,2)
    for act = [4 5]
        fprintf('Plotting video %d/%d. Act: %s\n', act, size(Acts,2), string(Acts(act).ActName));
%         v = VideoWriter(sprintf('%s\\ActsVideo\\%s_act_%s',PathOut, Filename, string(Acts(act).ActName)),'MPEG-4');
        v = VideoWriter(sprintf('%s\\%s_act_%s',PathOut, Filename, string(Acts(act).ActName)),'MPEG-4');
        v.FrameRate = Options.FrameRate;
        open(v);
                
        videoframes = find(Acts(act).ActArrayRefine');
        videoframesMax = min(length(videoframes),MaxPoints);
        h = waitbar(1/videoframesMax, sprintf('Plotting video, frame %d of %d', 0,  videoframesMax));
        nframe = 1;
        for k = videoframes(1:videoframesMax)
            
            if ~mod(k,10)
                h = waitbar(nframe/videoframesMax, h, sprintf('Plotting video, frame %d of %d', nframe,  videoframesMax));
            end
            nframe = nframe+1;
            if isempty(Acts(act).Zone)
                RealFrame = read(readerobj,k+StartTime-1);
            else
                RealFrame = round((Zones(Acts(act).Zone).maskfilled*255 + single(read(readerobj,k+StartTime-1)))./2);
            end
            
            % points of bodyparts in a fixed frame of reference
            for part=1:length(BodyPartsNames)
                RealFrame = insertShape(RealFrame,'circle', [BodyPartsTraces(part).TraceOriginal.X(k)/Options.x_kcorr BodyPartsTraces(part).TraceOriginal.Y(k) MarkSize*2],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
                RealFrame = insertShape(RealFrame,'filledcircle', [BodyPartsTracesMainX(part,k)/Options.x_kcorr BodyPartsTracesMainY(part,k) MarkSize],'Color',colorbase(part,:).*255,'LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
            end
            
            writeVideo(v,uint8(RealFrame));
        end
        close(v);
        delete(h);
    end
    
end

ExpID = 'LNOF';

PathMat = 'e:\Projects\LNOF\BehaviorData\6_Behav_mat\';

% PathOut = sprintf('e:\\Projects\\%s\\BehaviorData\\5_BehaviorSeparate\\',ExpID);

FileNames = {
    'J01_1D' 'J01_2D' 'J01_3D' 'J01_4D' 'J05_1D' 'J05_2D' 'J05_3D' 'J05_4D' ...
    'J06_1D' 'J06_2D' 'J06_3D' 'J06_4D' 'J12_1D' 'J12_2D' 'J12_3D' 'J12_4D' ...
    'J14_1D' 'J14_2D' 'J14_3D' 'J14_4D' 'J18_1D' 'J18_2D' 'J18_3D' 'J18_4D' ...
    'J19_1D' 'J19_2D' 'J19_3D' 'J19_4D' 'J20_1D' 'J20_2D' 'J20_3D' 'J20_4D' ...
    'J21_1D' 'J21_2D' 'J21_3D' 'J21_4D' 'J23_1D' 'J23_2D' 'J23_3D' 'J23_4D' ...
    'J24_1D' 'J24_2D' 'J24_3D' 'J24_4D' 'J25_1D' 'J25_2D' 'J25_3D' 'J25_4D' ...
                                        'J30_1D' 'J30_2D' 'J30_3D' 'J30_4D' ...
                                        'J52_1D' 'J52_2D' 'J52_3D' 'J52_4D' ...
    'J53_1D' 'J53_2D' 'J53_3D' 'J53_4D' 'J54_1D' 'J54_2D' 'J54_3D' 'J54_4D' ...
    'J55_1D' 'J55_2D' 'J55_3D' 'J55_4D' 'J56_1D' 'J56_2D' 'J56_3D' 'J56_4D' ...
    'J57_1D' 'J57_2D' 'J57_3D' 'J57_4D' 'J58_1D' 'J58_2D' 'J58_3D' 'J58_4D' ...
    'J59_1D' 'J59_2D' 'J59_3D' 'J59_4D' 'J61_1D' 'J61_2D' 'J61_3D' 'J61_4D' ...
    };

%% collect data

for file = [13 17:length(FileNames)]
    file
    fprintf('Processing of %s_%s\n', ExpID,  FileNames{file});
    
%     load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}), 'Acts', 'BodyPartsTraces', 'Point', 'n_frames', 'Options');
    load(sprintf('%s%s_%s_WorkSpace.mat', PathMat, ExpID, FileNames{file}));
    
    MaxPoints = 200000000;
    
%     for act = 1:size(Acts,2)
    for act = [4 5]
        
        fprintf('Plotting video %d/%d. Act: %s\n', act, size(Acts,2), string(Acts(act).ActName));
        v = VideoWriter(sprintf('%s\\ActsVideo\\%s_act_%s',PathOut, Filename, string(Acts(act).ActName)),'MPEG-4');
        v.FrameRate = Options.FrameRate;
        open(v);
        h = waitbar(1/n_frames, sprintf('Plotting video, frame %d of %d', 0,  n_frames));
        
        videoframes = find(Acts(act).ActArrayRefine');
        videoframesMax = min(length(videoframes),MaxPoints);
        
        for k = videoframes(1:videoframesMax)
            
            if ~mod(k,10)
                h = waitbar(k/n_frames, h, sprintf('Plotting video, frame %d of %d', k,  n_frames));
            end
            
            if isempty(Acts(act).Zone)
                RealFrame = read(readerobj,k+StartTime-1);
            else
                RealFrame = round((Zones(Acts(act).Zone).maskfilled*255 + single(read(readerobj,k+StartTime-1)))./2);
            end
            
            % field of view
            if Acts(act).ActName == "bowlInView" || Acts(act).ActName == "objectInView"
                RealFrame = insertShape(RealFrame, 'Line', View.Line.L(k,:), 'LineWidth', 3, 'Color', 'red');
                RealFrame = insertShape(RealFrame, 'Line', View.Line.R(k,:), 'LineWidth', 3, 'Color', 'red');
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

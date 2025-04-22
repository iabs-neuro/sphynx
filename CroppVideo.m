function CroppVideo(path, filename, pathout, method, lvl)
% made by VVP 05.02.23
% to cropp the video files
% 'division' - separate video on two parts by vertical lines, save all
% parts

if nargin<5
    [filename, path]  = uigetfile('*.*','Select video file','g:\_Projects\_OF [2023]\VT_original\');     
    pathout = path;
    method = 'division';
    lvl = 0;
end    

FullPath = fullfile(path, filename);
readerobj = VideoReader(FullPath);
FrameRate = get(readerobj, 'FrameRate');
NumFrames = get(readerobj, 'NumFrames');
Width = get(readerobj, 'Width');
Height = get(readerobj, 'Height');

%% searching of a good frame
if lvl == 0
    gframe = round(NumFrames/2);
    prmt = 0;
    while prmt==0    
        vidFrames = read(readerobj,gframe);
        h=figure;
        IM = vidFrames(:,:,1);
        imshow(IM);hold on;
        answer = questdlg('Is it good frame?', 'Cup and arena plot', 'Yes','No','Yes');
        switch answer
            case 'Yes'      
                prmt = 1;            
            case 'No'        
                prmt = 0;
                gframe=gframe+round(NumFrames/100);            
        end
        delete(h);
    end
end

%% searching of cropp area
switch method
    case 'division'
        if lvl == 0
            prmt = 0;
            while prmt == 0
                h=figure;
                imshow(IM);hold on; 
                uiwait(msgbox('Indicate points of separate line','Message for you','modal'));
                [x, y] = ginput;
                plot(x,y, 'o', 'LineWidth', 2);
                x_mean = mean(x); 
                plot(ones(Height,1)*x_mean,1:Height, 'r', 'LineWidth', 2);

                answer = questdlg('Is it correct?', 'Separate line',	'Yes','No','Yes');
                switch answer
                    case 'Yes'      
                        prmt = 1;
                    case 'No'        
                        prmt = 0;           
                end    
                delete(h);
            end
        else
            x_mean = lvl;
        end
end

%% saving video
for part = 1:2
    v = VideoWriter(sprintf('%s\\%s_A%d',pathout, filename(1:end-4), part),'MPEG-4');
    v.FrameRate = FrameRate;
    open(v);

    h = waitbar(1/NumFrames, sprintf('Saving %d video, frame %d of %d', part, 0,  NumFrames));
    for k=1:NumFrames
%     for k=1:100
        if mod(k,1000) == 0
                h = waitbar(k/NumFrames, h, sprintf('Saving %d video, frame %d of %d', part, k,  NumFrames));   
        end
        IM = read(readerobj,k);
        if part == 1
            IMM = IM(:,1:x_mean, :);
        else
            IMM = IM(:,x_mean:end, :);
        end
%         imshow(IMM);
        writeVideo(v,IMM);
    end
    close(v);
    delete(h);
end
end

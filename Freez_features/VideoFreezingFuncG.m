function [PctComponentTimeFreezing] = VideoFreezingFuncG(PlotVideo,path,filename,Both,CompUp,CompDown,noiZelvl,MinLengthFreez,MotThres,FreezDuratV,Line)
% 10.01.23 save only one part (down)
% Both = 3; for only down part calculation
% Line = 0; if you want to select manually
% Line = 144; height for standart boxes
if nargin<11
    %%
    [filename, path]  = uigetfile('*.wmv','Select wmv file','d:\Projects\Trace\RawData\'); 
    Both = listdlg('PromptString','Select the way of mouse location ','ListString', {'whole cage', 'up side', 'down side', 'both side'},'ListSize',  [170 60]);
    prompt = {'Duration of components for up sector, s','Duration of components for down sector, s', 'Noiz level(0-255)','Filter window','Motion threshold, px', 'Minimum Freeze Duration (number of frames for 30fps)', 'Dividing line height (zero to select manually)'}; 
    default_data = {'300','300','13','5','18','15','144'};
    options.Resize='on';
    dlg_data = inputdlg(prompt, 'Parameters', 1, default_data, options);
    DuratCompUp = str2num(dlg_data{1});
    DuratCompDown = str2num(dlg_data{2});
    DuratCompUp = dlg_data{1};
    DuratCompDown = dlg_data{2};
    noiZelvl = str2num(dlg_data{3});
    MinLengthFreez = str2num(dlg_data{4});
    MotThres = str2num(dlg_data{5});
    FreezDuratV = str2num(dlg_data{6});
    Line = str2num(dlg_data{7});
    PlotVideo = 1;
else
    DuratCompUp = str2num(CompUp);
    DuratCompDown = str2num(CompDown);
end
%% 
save(sprintf('%s\\%s_WorkSpace_%d_%d_%d_%d.mat',path, filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV));

MaxLengthFreez = FreezDuratV;
disp('Loading video');
readerobj = VideoReader(sprintf('%s\\%s', path, filename));
vidFrames = read(readerobj);
numFrames = get(readerobj, 'NumFrames');
FrameRate = get(readerobj, 'FrameRate');
Height = get(readerobj, 'Height');
Width = get(readerobj, 'Width');

h = waitbar(1/numFrames, sprintf('Reading frames %d of %d', 0,  numFrames));
for frames = 1:numFrames
    if ~mod(frames,100)
        h = waitbar(frames/numFrames, h, sprintf('Reading frames %d of %d', frames,  numFrames));
    end
    movie43(frames).data = vidFrames(:,:,1,frames);           
end
delete(h);

%dividing in sectors
if Both ~= 1 
%     IM = movie43(100).data;
%     h = figure;
%     imshow(IM);
%     hold on;
    x1 = linspace(1,Width,Width);
    if Line == 0
        prompt = {'Степень полинома кривой раздела(3-6)'};
        default_data = {'0'};
        options.Resize='on';
        dlg_data = inputdlg(prompt, 'Parameters', 1, default_data, options);
        degree = str2num(dlg_data{1});
        [x, y] = ginput;
        p = polyfit(x,y,degree);        
        y1 = polyval(p,x1);    
        plot(x,y,'o')
        hold on;
    else
        y1 = ones(1,Width).*Line;        
    end    
%     plot(x1,y1)
end

%main part
NumberComp(1) = length(DuratCompUp);
NumberComp(2) = length(DuratCompDown);
numFramesVcomp(1:2,1) = 0;    
for i=1:NumberComp(1)-1        
    numFramesVcomp(1,i+1) = numFramesVcomp(1,i)+DuratCompUp(i)*30;           
end
for i=1:NumberComp(2)-1                        
    numFramesVcomp(2,i+1) = numFramesVcomp(2,i)+DuratCompDown(i)*30;
end
numFramesVcomp(1,NumberComp(1)+1) = numFrames-1;
numFramesVcomp(2,NumberComp(2)+1) = numFrames-1;

%making mask
upMask = uint8(ones(Height, Width));
downMask = uint8(ones(Height, Width));
if Both ~= 1
    for j = 1:Width          
        for kk = round(y1(j)):Height
            upMask(kk,j) = 0;
        end
    end    
end
downMask = uint8(downMask-upMask);

    up = 1;
    down = 2;
if Both == 2 || Both == 1
    up = 1;
    down = 1;
end
if Both == 3
    up = 2;
    down = 2;
end
save(sprintf('%s\\%s_WorkSpace_%d_%d_%d_%d.mat',path, filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV));

%%
for m = up:down
    if m == 1
        Mask = upMask;
    else
        Mask = downMask;
    end
    
    %Motion index processing
    numFramesV=numFrames-1;
    MotInd(m,1:numFramesV) = zeros(1,numFramesV);
    
%     h = waitbar(1/numFramesV, sprintf('Motion index processing %d of %d', 0,  numFramesV));
%     dat2(1:Height,1:Width,1:numFramesV) = 0; 
    for i = 1:numFramesV
%         h = waitbar(i/numFramesV, h, sprintf('Motion index processing %d of %d', i,  numFramesV));     
        dat0 = movie43(i).data;
        dat1 = movie43(i+1).data;     
        dat2 = uint8(abs(double(dat0.*Mask)-double(dat1.*Mask)));
        Pix = size(find(dat2>noiZelvl));
        dat2 = uint8((dat2>noiZelvl))*255;
        MotInd(m,i) = Pix(1);     
    end   
%     delete(h);


    %searching of freeze time
    MotIndThres(m,1:numFramesV) = zeros(1,numFramesV);
    for i = 1 : numFramesV
        if MotInd(m,i) < MotThres
            MotIndThres(m,i) = 1;    
        end
    end
    
    %%
    % new code for smoothing acts of freezing
    freez = MotIndThres(m,:);
    
    % filtering
    freez_filt0 = MyFilt1(freez,MinLengthFreez, 0);
    freez_filt1 = MyFilt1(freez_filt0,MaxLengthFreez, 1);
    
    %calculating time parameters of freezing
    [freez_ref, ~, ~, ~, ~, ~] = RefineLine(freez_filt1, 0, 0);
 
    %plot raw and ref freez signal
    freez_ref_plot = freez_ref;
    freez_ref_plot(freez_ref_plot == 0) = NaN;
    time2 = linspace(1,numFramesV,numFramesV);
    
    h = figure;
    title('Raw and refined freez line','FontSize', 15);
    xlabel('Frame, 30Hz','FontSize', 15);hold on;
    ylabel('Freezing acts/Motion index','FontSize', 15);hold on;
    plot(time2,MotInd(m,:), 'b');hold on;
    plot(1:length(freez),freez.*MotThres ,'g','LineWidth', 2);hold on;
    plot(1:length(freez_ref),freez_ref.*(MotThres+3) ,'c','LineWidth', 2);    
    legend('Motion index','Freez raw','Freez refine');
    saveas(h,fullfile(path, sprintf('%s_FreezRawVsRef_%d_%d_%d_%d.png',filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV)));
    saveas(h,fullfile(path, sprintf('%s_FreezRawVsRef_%d_%d_%d_%d.fig',filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV)));
    delete(h);
    
    %% making video
    if PlotVideo
        v = VideoWriter(sprintf('%s\\%s_freezing_%d_%d_%d_%d',path, filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV),'MPEG-4');
        v.FrameRate = FrameRate;
        open(v);
        
        BlackFrame(1:Height,1:Width,3) = 0;
        BlackFrame = uint8(BlackFrame);
        
        h = waitbar(1/frames, sprintf('Plotting video, frame %d of %d', 0,  frames));
        for k=1:frames-1
            if ~mod(k,100)
                h = waitbar(k/frames, h, sprintf('Plotting video, frame %d of %d', k,  frames));
            end
            
            %         RealFrame = read(readerobj,k);
            %         if freez_ref(k)
            %             IM = [RealFrame RealFrame];
            %         else
            %             IM = [BlackFrame RealFrame];
            %         end
            % %         imshow(IM);
            
            dat0 = movie43(k).data;
            dat1 = movie43(k+1).data;
            dat2 = uint8(abs(double(dat0.*Mask)-double(dat1.*Mask)));
            dat2 = uint8((dat2>noiZelvl))*255;
            
            MovFrame(:,:,1) = uint8(dat2);
            MovFrame(:,:,2) = uint8(dat2);
            MovFrame(:,:,3) = uint8(dat2);
            RealFrame = read(readerobj,k);
            if freez_ref(k)
                IM = [RealFrame(round(y1(j)):Height,:,:); RealFrame(round(y1(j)):Height,:,:); MovFrame(round(y1(j)):Height,:,:)];
            else
                IM = [RealFrame(round(y1(j)):Height,:,:); BlackFrame(round(y1(j)):Height,:,:); MovFrame(round(y1(j)):Height,:,:)];
            end
            %         imshow(IM);
            
            writeVideo(v,IM);
        end
        close(v);
        delete(h);
    end
    %%
    
    %searching of freeze act taking into account the parameters
    count = 0; 
    MotIndThresFreez(m,1:numFrames) = zeros(1,numFrames);
    for i = 1 : numFramesV
        if freez_ref(i) == 1
            count = count+1;
        end
        if ((freez_ref(i) == 0) || ((freez_ref(i) == 1)&&(i == numFramesV))) && (count ~=0)             
            if count >= FreezDuratV-1                
                for k =1:count+1
                    if i ~= numFramesV
                        MotIndThresFreez(m,i-count+k-1) = 1;
                    end
                    if (freez_ref(i) == 1)&&(i == numFramesV)
                        MotIndThresFreez(m,i-count+k) = 1;
                    end
                end
            end
            count = 0;
        end
    end

% %making array for plots
% MotIndThresFreez2(m,:) = zeros(1,numFrames);
% for i = 1 : numFrames
%    if MotIndThresFreez(m,i) == 0
%        MotIndThresFreez2(m,i) = NaN; 
%    end
% end
% 
% % plots for movement index and acts of freezes
% hh = figure;
% time = linspace(1,numFrames,numFrames);
% time2 = linspace(1,numFramesV,numFramesV);
% if m==1
%     title('cage up');
% else
%     title('cage down');
% end
% plot(time2,MotInd(m,:));hold on;
% plot(time,MotIndThresFreez2(m,:)*3,'r', 'Linewidth', 3);

%dividing in components
for l = 1:NumberComp(m)
    summa(m,l) = sum(MotIndThresFreez(m,numFramesVcomp(m,l)+1:numFramesVcomp(m,l+1)));
    TimeFreezing(m,l) = summa(m,l)/FrameRate;
    PctComponentTimeFreezing(m,l) = summa(m,l)/(numFramesVcomp(m,l+1)-numFramesVcomp(m,l))*100;
end

csvwrite(sprintf('%s\\%s_Freezing_%d_%d_%d_%d.csv',path,filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV), MotIndThresFreez(2,:)');
csvwrite(sprintf('%s\\%s_MotionIndext_%d_%d_%d_%d.csv',path,filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV), MotInd(2,:)');
save(sprintf('%s\\%s_WorkSpace_%d_%d_%d_%d.mat',path, filename(1:end-4),noiZelvl,MinLengthFreez,MotThres,FreezDuratV));

end

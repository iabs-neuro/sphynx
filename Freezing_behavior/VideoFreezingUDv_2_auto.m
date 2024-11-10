%reading video
% clear all;
function PctComponentTimeFreezing(2) = VideoFreezingFunk(path,filename)
% [filename, path]  = uigetfile('*.wmv','Select wmv file','D:\_projects\Olya\Tanya_olya\Извлечение'); 
readerobj = VideoReader(sprintf('%s%s', path, filename));
vidFrames = read(readerobj);
numFrames = get(readerobj, 'NumberOfFrames');
Height = get(readerobj, 'Height');
Width = get(readerobj, 'Width');
h = waitbar(1/numFrames, sprintf('Reading frames %d of %d', 0,  numFrames));
for frames = 1:numFrames
    h = waitbar(frames/numFrames, h, sprintf('Reading frames %d of %d', frames,  numFrames));   
    movie43(frames).data = vidFrames(:,:,1,frames);           
end
delete(h);

%default parameters reading
% Both = listdlg('PromptString','Select the way of mouse location ','ListString', {'whole cage', 'up side', 'down side', 'both side'},'ListSize',  [170 60]);
Both = 4;
%dividing in sectors
if Both ~= 1 
    IM = movie43(100).data;
    h = figure;
    imshow(IM);
    hold on;
%         prompt = {'Степень полинома кривой раздела(3-6)'};
%         default_data = {'0'};
%         options.Resize='on';
%         dlg_data = inputdlg(prompt, 'Parameters', 1, default_data, options);
%         degree = str2num(dlg_data{1});
%     [x, y] = ginput;
%     p = polyfit(x,y,degree);
    x1 = linspace(1,Width,Width);
%     y1 = polyval(p,x1);
    y1 = ones(1,Width)*144;
%     plot(x,y,'o')
    hold on;
    plot(x1,y1)    
%     delete(h);
end

% prompt = {'Duration of components for up sector, s','Duration of components for down sector, s', 'Noiz level(0-255)','Motion threshold, px', 'Minimum Freeze Duration (number of frames for 30fps)'}; 
    %default_data = {'60 60 60 60 60 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8 2 8','60 60 60 60 60 60 60 60 60','13','20','5'};
    default_data = {'180','180','12','20','5'};
%     default_data = {'60 60 60 2 2 2 2 2 2 2 2 2 60 2 2 2 2 2 2 2 2 2 60 2 2 2 2 2 2 2 2 2 60 2 2 2 2 2 2 2 2 2 60 2 2 2 2 2 2 2 2 2 60 2 2 2 2 2 2 2 2 2 60 2 2 2 2 2 2 2 2 2','60 2 30','12','20','5'};
%     default_data = {'60 60 60 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2','60 60 60 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2','12','20','5'};    
%default_data = {'60 13 2 51 13 2 54 13 2 48 13 2 57 13 2 50 13 2 55 13 2 60','60 15 51 15 54 15 48 15 57 15 50 15 55 15 60','12','20','5'};
    options.Resize='on';
    dlg_data = inputdlg(prompt, 'Parameters', 1, default_data, options);
    DuratComp.up = str2num(dlg_data{1});
    DuratComp.down = str2num(dlg_data{2});
    noiZelvl = str2num(dlg_data{3});
    MotThres = str2num(dlg_data{4});
    FreezDuratV = str2num(dlg_data{5});

NumberComp(1) = length(DuratComp.up);
NumberComp(2) = length(DuratComp.down);
    numFramesVcomp(1:2,1) = 0;    
    for i=1:NumberComp(1)-1        
            numFramesVcomp(1,i+1) = numFramesVcomp(1,i)+DuratComp.up(i)*30;           
    end
    for i=1:NumberComp(2)-1                        
            numFramesVcomp(2,i+1) = numFramesVcomp(2,i)+DuratComp.down(i)*30;
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

for m = up:down
    if m == 1
        Mask = upMask;
    else
        Mask = downMask;
    end
    
    %Motion index processing
    numFramesV=numFrames-1;
    MotInd(m,1:numFramesV) = zeros(1,numFramesV);
    h = waitbar(1/numFramesV, sprintf('Motion index processing %d of %d', 0,  numFramesV));
    for i = 1:numFramesV
        h = waitbar(i/numFramesV, h, sprintf('Motion index processing %d of %d', i,  numFramesV));     
        dat0 = movie43(i).data;
        dat1 = movie43(i+1).data;     
        dat2 = uint8(abs(double(dat0.*Mask)-double(dat1.*Mask)));
        Pix = size(find(dat2>noiZelvl));
        MotInd(m,i) = Pix(1);     
    end
    delete(h);
    
    %searching of freeze time
    MotIndThres(m,1:numFramesV) = zeros(1,numFramesV);
    for i = 1 : numFramesV
        if MotInd(m,i) < MotThres
            MotIndThres(m,i) = 1;    
        end
    end
    
    %searching of freeze act taking into account the parameters
    count = 0; 
    MotIndThresFreez(m,1:numFrames) = zeros(1,numFrames);
    for i = 1 : numFramesV
        if MotIndThres(m,i) == 1
            count = count+1;
        end
        if ((MotIndThres(m,i) == 0) || ((MotIndThres(m,i) == 1)&&(i == numFramesV))) && (count ~=0)             
            if count >= FreezDuratV-1                
                for k =1:count+1
                    if i ~= numFramesV
                        MotIndThresFreez(m,i-count+k-1) = 1;
                    end
                    if (MotIndThres(m,i) == 1)&&(i == numFramesV)
                        MotIndThresFreez(m,i-count+k) = 1;
                    end
                end
            end
            count = 0;
        end
    end


%making array for plots
MotIndThresFreez2(m,:) = zeros(1,numFrames);
for i = 1 : numFrames
   if MotIndThresFreez(m,i) == 0
       MotIndThresFreez2(m,i) = NaN; 
   end
end

% plots for movement index and acts of freezes
h = figure;
time = linspace(1,numFrames,numFrames);
time2 = linspace(1,numFramesV,numFramesV);
if m==1
    title('cage up');
else
    title('cage down');
end
plot(time2,MotInd(m,:));hold on;
plot(time,MotIndThresFreez2(m,:),'r');


%dividing in components
for l = 1:NumberComp(m)        
        summa(m,l) = sum(MotIndThresFreez(m,numFramesVcomp(m,l)+1:numFramesVcomp(m,l+1)));
        TimeFreezing(m,l) = summa(m,l)/30;
        PctComponentTimeFreezing(m,l) = summa(m,l)/(numFramesVcomp(m,l+1)-numFramesVcomp(m,l))*100;
    end
end


csvwrite(sprintf('%s%s_MotInd_%d.csv',path,filename,noiZelvl), MotIndThresFreez(2,:)');
end
% figure
% time2 = linspace(1,NumberComp(1),NumberComp(1));
% plot(time2,PctComponentTimeFreezing(1,1:NumberComp(1)));
% title('mouse up');
% figure
% if m == 2
% time3 = linspace(1,NumberComp(2),NumberComp(2));
% plot(time3,PctComponentTimeFreezing(2,1:NumberComp(2)));
% end
% title('mouse down');
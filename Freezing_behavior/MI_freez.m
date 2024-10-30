
path = 'g:\_Projects\FEAR TRANS [2022]\FEAR transmission\social learning fear context\Social_learning_8Step\Social_learning_8Step_1D_training\video\';
NameFile1 = 'Social_learning_8Step_1D_training ';
NameFile2 = '.wmv_MotInd_13.csv';
nameAC = {'5 Box 1','5 Box 2','5 Box 3','5 Box 4', ...
    '10 Box 1','10 Box 2','10 Box 3','10 Box 4', ...
    '12 Box 1','12 Box 2'};

nameTR = {'7 Box 1','7 Box 2','7 Box 3','7 Box 4', ...
    '8 Box 1','8 Box 2','8 Box 3','8 Box 4', ...
    '9 Box 1','9 Box 2','9 Box 3','9 Box 4', ...
    '11 Box 1','11 Box 2','11 Box 3','11 Box 4', ...
    '13 Box 1','13 Box 2','13 Box 3','13 Box 4'};

namePreTR = {'1 Box 1','1 Box 2','1 Box 3','1 Box 4', ...
    '2 Box 1','2 Box 2','2 Box 3','2 Box 4', ...
    '3 Box 1','3 Box 2','3 Box 3','3 Box 4', ...
    '4 Box 1','4 Box 2','4 Box 3','4 Box 4'};

name = namePreTR;
PointTrain = 30*5*60;
for file = 1:length(name)
    MotInd = csvread(sprintf('%s%s%s%s',path,NameFile1,name{file},NameFile2))';
    numFramesV = length(MotInd);
    MotThres = 20;
    FreezDuratV = 5;
    for m=1:2
        %поиск актов замирания
        MotIndThres(m,1:numFramesV) = zeros(1,numFramesV);
        for i = 1 : numFramesV
            if MotInd(m,i) < MotThres
                MotIndThres(m,i) = 1;    
            end
        end

        %выделение актов по характеристикам
        count = 0; 
        MotIndThresFreez(m,1:numFramesV) = zeros(1,numFramesV);
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
    end

%     plot(1:numFramesV,MotIndThresFreez(:,1:numFramesV));
    PreTrain = MotIndThresFreez(:,1:PointTrain);
    Train = MotIndThresFreez(:,PointTrain:numFramesV);
    
    %PreTrain MI
    x = PreTrain(1,:);
    y = PreTrain(2,:);
    n = length(PreTrain);
    J = [sum(~x & ~y),sum(~x & y);sum(x & ~y),sum(x & y)]/n;
    MI(file,1) = sum(sum(J.*log2(J./(sum(J,2)*sum(J,1)))));
    
    %PTrain MI
    x = Train(1,:);
    y = Train(2,:);
    n = length(Train);
    J = [sum(~x & ~y),sum(~x & y);sum(x & ~y),sum(x & y)]/n;
    MI(file,2) = sum(sum(J.*log2(J./(sum(J,2)*sum(J,1)))));
    
end
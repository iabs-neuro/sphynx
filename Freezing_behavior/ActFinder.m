function [Acts, ActsNumber] = ActFinder(line, TimeAct,TimeSilenceAct)
%Searching acts in line of 1 and 0 (acts is ones) in line of ones manner.
%Appropriate like a mask for plotting 
% line = [0,0,1,1,1,1,1,1,1,0,0,0,1,1,1];
% TimeAct = 3;
% TimeSilenceAct = 2;
frames = length(line);
ActsLength = [];
count=line(1);
Acts(1:frames) = 0;
for i=2:frames
    if line(i) == 1
        count = count+1;
    end
    if ((line(i) == 0) && (line(i-1) == 1)) || ((line(i) == 1) && (i == frames))
        add = double(i==frames);
        if (count >= TimeAct) && (i+add > count+TimeSilenceAct) && sum(line(i+add-count-TimeSilenceAct:i+add-count-1)) == 0 
            for j=1:TimeAct+TimeSilenceAct
                Acts(i+add-count-TimeSilenceAct+j-1) = 1;
            end
            ActsLength = [ActsLength count];
        end  
        count = 0;
    end
end
ActsNumber=length(ActsLength);
end




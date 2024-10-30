function [Acts, ActsNumber] = ActFinder2(line, TimeAct,TimeSilenceAct)
%searching acts in line of 1 and 0 (acts is ones) in "start and end frame"
% manner
% line = [0,0,1,1,1,1,1,1,1,0,0,0,1,1,1];
% TimeAct = 3;
% TimeSilenceAct = 2;
frames = length(line);
ActsLength = [];
count=line(1);
Acts = [];
for i=2:frames
    if line(i) == 1
        count = count+1;
    end
    if ((line(i) == 0) && (line(i-1) == 1)) || ((line(i) == 1) && (i == frames))
        add = double(i==frames);
        if (count >= TimeAct) && (i+add > count+TimeSilenceAct) && sum(line(i+add-count-TimeSilenceAct:i+add-count-1)) == 0 
            Acts = [Acts; [i+add-count, i+add-1]];
            ActsLength = [ActsLength count];
        end  
        count = 0;
    end
end
ActsNumber=length(ActsLength);
end



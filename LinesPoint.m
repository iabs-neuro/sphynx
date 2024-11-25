function [x,y] = LinesPoint(k1,B1,k2,B2)
%finding a point of intersection of lines
    if k1 == k2
        k2 = k2+0.01;
    end
    x = (B2-B1)/(k1-k2);
    y = k1*x+B1;
%     if x == Inf || x == -Inf 
end
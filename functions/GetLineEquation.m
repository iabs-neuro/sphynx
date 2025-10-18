function [equation] = GetLineEquation(Point1, Point2)
% Define equation [k B x] of line on two points.
% If equation "y = kx+B", then [k B x] = [k B nan].
% If equation "x = a",    then [k B x] = [nan nan a], where "a" is a number.
% If Point1 == Point2,    then [k B x] = [nan nan nan].
% VVP. 21.02.23

if Point1(1) == Point2(1)
    if Point1(2) == Point2(2)
        equation = [nan nan nan];
    else
        equation = [nan nan Point1(1)];
    end
else
    k = (Point1(2)-Point2(2))/(Point1(1)-Point2(1));
    B = (Point2(2)*Point1(1)-Point1(2)*Point2(1))/(Point1(1)-Point2(1));
    equation = [k B nan];
end
end

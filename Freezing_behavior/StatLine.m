function [line_time] = StatLine(line, value)
    antivalue = double(~value);    
    frames = length(line);
    count = double(line(1) == value);
    k=1;
    line_time =[];
    for i=2:frames
        if line(i) == value
            count = count+1;
        end
        if ((line(i) == antivalue) && (line(i-1) == value)) || (line(i) == value && i==frames)
           line_time(k) = count;
           count = 0; 
           k = k + 1;
        end
    end
end

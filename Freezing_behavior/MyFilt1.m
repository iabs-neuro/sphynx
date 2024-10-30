% filter hmm.. like a median but without bias and for logical data 
function [line] = MyFilt1(line,wind,value)
    antivalue = double(~value);    
    frames = length(line);
    count = double(line(1) == value);
    for i=2:frames
        if line(i) == value
            count = count+1;
        end
        if ((line(i) == antivalue) && (line(i-1) == value))
            if count < wind && i-count ~= 1
                for j=1:count
                    line(i-j) = antivalue;
                end            
            end
           count = 0; 
        end
    end
end

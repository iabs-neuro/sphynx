% median 
% function line = MyMedFilt1(line,wind)    
    line = [0,1,1,0,1,1,1,0,0,1,1,1,0,0,0,1,1,1,1,1,0]
    
    frames = length(line);
    count = mod(line(1)+1,2);
    for i=2:frames
        if line(i) == 0
            count = count+1;
        end
        if ((line(i) == 1) && (line(i-1) == 0))
            if count < wind && i-count ~= 1
                for j=1:count
                    line(i-j) = 1;
                end            
            end
           count = 0; 
        end
    end
    line
%     line = line./line;
% end

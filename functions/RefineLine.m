function [line_ref, entries, time, count_time, frame_in, frame_out] = RefineLine(line, min_frame1, minframe0) 
% act's statistics calculation 
% 04.12.24 Improved to handle edge cases [1,1,1,1,1]
% 06.03 time calculation changed, now in frames

n_frames = length(line);
line_ref(1:n_frames) = 0;
if line(1)==1
    count=1;
else
    count=0;
end

for i=2:n_frames
    if line(i) == 1
        count = count+1;
    end
    if ((line(i) == 0) && (line(i-1) == 1)) || (line(i) == 1 && i==n_frames)     
        if count >=min_frame1
            for j=1:count
                if i-j > 0 
                    line_ref(i-j) = 1;
                end
            end
            if i==n_frames
               line_ref(i) = 1;
               if i-count > 0
                line_ref(i-count) = 0;
               end
            end
        end  
        count = 0;
    end
end

if line_ref(1)==0
    count0=1;
else
    count0=0;
end

for i=2:n_frames
    if line(i) == 0
        count0 = count0+1;
    end
    if ((line_ref(i) == 1) && (line_ref(i-1) == 0))
        if count0 < minframe0 && i-count0 ~= 1
            for j=1:count0
                if i-j > 0
                    line_ref(i-j) = 1;
                end
            end            
        end
       count0 = 0; 
    end
end

if line_ref(1)==1
    count=1;
else
    count=0;
end
k=1;
count_time =[];
frame_out = [];
frame_in = [];
for i=2:n_frames
    if line_ref(i) == 1
        count = count+1;
    end
    if ((line_ref(i) == 0) && (line_ref(i-1) == 1)) || (line_ref(i) == 1 && i==n_frames)
        count_time(k)=count;
        if i ~= n_frames
            frame_out(k) = i-1;
            frame_in(k)= i-count;
        else
            frame_out(k) = i;
            frame_in(k)= i-count+1;
        end
        k=k+1;
        count=0;
    end
end
entries=length(count_time);
time = sum(count_time);
end
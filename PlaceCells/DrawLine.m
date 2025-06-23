% line = field_line_2s;
% x_line = x_int_sm;
% y_line = y_int_sm;
% s = 'b';
function [h] = DrawLine(x_line, y_line, line, x_kcorr, s, grad, width)
k=1;
l=1;
if grad
    colorstring = 'gbrcmyk';
else
    colorstring = s;
end

clear pline;
for i=2:length(line)
   if line(i) == 1
       pline(k) = i;
       k=k+1;
   end   
   if (line(i)==0) && (line(i-1) == 1) || (line(i) == 1 && i==length(line)) 
       if grad
           h = plot(x_line(pline)/x_kcorr,y_line(pline), colorstring(mod(l,7)+1), 'LineWidth',width);
       else
           h = plot(x_line(pline)/x_kcorr,y_line(pline), s, 'LineWidth',width);
       end
       hold on;
       k=1;
       l=l+1;
       clear pline;
   end        
end
end

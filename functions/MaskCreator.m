function Mask = MaskCreator(Mask, x, y)
% create 2D Mask with borders (x,y)

Height = size(Mask, 1);
Width = size(Mask,2);
for i=1:length(x)    
    if round(y(i)) <= Height && round(y(i)) > 0 && round(x(i)) <= Width && round(x(i)) > 0
        Mask(round(y(i)),round(x(i))) = 1;    
    end
end

end
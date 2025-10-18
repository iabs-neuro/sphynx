function [x_border, y_border, x_separate_border, y_separate_border] = PolygonFit(x,y)
% creates an array of polygon borders (x,y - arrays of corner's coordinates)
% 17.02.23 add separate border coordinates

n_corners = length(x);
x = [x; x(1)];
y = [y; y(1)];
N = 5000;
x_border = [];
y_border = [];
x_separate_border = {};
y_separate_border = {};
for i=1:n_corners
    if x(i) == x(i+1)
        x_border_i = x(i)*ones(N,1);
        y_border_i = linspace(y(i),y(i+1), N)';
    else
        kx = (y(i)-y(i+1))/(x(i)-x(i+1));
        Bx = (y(i+1)*x(i)-y(i)*x(i+1))/(x(i)-x(i+1));        
        x_border_i = linspace(x(i), x(i+1), N)';
        y_border_i = kx*x_border_i+Bx;     
    end
    x_border = [x_border; x_border_i];
    y_border = [y_border; y_border_i];
    x_separate_border{i} = x_border_i;
    y_separate_border{i} = y_border_i;
end

end
function RGB= RGB(index_or_name)
%
% OVERVIEW
%
% The Matlab function RGB() converts a color index (whole number from
% 1-21), English name of a color (string), or RGB triple with whole number
% components in {0, 1, ..., 255} into an RGB triple with real-valued
% components in [0,1].  RGB() allows the user to access a set of 21 colors
% via their common English names.  For eight of these colors that have more
% than one common name, the program accepts alternative names, reducing the
% memory burden on the user.
%
% INPUTS
%
% - index_or_name can be a color index (whole number from 1-21), a string
% containing the name of a color in lower case, an RGB triple with elements
% in [0,1], or an RGB triple with elements in [0,255].  Note that some
% colors have more than one name, in which case any of these may be used.
% See the code for the list of color names.
%
% OUTPUTS
%
% - RGB is a length-3 vector of RGB components that can be used as a color
% specifier with any of the Matlab graphics functions.
%
% If the input is an RGB triple with elements in [0,1], it is returned to
% the calling program without modification.
%
% If the input is an RGB triple with elements in [0,255], it is scaled by
% 1/255 and then returned.
%
% If the input is a color index (1-21), it is converted to an RGB triple
% via direct table lookup.
%
% If the input is the name of a color, a search is done to find a matching
% name, and the corresponding RGB triple is returned.
% 
%  FYI, RGB('chart') would show the colors with corresponding names.
%
%
% DEPENDENCIES
%
% RGB.m depends on cell2num.m and lookup.m.
%
%
% FUTURE ENHANCEMENTS
%
% I plan to at some point add code to allow the user to define additional
% colors and change the order of the colors.
%
% Dr. Phillip M. Feldman 9 April 2009
 
 
% Section 1: Define names and RGB values of 21 colors.  Note that some
% colors have more than one name.
 
colors= {
0    0    0    'black';
1    0    0    'red';
0    1    1    {'cyan','baby blue'};
1    0.6  0    'orange';
0.5  0.5  1    'light blue';
0    1    0    {'green','light green'};
0.8  0.5  0    'brown';
0.5  0.5  0.5  'dark gray';
0.25 0.25 0.9  {'blue','cobalt blue'};
1    1    0.6  'cream';
0    0.5  0    {'dark green','forest green'};
1    0.5  0.5  'peach';
1    1    0    'yellow';
0    0    0.8  {'dark blue','navy blue'};
0.8  0.8  0.8  {'gray','light gray'};
0.5  0    0.9  'purple';
0.3  0.8  0    'avocado';
1    0.5  1    {'magenta','pink'};
0    0.8  0.8  {'aqua','turquoise'};
0.9  0.75 0    'gold';
1    1    1    'white';
 
 
%----------------------------
% COLORNAME below are listed by the CSS3 proposed standard [1], which
%     contains 139 different colors (an rgb triple is a 1x3 vector of
%     numbers between 0 and 1)
% Source: http://www.mathworks.com/matlabcentral/fileexchange/24497-rgb-triple-of-color-name--version-2
% 
%   REFERENCES
%     [1] "CSS Color module level 3", W3C (World Wide Web Consortium)
%         working draft 21 July 2008, http://www.w3.org/TR/css3-color
%
%     [2] "Scalable Vector Graphics (SVG) 1.1 specification", W3C
%         recommendation 14 January 2003, edited in place 30 April 2009,
%         http://www.w3.org/TR/SVG
%
%     [3] "Web colors", http://en.wikipedia.org/wiki/Web_colors
%
%     [4] "X11 color names" http://en.wikipedia.org/wiki/X11_color_names
 
 
1.000000    1.000000    1.000000    'White';
1.000000    0.979167    0.979167    'Snow';
0.937500    1.000000    0.937500    'Honeydew';
0.958333    1.000000    0.979167    'MintCream';
0.937500    1.000000    1.000000    'Azure';
0.937500    0.970833    1.000000    'AliceBlue';
0.970833    0.970833    1.000000    'GhostWhite';
0.958333    0.958333    0.958333    'WhiteSmoke';
1.000000    0.958333    0.929688    'Seashell';
0.958333    0.958333    0.859375    'Beige';
0.991667    0.958333    0.898438    'OldLace';
1.000000    0.979167    0.937500    'FloralWhite';
1.000000    1.000000    0.937500    'Ivory';
0.979167    0.917969    0.839844    'AntiqueWhite';
0.979167    0.937500    0.898438    'Linen';
1.000000    0.937500    0.958333    'LavenderBlush';
1.000000    0.890625    0.878906    'MistyRose';
0.500000    0.500000    0.500000    'Gray';
0.859375    0.859375    0.859375    'Gainsboro';
0.824219    0.824219    0.824219    'LightGray';
0.750000    0.750000    0.750000    'Silver';
0.660156    0.660156    0.660156    'DarkGray';
0.410156    0.410156    0.410156    'DimGray';
0.464844    0.531250    0.597656    'LightSlateGray';
0.437500    0.500000    0.562500    'SlateGray';
0.183594    0.308594    0.308594    'DarkSlateGray';
0.000000    0.000000    0.000000    'Black';
1.000000    0.000000    0.000000    'Red';
1.000000    0.625000    0.476562    'LightSalmon';
0.979167    0.500000    0.445312    'Salmon';
0.910156    0.585938    0.476562    'DarkSalmon';
0.937500    0.500000    0.500000    'LightCoral';
0.800781    0.359375    0.359375    'IndianRed';
0.859375    0.078125    0.234375    'Crimson';
0.695312    0.132812    0.132812    'FireBrick';
0.542969    0.000000    0.000000    'DarkRed';
1.000000    0.750000    0.792969    'Pink';
1.000000    0.710938    0.753906    'LightPink';
1.000000    0.410156    0.703125    'HotPink';
1.000000    0.078125    0.574219    'DeepPink';
0.855469    0.437500    0.574219    'PaleVioletRed';
0.777344    0.082031    0.519531    'MediumVioletRed';
1.000000    0.644531    0.000000    'Orange';
1.000000    0.546875    0.000000    'DarkOrange';
1.000000    0.496094    0.312500    'Coral';
1.000000    0.386719    0.277344    'Tomato';
1.000000    0.269531    0.000000    'OrangeRed';
1.000000    1.000000    0.000000    'Yellow';
1.000000    1.000000    0.875000    'LightYellow';
1.000000    0.979167    0.800781    'LemonChiffon';
0.979167    0.979167    0.820312    'LightGoldenrodYellow';
1.000000    0.933594    0.832031    'PapayaWhip';
1.000000    0.890625    0.707031    'Moccasin';
1.000000    0.851562    0.722656    'PeachPuff';
0.929688    0.906250    0.664062    'PaleGoldenrod';
0.937500    0.898438    0.546875    'Khaki';
0.738281    0.714844    0.417969    'DarkKhaki';
1.000000    0.839844    0.000000    'Gold';
0.644531    0.164062    0.164062    'Brown';
1.000000    0.970833    0.859375    'Cornsilk';
1.000000    0.917969    0.800781    'BlanchedAlmond';
1.000000    0.890625    0.765625    'Bisque';
1.000000    0.867188    0.675781    'NavajoWhite';
0.958333    0.867188    0.699219    'Wheat';
0.867188    0.718750    0.527344    'BurlyWood';
0.820312    0.703125    0.546875    'Tan';
0.734375    0.558594    0.558594    'RosyBrown';
0.954167    0.640625    0.375000    'SandyBrown';
0.851562    0.644531    0.125000    'Goldenrod';
0.718750    0.523438    0.042969    'DarkGoldenrod';
0.800781    0.519531    0.246094    'Peru';
0.820312    0.410156    0.117188    'Chocolate';
0.542969    0.269531    0.074219    'SaddleBrown';
0.625000    0.320312    0.175781    'Sienna';
0.500000    0.000000    0.000000    'Maroon';
0.000000    0.500000    0.000000    'Green';
0.593750    0.983333    0.593750    'PaleGreen';
0.562500    0.929688    0.562500    'LightGreen';
0.601562    0.800781    0.195312    'YellowGreen';
0.675781    1.000000    0.183594    'GreenYellow';
0.496094    1.000000    0.000000    'Chartreuse';
0.484375    0.987500    0.000000    'LawnGreen';
0.000000    1.000000    0.000000    'Lime';
0.195312    0.800781    0.195312    'LimeGreen';
0.000000    0.979167    0.601562    'MediumSpringGreen';
0.000000    1.000000    0.496094    'SpringGreen';
0.398438    0.800781    0.664062    'MediumAquamarine';
0.496094    1.000000    0.828125    'Aquamarine';
0.125000    0.695312    0.664062    'LightSeaGreen';
0.234375    0.699219    0.441406    'MediumSeaGreen';
0.179688    0.542969    0.339844    'SeaGreen';
0.558594    0.734375    0.558594    'DarkSeaGreen';
0.132812    0.542969    0.132812    'ForestGreen';
0.000000    0.390625    0.000000    'DarkGreen';
0.417969    0.554688    0.136719    'OliveDrab';
0.500000    0.500000    0.000000    'Olive';
0.332031    0.417969    0.183594    'DarkOliveGreen';
0.000000    0.500000    0.500000    'Teal';
0.000000    0.000000    1.000000    'Blue';
0.675781    0.843750    0.898438    'LightBlue';
0.687500    0.875000    0.898438    'PowderBlue';
0.683594    0.929688    0.929688    'PaleTurquoise';
0.250000    0.875000    0.812500    'Turquoise';
0.281250    0.816406    0.796875    'MediumTurquoise';
0.000000    0.804688    0.816406    'DarkTurquoise';
0.875000    1.000000    1.000000    'LightCyan';
0.000000    1.000000    1.000000    'Cyan';
0.000000    1.000000    1.000000    'Aqua';
0.000000    0.542969    0.542969    'DarkCyan';
0.371094    0.617188    0.625000    'CadetBlue';
0.687500    0.765625    0.867188    'LightSteelBlue';
0.273438    0.507812    0.703125    'SteelBlue';
0.527344    0.804688    0.979167    'LightSkyBlue';
0.527344    0.804688    0.917969    'SkyBlue';
0.000000    0.746094    1.000000    'DeepSkyBlue';
0.117188    0.562500    1.000000    'DodgerBlue';
0.390625    0.582031    0.925781    'CornflowerBlue';
0.253906    0.410156    0.878906    'RoyalBlue';
0.000000    0.000000    0.800781    'MediumBlue';
0.000000    0.000000    0.542969    'DarkBlue';
0.000000    0.000000    0.500000    'Navy';
0.097656    0.097656    0.437500    'MidnightBlue';
0.500000    0.000000    0.500000    'Purple';
0.898438    0.898438    0.979167    'Lavender';
0.843750    0.746094    0.843750    'Thistle';
0.863281    0.625000    0.863281    'Plum';
0.929688    0.507812    0.929688    'Violet';
0.851562    0.437500    0.835938    'Orchid';
1.000000    0.000000    1.000000    'Fuchsia';
1.000000    0.000000    1.000000    'Magenta';
0.726562    0.332031    0.824219    'MediumOrchid';
0.574219    0.437500    0.855469    'MediumPurple';
0.597656    0.398438    0.796875    'Amethyst';
0.539062    0.167969    0.882812    'BlueViolet';
0.578125    0.000000    0.824219    'DarkViolet';
0.597656    0.195312    0.796875    'DarkOrchid';
0.542969    0.000000    0.542969    'DarkMagenta';
0.414062    0.351562    0.800781    'SlateBlue';
0.281250    0.238281    0.542969    'DarkSlateBlue';
0.480469    0.406250    0.929688    'MediumSlateBlue';
0.292969    0.000000    0.507812    'Indigo';
0.500000    0.500000    0.500000    'Grey';
0.824219    0.824219    0.824219    'LightGrey';
0.660156    0.660156    0.660156    'DarkGrey';
0.410156    0.410156    0.410156    'DimGrey';
0.464844    0.531250    0.597656    'LightSlateGrey';
0.437500    0.500000    0.562500    'SlateGrey';
0.183594    0.308594    0.308594    'DarkSlateGrey';
%----------------------------
 
};
 
 
 
% Extract names from rightmost column of colors cell array:
names= colors(:,4);
 
% Strip off rightmost column of colors cell array and convert remaining
% columns to a matrix:
RGBs= cell2num(colors(:,1:3));
 
 
% Section 2: Convert index_or_name to an RGB triple.
 
if nargin ~= 1
   error('This function must be called with exactly one argument.');
end
 
 
%----------------------modifed to show the chart map ------------
% source http://www.mathworks.com/matlabcentral/fileexchange/24497-rgb-triple-of-color-name--version-2/content//rgb.m
if strcmpi( index_or_name, 'chart')
num = colors(22:end,1:3); name = colors(22:end,4); % [1 21] not shown in chart
  grp = {'White', 'Gray', 'Red', 'Pink', 'Orange', 'Yellow', 'Brown'...
    , 'Green', 'Blue', 'Purple', 'Grey'};
  J = [1,3,6,8,9,10,11];
  fl = lower(grp);
  nl = name;
  for i=1:length(grp)
      disp(i);
    n(i) = find( strcmpi(nl, fl{i})); %#ok<AGROW> % modified by xuchun
    % n(i) = strmatch(fl{i}, nl, 'exact'); % old code
  end
  figure; %chun modifed  % clf
  p = get(0,'screensize');
  wh = 0.6*p(3:4);
  xy0 = p(1:2)+0.5*p(3:4) - wh/2;
  set(gcf,'position', [xy0 wh]);
  axes('position', [0 0 1 1], 'visible', 'off');
  hold on
  x = 0;
  N = 0;
  for i=1:length(J)-1
    N = max(N, n(J(i+1)) - n(J(i)) + (J(i+1) - J(i))*1.3); 
  end
  h = 1/N;
  w = 1/(length(J)-1);
  d = w/30;
  for col = 1:length(J)-1;
    y = 1 - h;
    for i=J(col):J(col+1)-1
      t = text(x+w/2, y+h/10 , [grp{i} ' colors']);
      set(t, 'fontw', 'bold', 'vert','bot', 'horiz','cent', 'fontsize',10);
      y = y - h;
      for k = n(i):n(i+1)-1
        c = cell2mat( num(k,1:3));  % modified by Chun % c = num(k,:);
        bright = (c(1)+2*c(2)+c(3))/4;
        if bright < 0.5, txtcolor = 'w'; else txtcolor = 'k'; end
        rectangle('position',[x+d,y,w-2*d,h],'facecolor',c);
        t = text(x+w/2, y+h/2, name{k}, 'color', txtcolor);
        set(t, 'vert', 'mid', 'horiz', 'cent', 'fontsize', 9);
        y = y - h;
      end
      y = y - 0.3*h;
    end
    x = x + w;
  end
  return;
end  
%---------------------
 
 
if isnumeric(index_or_name)
   index= index_or_name;
 
 
   if length(index)==3 & all(index>=0) %#ok<AND2>
 
      % If contents of index_or_name are an RGB triple with elements in
      % [0,1], return them as output without modification:
 
      if all(index<=1)
         RGB= index;
         return
      end
 
      % If contents of index_or_name are an RGB triple with elements in
      % [0,255], scale by 1/255 and return as output:
 
      if all(index<=255)
         RGB= index/255;
         return
      end
 
   end
 
   if length(index) > 1
      error('When calling with a color index, specify a single number.');
   end
   if ismember(index,1:21)
      RGB= RGBs(index,:);
      return
   end
   error('A color index must be a whole number between 1 and 21.');
end
 
if isa(index_or_name,'char')
   index= lookup(names,index_or_name);
   if index
      RGB= RGBs(index,:);
   else
      fprintf(2, ['Warning: Unknown color name "%s".  ' ...
        'Substituting black.\n'], index_or_name);
      RGB= [0 0 0];
   end
   return
end
 
error('Input argument has unexpected data type.');
 
end
 
function n= lookup(c, str)
%
% OVERVIEW
%
% lookup(c, str) compares the string in str against each element of the
% cell array c in turn.  If str is found in any element of c, the index of
% the first such element is returned.  Otherwise, the value zero is
% returned.
%
% INPUTS
%
% c: A one-dimensional cell-array.  Each element of this cell array is
% either a character string, or another one-dimensional cell-array
% containing character strings.  Note: Deeper nesting of cell arrays is not
% supported.
%
% EXAMPLES
%
% All three of the following function calls return the value 2:
 
% lookup({'cat','dog','fish'},'dog')
% lookup({{'c','cat'},{'d','dog'},'fish'},'dog')
% lookup({{'c','cat'},{'d','dog'},'fish'},'d')
%
% Dr. Phillip M. Feldman
% 3 June 2008
 
if (nargin ~= 2)
   error('This function requires exactly two calling arguments.');
end
if (~iscell(c))
   error('The first calling argument must be a cell array.');
end
if (~isa(str,'char'))
   error('The second calling argument must be a character string.');
end
 
for i= 1 : length(c)
   ndx(i,1)= any(strcmpi(c{i},str)); %#ok<AGROW>
end
 
n= find(ndx, 1, 'first');
 
% We can't return an empty matrix, so convert an empty matrix to a zero:
 
if (isempty(n)), n= 0; end
 
end
 
 
 
function [output]= cell2num(inputcell)
%
% This function converts a cell array to a double precision array.
%
% Usage: output= cell2num(inputcellarray)
%
% The output array will have the same dimensions as the input cell array.
% Non-numeric cell contents will be converted to NaNs in output.
%
% Written by Nishaat Vasi, Application Support Engineer, The MathWorks
 
if ~iscell(inputcell)
   error('Input must be a cell array.');
end
 
output= cellfun(@cellcheck, inputcell);
 
function y= cellcheck(x)
 
if isnumeric(x) && numel(x) == 1
    y= x;
else
    y= NaN;
end
 
end % embedded function cellcheck
 
end % function cell2num
 
 
 
 
 
 

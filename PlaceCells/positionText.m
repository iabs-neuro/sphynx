function coord_text = positionText(gca, x_percent, y_percent)

xLimits = get(gca, 'XLim'); % Границы оси X
yLimits = get(gca, 'YLim'); % Границы оси Y

coord_text = [xLimits(1) + x_percent*(xLimits(2)-xLimits(1)), yLimits(1) + y_percent*(yLimits(2)-yLimits(1))];

end
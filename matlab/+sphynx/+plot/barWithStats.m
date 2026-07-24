function barWithStats(ax, L, factor1, factor2, statsRes, style)
% BARWITHSTATS  Render a Prism-style bar chart (mean +- error, individual
% dots overlay) into the given axes, optionally annotated with pairwise
% significance stars.
%
%   sphynx.plot.barWithStats(ax, L, factor1, factor2, statsRes, style)
%
%   Input:
%     ax       - target axes (uiaxes or axes handle).
%     L        - long table with columns subject, session, <factors...>, value.
%     factor1  - char, primary factor (X groups).
%     factor2  - char or '' for one-way layout.
%     statsRes - struct from sphynx.stats.runTest (may be []).
%     style    - struct with fields (all optional):
%                  errorbar: 'SEM' (default) | 'SD' | '95CI' | 'none'
%                  showPoints: true (default)
%                  showStars: true (default)
%                  fontName: 'Arial'
%                  fontSize: 11
%                  titleFontSize: 13
%                  axisFontSize: 11
%                  barEdgeColor: [0 0 0]
%                  colormap: 'parula'
%                  title: ''

    if nargin < 6; style = struct(); end
    style = defaultStyle(style);

    cla(ax);
    hold(ax, 'on');

    % Coerce factor columns to cellstr for grouping.
    if ~iscell(L.(factor1)); L.(factor1) = cellstr(string(L.(factor1))); end
    levels1 = uniqueStable(L.(factor1));
    n1 = numel(levels1);

    if ~isempty(factor2) && any(strcmp(L.Properties.VariableNames, factor2))
        if ~iscell(L.(factor2)); L.(factor2) = cellstr(string(L.(factor2))); end
        levels2 = uniqueStable(L.(factor2));
    else
        factor2 = '';
        levels2 = {''};
    end
    n2 = numel(levels2);

    cmap = pickColormap(style.colormap, max(2, n2));

    barWidth = 0.8 / max(1, n2);
    offsets = (-((n2-1)/2):((n2-1)/2)) * barWidth;
    centers = zeros(n1, n2);
    legendHandles = gobjects(1, n2);

    for i = 1:n1
        for j = 1:n2
            mask = strcmp(L.(factor1), levels1{i});
            if ~isempty(factor2)
                mask = mask & strcmp(L.(factor2), levels2{j});
            end
            v = L.value(mask); v = v(~isnan(v));
            if isempty(v); centers(i, j) = i + offsets(j); continue; end
            m = mean(v);
            x = i + offsets(j);
            centers(i, j) = x;
            % Keep one bar handle per j for the legend; rest hidden.
            if ~isgraphics(legendHandles(j))
                hb = bar(ax, x, m, barWidth * 0.9, ...
                    'FaceColor', cmap(j, :), 'EdgeColor', style.barEdgeColor, ...
                    'LineWidth', 1.0, 'DisplayName', levels2{j});
                legendHandles(j) = hb;
            else
                bar(ax, x, m, barWidth * 0.9, ...
                    'FaceColor', cmap(j, :), 'EdgeColor', style.barEdgeColor, ...
                    'LineWidth', 1.0, 'HandleVisibility', 'off');
            end
            e = errVal(v, style.errorbar);
            if e > 0
                errorbar(ax, x, m, e, 'k', 'LineStyle', 'none', ...
                    'LineWidth', 1.0, 'CapSize', 6, 'HandleVisibility', 'off');
            end
            if style.showPoints
                jit = (rand(numel(v), 1) - 0.5) * (barWidth * 0.6);
                scatter(ax, x + jit, v, 18, [0 0 0], 'filled', ...
                    'MarkerFaceAlpha', 0.7, 'MarkerEdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            end
        end
    end

    ax.XTick = 1:n1;
    ax.XTickLabel = levels1;
    ax.TickLabelInterpreter = 'none';
    ax.XLim = [0.5 n1 + 0.5];
    ax.FontName = style.fontName;
    ax.FontSize = style.axisFontSize;
    if ~isempty(style.title)
        title(ax, style.title, 'Interpreter', 'none', ...
            'FontName', style.fontName, 'FontSize', style.titleFontSize);
    end
    if ~isempty(factor1); xlabel(ax, factor1, 'Interpreter', 'none'); end
    ylabel(ax, 'value', 'Interpreter', 'none');
    if ~isempty(factor2)
        valid = isgraphics(legendHandles);
        if any(valid)
            legend(ax, legendHandles(valid), levels2(valid), 'Location', 'best', ...
                'Interpreter', 'none', 'Box', 'off', 'FontSize', style.fontSize - 1);
        end
    end

    % --- Stars annotation ---
    if style.showStars && ~isempty(statsRes) && ~isempty(statsRes.pairwise) ...
            && height(statsRes.pairwise) > 0
        drawStars(ax, statsRes.pairwise, levels1, levels2, factor1, factor2, centers);
    end

    box(ax, 'on');
    hold(ax, 'off');
end


function style = defaultStyle(style)
    def = struct('errorbar', 'SEM', 'showPoints', true, 'showStars', true, ...
        'fontName', 'Arial', 'fontSize', 11, 'titleFontSize', 13, ...
        'axisFontSize', 11, 'barEdgeColor', [0 0 0], ...
        'colormap', 'parula', 'title', '');
    fn = fieldnames(def);
    for k = 1:numel(fn)
        if ~isfield(style, fn{k}) || isempty(style.(fn{k}))
            style.(fn{k}) = def.(fn{k});
        end
    end
end


function e = errVal(v, kind)
    switch upper(string(kind))
        case "SEM"; e = std(v) / sqrt(numel(v));
        case "SD";  e = std(v);
        case "95CI"
            if numel(v) > 1
                t = tinv(0.975, numel(v) - 1);
                e = t * std(v) / sqrt(numel(v));
            else
                e = 0;
            end
        case "NONE"; e = 0;
        otherwise;   e = std(v) / sqrt(numel(v));
    end
end


function u = uniqueStable(c)
    if ~iscell(c); c = cellstr(string(c)); end
    [~, ia] = unique(c, 'stable');
    u = c(ia);
end


function cmap = pickColormap(name, n)
    n = max(2, n);
    try
        switch lower(name)
            case 'parula';  cmap = parula(n);
            case 'jet';     cmap = jet(n);
            case 'hsv';     cmap = hsv(n);
            case 'cool';    cmap = cool(n);
            case 'hot';     cmap = hot(n);
            case 'turbo';   cmap = turbo(n);
            case 'lines';   cmap = lines(n);
            case 'gray';    cmap = gray(n);
            otherwise;      cmap = parula(n);
        end
    catch
        cmap = parula(n);
    end
end


function drawStars(ax, pw, levels1, levels2, factor1, factor2, centers)
    % pw has columns groupA, groupB, p. Group names may be plain (one-way)
    % or 'factor:level' (two-way).
    yl = ylim(ax);
    yMax = yl(2);
    yStep = (yl(2) - yl(1)) * 0.06;

    for r = 1:height(pw)
        gA = pw.groupA{r};
        gB = pw.groupB{r};
        p = pw.p(r);
        if isnan(p) || p >= 0.05; continue; end
        [xA, fA] = locateGroup(gA, levels1, levels2, factor1, factor2, centers);
        [xB, fB] = locateGroup(gB, levels1, levels2, factor1, factor2, centers);
        if isnan(xA) || isnan(xB); continue; end
        % Skip cross-factor pairs (e.g. '1D' vs 'ctrl') -- only one
        % side resolved via factor2. Keep within-factor1 (both ''),
        % within-factor2 (both non-empty), and interaction pairs
        % encoded as 'factor:level' on both sides.
        if ~isempty(factor2) && xor(isempty(fA), isempty(fB)); continue; end
        yMax = yMax + yStep;
        x = sort([xA, xB]);
        plot(ax, x, [yMax yMax], 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        plot(ax, [x(1) x(1)], [yMax - yStep*0.3, yMax], 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        plot(ax, [x(2) x(2)], [yMax - yStep*0.3, yMax], 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        text(ax, mean(x), yMax + yStep*0.2, sphynx.stats.pStars(p), ...
            'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
            'FontSize', 11, 'FontWeight','bold');
    end
    ylim(ax, [yl(1), yMax + yStep]);
end


function [x, f2lvl] = locateGroup(name, levels1, levels2, factor1, factor2, centers)
    x = NaN; f2lvl = '';
    if isempty(factor2)
        idx = find(strcmp(levels1, name), 1);
        if ~isempty(idx); x = centers(idx, 1); end
        return;
    end
    % Two-way: name may be 'factor1:level1' or 'factor2:level2' or just a level.
    if contains(name, ':')
        parts = strsplit(name, ':');
        fname = parts{1}; lvl = parts{2};
        if strcmp(fname, factor1)
            idx = find(strcmp(levels1, lvl), 1);
            if ~isempty(idx)
                % Use mean across factor2 columns (rough but ok for label)
                x = mean(centers(idx, :));
            end
            return;
        elseif strcmp(fname, factor2)
            idx = find(strcmp(levels2, lvl), 1);
            if ~isempty(idx)
                x = mean(centers(:, idx));
                f2lvl = lvl;
            end
            return;
        end
    end
    % Plain level — try factor1 first then factor2
    idx = find(strcmp(levels1, name), 1);
    if ~isempty(idx); x = mean(centers(idx, :)); return; end
    idx = find(strcmp(levels2, name), 1);
    if ~isempty(idx); x = mean(centers(:, idx)); f2lvl = name; return; end
end

classdef PreprocessVideoWindow < handle
% PREPROCESSVIDEOWINDOW  Standalone video viewer for the Preprocess tab.
%
%   sphynx.app.PreprocessVideoWindow(parentController) opens a separate
%   uifigure window with: large video axes, frame slider, step buttons,
%   play/pause/stop with a speed dropdown, color/marker settings.
%
%   The window reads frames from the parent controller's VideoReader_
%   and overlays:
%     - raw DLC points as open circles
%     - smoothed (post-Compute) points as filled circles
%   Color comes from a chosen colormap (parula/jet/hsv/hot/cool with
%   plasma/viridis/turbo fallbacks for older releases).
%
%   The window mirrors the parent controller's currentFrame: navigation
%   here updates the controller's playhead (via setCurrentFrame), so the
%   X(t) and Y(t) plots in the main tab move in sync.

    properties
        Parent          % handle to PreprocessTabController
        Figure          % standalone uifigure
        Ax              % uiaxes for the video frame
        Slider          % uislider
        FrameLabel
        SpeedDropDown
        ColormapDropDown
        MarkerSizeField
        ShowAllChk      % show all parts vs only the current
        PlayButton
        Timer           % MATLAB timer for play loop
    end

    methods
        function obj = PreprocessVideoWindow(parent)
            obj.Parent = parent;
            obj.buildUI();
            obj.refreshFrame();
        end

        function delete(obj)
            obj.stopPlay();
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                close(obj.Figure);
            end
        end

        function setCurrentFrame(obj, idx)
            if isempty(obj.Parent.State.dlc); return; end
            n = obj.Parent.State.dlc.nFrames;
            idx = max(1, min(n, round(idx)));
            obj.Parent.setCurrentFrame(idx);
            % parent's setCurrentFrame already calls refreshVideoFrame on
            % the embedded panel; we still need to refresh ours separately.
            obj.refreshFrame();
        end

        function play(obj)
            if isempty(obj.Parent.VideoReader_); return; end
            obj.stopPlay();
            speed = parseSpeed(obj.SpeedDropDown.Value);
            fps = obj.Parent.VideoReader_.FrameRate;
            period = max(0.02, 1 / (fps * speed));
            obj.Timer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', period, ...
                'TimerFcn', @(~,~) obj.tick(), ...
                'StopFcn', @(~,~) obj.onTimerStop());
            start(obj.Timer);
            obj.PlayButton.Text = 'Pause';
        end

        function stopPlay(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                try; stop(obj.Timer); catch; end
                try; delete(obj.Timer); catch; end
            end
            obj.Timer = [];
            if ~isempty(obj.PlayButton) && isvalid(obj.PlayButton)
                obj.PlayButton.Text = 'Play';
            end
        end

        function refreshFrame(obj)
            if isempty(obj.Ax) || ~isvalid(obj.Ax); return; end
            if isempty(obj.Parent.VideoReader_); return; end
            f = obj.Parent.State.currentFrame;
            try
                img = read(obj.Parent.VideoReader_, f);
            catch
                return;
            end
            cla(obj.Ax);
            imshow(img, 'Parent', obj.Ax);
            obj.overlayPoints(f);
            if isvalid(obj.Slider); obj.Slider.Value = f; end
            if isvalid(obj.FrameLabel)
                obj.FrameLabel.Text = sprintf('Frame %d / %d', f, ...
                    obj.Parent.State.dlc.nFrames);
            end
        end
    end

    methods (Access = private)
        function buildUI(obj)
            obj.Figure = uifigure('Name', 'Preprocess Video', ...
                'Position', [100 80 900 720]);
            g = uigridlayout(obj.Figure, [3, 1]);
            g.RowHeight = {'1x', 36, 36};
            g.Padding = [6 6 6 6];
            g.RowSpacing = 6;

            obj.Ax = uiaxes(g);
            obj.Ax.Layout.Row = 1;
            obj.Ax.XTick = []; obj.Ax.YTick = [];
            obj.Ax.Box = 'on';

            % Row 2: navigation
            nav = uigridlayout(g, [1, 8]);
            nav.Layout.Row = 2;
            nav.RowHeight = {30};
            nav.ColumnWidth = {30, 30, '1x', 30, 30, 70, 50, 90};
            nav.Padding = [0 0 0 0];
            nav.ColumnSpacing = 4;

            uibutton(nav, 'Text', '<<', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.Parent.State.currentFrame - 10));
            uibutton(nav, 'Text', '<', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.Parent.State.currentFrame - 1));

            n = 1; if ~isempty(obj.Parent.State.dlc); n = obj.Parent.State.dlc.nFrames; end
            obj.Slider = uislider(nav, 'Limits', [1 max(2, n)], ...
                'Value', max(1, obj.Parent.State.currentFrame), ...
                'ValueChangedFcn', @(s, ~) obj.setCurrentFrame(round(s.Value)));

            uibutton(nav, 'Text', '>', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.Parent.State.currentFrame + 1));
            uibutton(nav, 'Text', '>>', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.setCurrentFrame(obj.Parent.State.currentFrame + 10));
            obj.PlayButton = uibutton(nav, 'Text', 'Play', ...
                'BackgroundColor', semanticColor('info'), ...
                'ButtonPushedFcn', @(~,~) obj.togglePlay());
            uibutton(nav, 'Text', 'Stop', 'BackgroundColor', semanticColor('action'), ...
                'ButtonPushedFcn', @(~,~) obj.stopPlay());
            obj.FrameLabel = uilabel(nav, 'Text', 'Frame -/-', ...
                'HorizontalAlignment', 'right');

            % Row 3: settings
            settings = uigridlayout(g, [1, 7]);
            settings.Layout.Row = 3;
            settings.RowHeight = {30};
            settings.ColumnWidth = {60, 100, 60, 60, 80, 70, '1x'};
            settings.Padding = [0 0 0 0];
            settings.ColumnSpacing = 4;

            uilabel(settings, 'Text', 'speed:');
            obj.SpeedDropDown = uidropdown(settings, ...
                'Items', {'0.25x', '0.5x', '1x', '2x', '4x'}, 'Value', '1x', ...
                'ValueChangedFcn', @(~,~) obj.onSpeedChanged());

            uilabel(settings, 'Text', 'colors:');
            obj.ColormapDropDown = uidropdown(settings, ...
                'Items', {'parula', 'jet', 'hsv', 'hot', 'cool', 'plasma', 'viridis', 'turbo'}, ...
                'Value', 'parula', ...
                'ValueChangedFcn', @(~,~) obj.refreshFrame());

            uilabel(settings, 'Text', 'marker:');
            obj.MarkerSizeField = uieditfield(settings, 'numeric', ...
                'Value', 8, 'Limits', [1 50], 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~,~) obj.refreshFrame());

            obj.ShowAllChk = uicheckbox(settings, 'Text', 'show all parts', ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~) obj.refreshFrame());
        end

        function togglePlay(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                obj.stopPlay();
            else
                obj.play();
            end
        end

        function onSpeedChanged(obj)
            wasPlaying = ~isempty(obj.Timer) && isvalid(obj.Timer);
            obj.stopPlay();
            if wasPlaying; obj.play(); end
        end

        function onTimerStop(obj)
            obj.PlayButton.Text = 'Play';
        end

        function tick(obj)
            if isempty(obj.Parent.State.dlc); return; end
            n = obj.Parent.State.dlc.nFrames;
            next = obj.Parent.State.currentFrame + 1;
            if next > n
                obj.stopPlay();
                return;
            end
            obj.setCurrentFrame(next);
        end

        function overlayPoints(obj, f)
            if isempty(obj.Parent.State.dlc); return; end
            dlc = obj.Parent.State.dlc;
            nParts = numel(dlc.bodyPartsNames);
            cmap = pickColormap(obj.ColormapDropDown.Value, nParts);
            sz = obj.MarkerSizeField.Value;
            showAll = obj.ShowAllChk.Value;
            cur = obj.Parent.State.currentBodyPart;

            hold(obj.Ax, 'on');
            for i = 1:nParts
                if ~showAll && i ~= cur; continue; end
                col = cmap(i, :);
                rx = dlc.X(i, f); ry = dlc.Y(i, f);
                if isfinite(rx) && isfinite(ry)
                    plot(obj.Ax, rx, ry, 'o', ...
                        'MarkerSize', sz, ...
                        'MarkerEdgeColor', col, 'MarkerFaceColor', 'none', ...
                        'LineWidth', 1.5);
                end
                % Smoothed point if computed
                if i <= numel(obj.Parent.State.processed) && ...
                        ~isempty(obj.Parent.State.processed(i).status) && ...
                        strcmp(obj.Parent.State.processed(i).status, 'Good')
                    p = obj.Parent.State.processed(i);
                    sx = p.X_smooth(f); sy = p.Y_smooth(f);
                    if isfinite(sx) && isfinite(sy)
                        plot(obj.Ax, sx, sy, 'o', ...
                            'MarkerSize', max(2, sz - 2), ...
                            'MarkerEdgeColor', col, 'MarkerFaceColor', col);
                    end
                end
            end
            hold(obj.Ax, 'off');
        end
    end
end

% --- Local helpers ---------------------------------------------------------

function rgb = semanticColor(kind)
    switch kind
        case 'action';   rgb = [1.00 0.85 0.85];
        case 'geometry'; rgb = [1.00 0.96 0.78];
        case 'info';     rgb = [0.78 0.95 0.95];
        otherwise;       rgb = [0.94 0.94 0.94];
    end
end

function cmap = pickColormap(name, n)
    n = max(2, n);
    try
        switch lower(name)
            case 'parula';  cmap = parula(n);
            case 'jet';     cmap = jet(n);
            case 'hsv';     cmap = hsv(n);
            case 'hot';     cmap = hot(n);
            case 'cool';    cmap = cool(n);
            case 'plasma';  cmap = tryColormap('plasma', n);
            case 'viridis'; cmap = tryColormap('viridis', n);
            case 'turbo';   cmap = tryColormap('turbo', n);
            otherwise;      cmap = parula(n);
        end
    catch
        cmap = parula(n);
    end
end

function cmap = tryColormap(name, n)
    try
        cmap = feval(name, n);   % R2020b+ has plasma/viridis/turbo
    catch
        cmap = parula(n);
    end
end

function speed = parseSpeed(label)
    switch lower(label)
        case '0.25x'; speed = 0.25;
        case '0.5x';  speed = 0.5;
        case '2x';    speed = 2;
        case '4x';    speed = 4;
        otherwise;    speed = 1;
    end
end

function v = parseSpeedNumber(s) %#ok<DEFNU>
    v = parseSpeed(s);
end

function ArenaAndObjects = adjustExistingPreset(frame, ArenaAndObjects, varargin)
% ADJUSTEXISTINGPRESET  Reposition / rotate a previously saved preset
% over a new frame using arrow keys + bracket keys.
%
%   ArenaAndObjects = sphynx.preset.adjustExistingPreset(frame, AAO)
%
%   Interactive controls (when running in MATLAB GUI):
%     arrows  : translate by current step
%     +, -    : double / halve the step
%     [, ]    : rotate by current step (degrees)
%     enter   : accept and exit (return updated AAO)
%
%   Optional name-value (for headless override — apply a single
%   transform without entering the loop, useful for tests):
%     'Translation'  [dx dy] in pixels
%     'RotationDeg'  scalar rotation around arena center
%
%   Decomposition of legacy CreatePreset.m:151-249.

    p = inputParser;
    addRequired(p, 'frame');
    addRequired(p, 'ArenaAndObjects');
    addParameter(p, 'Translation', [0 0]);
    addParameter(p, 'RotationDeg', 0);
    parse(p, frame, ArenaAndObjects, varargin{:});

    if all(p.Results.Translation == 0) && p.Results.RotationDeg == 0
        ArenaAndObjects = interactiveLoop(frame, ArenaAndObjects);
    else
        ArenaAndObjects = applyTransform(ArenaAndObjects, ...
            p.Results.Translation, p.Results.RotationDeg);
    end
end

function AAO = applyTransform(AAO, translation, rotationDeg)
    cx = mean(AAO(1).border_x);
    cy = mean(AAO(1).border_y);
    rad = deg2rad(rotationDeg);
    R = [cos(rad), -sin(rad); sin(rad), cos(rad)];
    for k = 1:numel(AAO)
        xs = AAO(k).border_x(:);
        ys = AAO(k).border_y(:);
        relx = xs - cx;
        rely = ys - cy;
        rot = R * [relx, rely]';
        AAO(k).border_x = rot(1, :)' + cx + translation(1);
        AAO(k).border_y = rot(2, :)' + cy + translation(2);
    end
end

function AAO = interactiveLoop(frame, AAO)
    step = 10;
    rotationAngle = 0;
    figure; imshow(frame); hold on;
    drawAAO(AAO);
    title(sprintf('arrows: move, +/-: step, [/]: rotate, enter: save (step=%d)', step));
    key = 0;
    while key ~= 13  % enter
        waitforbuttonpress;
        key = get(gcf, 'CurrentCharacter');
        if isempty(key); continue; end
        switch double(key)
            case 28  % left
                AAO = applyTransform(AAO, [-step 0], 0);
            case 29  % right
                AAO = applyTransform(AAO, [step 0], 0);
            case 30  % up
                AAO = applyTransform(AAO, [0 -step], 0);
            case 31  % down
                AAO = applyTransform(AAO, [0 step], 0);
            case double('-')
                step = max(round(step/2), 1);
            case double('+')
                step = step * 2;
            case double('[')
                AAO = applyTransform(AAO, [0 0], -step);
                rotationAngle = rotationAngle - step;
            case double(']')
                AAO = applyTransform(AAO, [0 0], step);
                rotationAngle = rotationAngle + step;
        end
        clf; imshow(frame); hold on;
        drawAAO(AAO);
        title(sprintf('arrows: move, +/-: step, [/]: rotate, enter: save (step=%d, angle=%d)', step, rotationAngle));
    end
end

function drawAAO(AAO)
    for k = 1:numel(AAO)
        plot(AAO(k).border_x, AAO(k).border_y, 'k', 'LineWidth', 2);
    end
end

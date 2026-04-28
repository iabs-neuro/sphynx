function [refined, runs] = refineAct(line, minRunLen1, minRunLen0)
% REFINEACT  Min-length filter for a binary act line.
%
%   [refined, runs] = sphynx.acts.refineAct(line, minRunLen1, minRunLen0)
%
%   Inputs:
%     line        - 1xN logical/0-1 array indicating an act per frame
%     minRunLen1  - drop any run of consecutive 1s shorter than this
%     minRunLen0  - merge any run of 0s shorter than this between
%                   surviving 1-runs (close small gaps)
%
%   Output:
%     refined - same shape as line, refined in-place
%     runs    - struct array of surviving 1-runs:
%                 .frameIn   first frame of run
%                 .frameOut  last frame of run
%                 .duration  number of frames
%
%   Replaces functions/RefineLine.m with the same semantics on the
%   inputs we use, and a cleaner output shape (struct of runs vs the
%   legacy six-output tuple).
%
%   Algorithm:
%     1. Drop short 1-runs.
%     2. Close short 0-runs between 1-runs (but only after step 1, so
%        a kept 1-run sandwiched between dropped 1-runs doesn't get
%        glued to nothing).
%     3. Re-enumerate the surviving 1-runs.

    line = logical(line(:)');
    n = numel(line);

    % Step 1: drop short 1-runs
    refined = line;
    [in1, out1] = findRuns(refined, true);
    for k = 1:numel(in1)
        if (out1(k) - in1(k) + 1) < minRunLen1
            refined(in1(k):out1(k)) = false;
        end
    end

    % Step 2: close short 0-runs that are flanked by surviving 1s on both sides
    [in0, out0] = findRuns(refined, false);
    for k = 1:numel(in0)
        if (out0(k) - in0(k) + 1) < minRunLen0
            % Only close if the 0-run is surrounded by 1s (not at the start/end)
            if in0(k) > 1 && out0(k) < n
                if refined(in0(k)-1) && refined(out0(k)+1)
                    refined(in0(k):out0(k)) = true;
                end
            end
        end
    end

    % Step 3: enumerate surviving 1-runs
    [in1, out1] = findRuns(refined, true);
    runs = struct('frameIn', {}, 'frameOut', {}, 'duration', {});
    for k = 1:numel(in1)
        runs(k).frameIn = in1(k);
        runs(k).frameOut = out1(k);
        runs(k).duration = out1(k) - in1(k) + 1;
    end
end

function [runStarts, runEnds] = findRuns(line, value)
    transitions = diff([~value, line == value, ~value]);
    runStarts = find(transitions == 1);
    runEnds = find(transitions == -1) - 1;
end

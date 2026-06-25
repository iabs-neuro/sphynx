function tests = barnesSessionMetricsTest
% BARNESSESSIONMETRICSTEST  Coverage for the Barnes session-metrics
%   computer. Locks in: visit counters, first-checked-hole angle,
%   mean-of-checked angles, target visit order, and edge cases.
    tests = functiontests(localfunctions);
end

% --- counters ------------------------------------------------------------

function testEmptyResultReturnsZeros(testCase)
    m = sphynx.pipeline.barnesSessionMetrics(struct());
    verifyEqual(testCase, m.TotalNoseHoleVisits, 0);
    verifyEqual(testCase, m.TotalBodyHoleVisits, 0);
    verifyEqual(testCase, m.NumCheckedHoles, 0);
    verifyTrue(testCase,  isnan(m.FirstCheckedHoleErrorDeg));
    verifyTrue(testCase,  isnan(m.MeanCheckedHoleErrorDeg));
    verifyTrue(testCase,  isnan(m.TargetHoleVisitOrder));
end

function testCountsSumActNumberOverHoles(testCase)
    result = mkResult( ...
        {'nose_at_object1', 'nose_at_object3', 'nose_at_object5', 'body_at_object2'}, ...
        [3, 2, 1, 4], ...                        % ActNumber per act
        {[1 5], [10 12], [20 21], [3 7]});       % FirstStart / FirstEnd
    m = sphynx.pipeline.barnesSessionMetrics(result);
    verifyEqual(testCase, m.TotalNoseHoleVisits, 3 + 2 + 1);
    verifyEqual(testCase, m.TotalBodyHoleVisits, 4);
end

% --- angle ----------------------------------------------------------------

function testFirstCheckedHoleAngleN1Is18Deg(testCase)
    % With NumObjects=19 the angle step = 360/20 = 18 deg. object1 is
    % one slot away from target -> 18 deg of error.
    result = mkResult( ...
        {'nose_at_object1'}, [1], {[0.5, 1.0]});
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.FirstCheckedHoleNumber, 1);
    verifyEqual(testCase, m.FirstCheckedHoleErrorDeg, 18, 'AbsTol', 0.01);
end

function testFirstCheckedHoleAngleN19SymmetricBack(testCase)
    % object19: forward = 19*18 = 342, backward = 18. The metric picks
    % the shorter side -> 18 deg, same as object1.
    result = mkResult( ...
        {'nose_at_object19'}, [1], {[2.0, 2.5]});
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.FirstCheckedHoleNumber, 19);
    verifyEqual(testCase, m.FirstCheckedHoleErrorDeg, 18, 'AbsTol', 0.01);
end

function testFirstCheckedHoleAngleN10Is180Deg(testCase)
    % Opposite hole around the ring -> 180 deg.
    result = mkResult( ...
        {'nose_at_object10'}, [1], {[1.0, 1.5]});
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.FirstCheckedHoleErrorDeg, 180, 'AbsTol', 0.01);
end

function testFirstCheckedHolePicksEarliestStart(testCase)
    % object5 fired earlier than object1 in time -> object5 wins.
    result = mkResult( ...
        {'nose_at_object1', 'nose_at_object5'}, [1, 1], ...
        {[5.0, 5.5], [1.0, 1.5]});
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.FirstCheckedHoleNumber, 5);
    verifyEqual(testCase, m.FirstCheckedHoleErrorDeg, min(5*18, 360-5*18), 'AbsTol', 0.01);
end

function testMeanAngleIsArithmeticAverage(testCase)
    % Holes 1, 5, 10 visited -> angles 18, 90, 180. Mean = 96.
    result = mkResult( ...
        {'nose_at_object1', 'nose_at_object5', 'nose_at_object10'}, ...
        [1, 1, 1], ...
        {[1.0 1.5], [2.0 2.5], [3.0 3.5]});
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.NumCheckedHoles, 3);
    verifyEqual(testCase, m.MeanCheckedHoleErrorDeg, mean([18, 90, 180]), 'AbsTol', 0.01);
end

% --- target visit order --------------------------------------------------

function testTargetVisitOrderCountsEarlierEpisodes(testCase)
    % Mouse pokes object3 (twice) and object7 (once) before reaching
    % the target. Order = 3 + 1 = 4.
    % Build masks at fps=10:
    %   object3 episodes at frames 1, 10 (two separate runs)
    %   object7 episode at frame 20
    %   target  first episode at frame 40
    n = 100;
    fps = 10;
    m_o3 = false(1, n); m_o3([1, 10]) = true;       % two starts
    m_o7 = false(1, n); m_o7(20) = true;
    m_tg = false(1, n); m_tg(40:42) = true;
    Acts = struct('ActName', {}, 'ActArrayRefine', {}, 'ActNumber', {}, ...
                  'FirstStartSec', {}, 'FirstEndSec', {});
    Acts(end + 1) = mkAct('nose_at_object3', m_o3, 2, (1 - 1)/fps, (1 - 1)/fps);
    Acts(end + 1) = mkAct('nose_at_object7', m_o7, 1, (20 - 1)/fps, (20 - 1)/fps);
    Acts(end + 1) = mkAct('nose_at_target',  m_tg, 1, (40 - 1)/fps, (42 - 1)/fps);
    result.Acts = Acts;
    result.Options = struct('FrameRate', fps);
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.TargetHoleVisitOrder, 4);
end

function testTargetVisitOrderIs1WhenNoEarlierHole(testCase)
    n = 50;
    fps = 10;
    m_tg = false(1, n); m_tg(5:10) = true;
    Acts = struct('ActName', {}, 'ActArrayRefine', {}, 'ActNumber', {}, ...
                  'FirstStartSec', {}, 'FirstEndSec', {});
    Acts(end + 1) = mkAct('nose_at_target', m_tg, 1, (5 - 1)/fps, (10 - 1)/fps);
    result.Acts = Acts;
    result.Options = struct('FrameRate', fps);
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyEqual(testCase, m.TargetHoleVisitOrder, 1);
end

function testTargetVisitOrderNaNWhenNoTarget(testCase)
    n = 50;
    fps = 10;
    m_o5 = false(1, n); m_o5(10) = true;
    Acts = struct('ActName', {}, 'ActArrayRefine', {}, 'ActNumber', {}, ...
                  'FirstStartSec', {}, 'FirstEndSec', {});
    Acts(end + 1) = mkAct('nose_at_object5', m_o5, 1, (10 - 1)/fps, (10 - 1)/fps);
    result.Acts = Acts;
    result.Options = struct('FrameRate', fps);
    m = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19);
    verifyTrue(testCase, isnan(m.TargetHoleVisitOrder));
end

% --- helpers -------------------------------------------------------------

function result = mkResult(names, actNumbers, firstTimes)
    % Synthetic result with only the columns barnesSessionMetrics
    % reads (no ActArrayRefine needed except for the
    % TargetHoleVisitOrder tests, which build their own Acts).
    Acts = struct('ActName', {}, 'ActNumber', {}, ...
                  'FirstStartSec', {}, 'FirstEndSec', {}, ...
                  'ActArrayRefine', {});
    for k = 1:numel(names)
        a.ActName        = names{k};
        a.ActNumber      = actNumbers(k);
        a.FirstStartSec  = firstTimes{k}(1);
        a.FirstEndSec    = firstTimes{k}(2);
        a.ActArrayRefine = [];
        Acts(end + 1) = a; %#ok<AGROW>
    end
    result.Acts = Acts;
    result.Options = struct('FrameRate', 30);
end

function a = mkAct(name, mask, num, startSec, endSec)
    a.ActName        = name;
    a.ActArrayRefine = mask;
    a.ActNumber      = num;
    a.FirstStartSec  = startSec;
    a.FirstEndSec    = endSec;
end

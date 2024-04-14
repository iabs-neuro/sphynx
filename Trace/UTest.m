function [CellStatus] =  UTest(BaseLine, TargetLine, p_value)
% 19.02.24 vvp
% Calculation of UTest

% ToDo: reshapes vectors if they columns

%% for test data
% BaseLine = randn(100, 1);  
% TargetLine = randn(120, 1)+0.2;  

% U-тест
[p_v, CellStatus, ~] = ranksum(BaseLine, TargetLine);

if p_v > p_value
    CellStatus = false;
end

% output results
% disp(['p-value: ', num2str(p_value)]);
% disp(['Hypothesis test result (H): ', num2str(CellStatus)]);
% disp(['Test statistics (stats): ', num2str(stats.zval)]);

end

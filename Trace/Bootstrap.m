function [CellStatus, CellZscore, CellDiffMean, CellDiffMeanNorm] =  Bootstrap(BaseLine, TargetLine, NumIter, SigmaValue, DiffValue, DiffNormValue)
% 17.02.24 vvp
% Calculation mean difference between BaseLine and TargetLine and
% calculation of p-value of difference significant by bootstrap analysis
% ToDo: reshapes vectors if they columns

%% for test
% BaseLine = rand(1,20);
% TargetLine = rand(1,20).*5+rand(1,20).*3;
% BaseLine = BaseLineThis.Cell(:,cell)';
% TargetLine = FeatureThis.Cell(:,cell)';
% NumIter = 1000;
% SigmaValue = 2;

BaseLineNum = length(BaseLine);
CombineLine = [BaseLine TargetLine];

% 1st row for diff in means
% 2nd row for std1
% 3th row for std2
CellStat = zeros(3,NumIter+1);

FakeLine = CombineLine;
for iter = 1:NumIter+1
    CellStat(1,iter) = mean(FakeLine(BaseLineNum+1:end)) - mean(FakeLine(1:BaseLineNum));
    CellStat(2,iter) = std(FakeLine(BaseLineNum+1:end));
    CellStat(3,iter) = std(FakeLine(1:BaseLineNum));
    FakeLine = CombineLine(randperm(length(CombineLine)));
end

[~,MU,SIGMA] = zscore(CellStat(1, 2:end));

% difference
CellDiffMean = CellStat(1,1);

% difference normalized on sigma
CellDiffMeanNorm = CellStat(1,1)/(sqrt(0.5*(CellStat(2,1)^2 + CellStat(3,1)^2)));

CellZscore = (CellDiffMean-MU)/SIGMA;

if (CellDiffMean > MU + SigmaValue*SIGMA) && (CellDiffMeanNorm > DiffValue) && (CellDiffMean > DiffNormValue)
    CellStatus = true;
else
    CellStatus = false;
end

% % for test
% disp(CellStatus);
% disp(CellZscore);
% disp(CellDiffMean);
% disp(CellDiffMeanNorm);
end
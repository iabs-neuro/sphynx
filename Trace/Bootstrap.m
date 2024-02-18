function [CellStatus, CellZscore] =  Bootstrap(BaseLine, TargetLine, NumIter, SigmaValue)
% 17.02.24 vvp
% Calculation mean difference between BaseLine and TargetLine and
% calculation of p-value of difference significant by bootstrap analysis
% ToDo: reshapes vectors if they columns

%% for test
% BaseLine = rand(1,20);
% TargetLine = rand(1,20).*1;
% BaseLine = BaseLineThis.Cell(:,cell)';
% TargetLine = FeatureThis.Cell(:,cell)';
% NumIter = 1000;
% SigmaValue = 2;

BaseLineNum = length(BaseLine);

CombineLine = [BaseLine TargetLine];
CellStat = zeros(1,NumIter+1);

FakeLine = CombineLine;
for iter = 1:NumIter+1
    CellStat(iter) = mean(FakeLine(BaseLineNum+1:end)) - mean(FakeLine(1:BaseLineNum));
    FakeLine = CombineLine(randperm(length(CombineLine)));
end

[~,MU,SIGMA] = zscore(CellStat(2:end));
CellZscore = (CellStat(1)-MU)/SIGMA;

if CellStat(1) > MU + SigmaValue*SIGMA
    CellStatus = true;
else
    CellStatus = false;
end   

end
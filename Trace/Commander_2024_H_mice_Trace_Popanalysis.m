
root = 'f:\_Projects\_2024_Trace\';
NumIter = 1000;
SigmaValue = 3;
p_value = 0.01;
DiffTrhreshold = 1;
ShockPeriod = 6; % in seconds
BaseLinePeriod = 20; % in seconds
NormWay = 'MADscore'; % {'none' raw signal} {'norm' on interval [0,1]} {'zscore'} {'MADscore'}

PathOut = sprintf('%sPopAnalysis\\',root);
PathPlot = sprintf('%sFigures\\',root);
%% loading ready data

% PathTraceData = sprintf('%sPopAnalysis\\TraceDataAllGroups.mat',root);
% load(PathTraceData);

PathTraceSpecData = sprintf('%sPopAnalysis\\NeuronSpecData_3sigma.mat',root);
load(PathTraceSpecData);

%% creation struct for synchronized traces and features

PathFeatures = sprintf('%sFeatures\\',root);
PathTraces = sprintf('%sTraces\\',root);

Tr1D_G00 = {'H02_1D','H10_1D','H11_1D','H14_1D'};
Tr1D_G20 = {'H03_1D','H15_1D','H16_1D','H19_1D'};
Tr1D_G60 = {'H04_1D','H05_1D','H13_1D','H23_1D'};

Tr2D_G00 = {'H02_2D','H10_2D','H11_2D','H14_2D'};
Tr2D_G20 = {'H03_2D','H15_2D','H16_2D','H19_2D'};
Tr2D_G60 = {'H04_2D','H05_2D','H13_2D','H23_2D'};

Groups = {Tr1D_G00,Tr1D_G20,Tr1D_G60,Tr2D_G00,Tr2D_G20,Tr2D_G60};
GroupsNames = {'Tr1D_G00','Tr1D_G20','Tr1D_G60','Tr2D_G00','Tr2D_G20','Tr2D_G60'};

TraceData = struct('GroupName', [],'FileName', [], 'Features', [], 'NeuronData', [], 'NeuronDataNorm', [], 'NeuronInd', [], 'NeuronNum', []);

for group = 1:length(Groups)
    
    TraceData(group).GroupName = GroupsNames{group};
    TraceData(group).FileName = Groups{group};
    
    for file = 1:length(Groups{group})
        
        fprintf('Processing of %s mouse\n',Groups{group}{file});
        
        % loading trace data
        TracesTable = readtable(sprintf('%sTrace_%s_traces.csv', PathTraces,Groups{group}{file}));
        TraceThis = table2array(TracesTable(2:end,2:end));
        
        % loading features data        
        FeaturesTable = readtable(sprintf('%s%s_Features.csv', PathFeatures,Groups{group}{file}));
        FeaturesThis = table2array(FeaturesTable);        
        FeaturesHeaders = FeaturesTable.Properties.VariableNames;
        
        % getting fps and binarization
        FPSTraces = GetFPS(TraceThis(:,1));
        FPSFeatures = GetFPS(FeaturesThis(:,1));
        
        fprintf('Calcium data\n');
        [TraceThisBinned] = BinarizationArrayMany(TraceThis, FPSTraces);
        fprintf('Behavior data\n');
        [FeaturesThisBinned] = BinarizationArrayMany(FeaturesThis, FPSFeatures);        
        
        % saving DataStruct
        TraceData(group).NeuronData = [TraceData(group).NeuronData TraceThisBinned];                
        TraceData(group).Features = array2table(FeaturesThisBinned, 'VariableNames', FeaturesHeaders);        
        TraceData(group).NeuronInd = [TraceData(group).NeuronInd size(TraceThisBinned,2)];
        
    end
    TraceData(group).NeuronNum = size(TraceData(group).NeuronData,2);
end
%%
save(sprintf('%sTraceDataAllGroups.mat',PathOut));

%% recalculation shock period to 6 seconds

ShockTime = 2; % in seconds
for group=1:3
    ShockFrame = find(table2array(TraceData(group).Features(:,4)) == 1);
    disp(ShockFrame);
    for frame = ShockTime:ShockTime:length(ShockFrame)
        TraceData(group).Features(ShockFrame(frame)+1:ShockFrame(frame)+ShockPeriod-ShockTime,4) = array2table(1);
    end
end
save(sprintf('%sTraceDataAllGroups.mat',PathOut));

%% recalculation baseline period 


BaseLineTime = 2; % in seconds
for group = 1:size(TraceData,2)
    for trial = 1:7
        BaseLineThisIndex = find(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineFrames = find(table2array(TraceData(group).Features(:,BaseLineThisIndex)) == 1);
        
        for frame = 1:BaseLinePeriod
            TraceData(group).Features(ShockFrame(frame)+1:ShockFrame(frame)+ShockPeriod-ShockTime,4) = array2table(1);
        end
end
save(sprintf('%sTraceDataAllGroups.mat',PathOut));

%% scaling of Neuron data 

for group = 1:size(TraceData,2)
    fprintf('Normalization for %d group started\n',group);
    NeuronDataNorm = zeros(size(TraceData(group).NeuronData,1),size(TraceData(group).NeuronData,2));
    switch NormWay
        case 'none'
            NeuronDataNorm = TraceData(group).NeuronData;
        case 'zscore'
            for cell = 1:TraceData(group).NeuronNum
                NeuronDataNorm(:,cell) = zscore(TraceData(group).NeuronData(:,cell));
            end
        case 'norm'
            % ToDO: to do but for what
        case 'MADscore'
            for cell = 1:TraceData(group).NeuronNum
                MedianNeuro = median(TraceData(group).NeuronData(:,cell));
                MadNeuro = mad(TraceData(group).NeuronData(:,cell));
                NeuronDataNorm(:,cell) = (TraceData(group).NeuronData(:,cell)-MedianNeuro)./MadNeuro;
            end
    end
    TraceData(group).NeuronDataNorm = NeuronDataNorm;
end
save(sprintf('%sTraceDataAllGroupsNormMADscore.mat',PathOut));


%% searching spesializations of neurons
ZscoreData = [];
CellDiffData = [];
FeatureList = {'sound','trace1','trace2','trace3'};
for group = 1:size(TraceData,2)
    
    fprintf('Analysis of %s group started\n',TraceData(group).GroupName);
    
    NeuronSpecData = struct('Trial',[],'Feature',[],'NeuronSpecNum',[],'NeuronSpecInd',[],'NeuronSpecZscore',[],'BaseLineData',[],'NeuronSpecData',[], 'NeuronDiff', []);
    
    Giter = 1;
    for trial = 1:7
        fprintf('Analysis of %d trial started\n',trial);
        
        % create a mask for baselineN
        BaseLineThis.Name = sprintf('baseline%d',trial);
        BaseLineThis.Index = find(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineThis.Line = table2array(TraceData(group).Features(:,BaseLineThis.Index));
        BaseLineThis.Cell = zeros(sum(BaseLineThis.Line),size(TraceData(group).NeuronDataNorm,2));
        
        for feature = 1:length(FeatureList)
            
            switch feature
                case 1
                    FeatureThis.Name = sprintf('%s%d',FeatureList{feature} ,trial);
                    FeatureThis.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d',FeatureList{feature},trial)));
                case {2,3,4}
                    FeatureThis.Name = sprintf('%s%d%s',FeatureList{feature}(1:end-1),trial,FeatureList{feature}(end));
                    FeatureThis.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d%s',FeatureList{feature}(1:end-1),trial,FeatureList{feature}(end))));
            end
            
            FeatureThis.Line = table2array(TraceData(group).Features(:,FeatureThis.Index));
            FeatureThis.Cell = zeros(sum(FeatureThis.Line),size(TraceData(group).NeuronDataNorm,2));
            NeuronSpecData(Giter).NeuronSpecNum = 0;
            if sum(FeatureThis.Line) ~= 0
                for cell = 1:TraceData(group).NeuronNum
                    
                    FeatureThis.Cell(:,cell) = TraceData(group).NeuronDataNorm(FeatureThis.Line.*TraceData(group).NeuronDataNorm(:,cell)~=0,cell);
                    
                    BaseLineThis.Cell(:,cell) = TraceData(group).NeuronDataNorm(BaseLineThis.Line.*TraceData(group).NeuronDataNorm(:,cell)~=0,cell);
                    
                    % Calculate specialization of neuron-feature
                    [CellStatusB, CellZscoreB, CellDiff] = Bootstrap(BaseLineThis.Cell(:,cell)', FeatureThis.Cell(:,cell)', NumIter, SigmaValue);
                    
                    % u-test implementation
                    [CellStatusU] = UTest(BaseLineThis.Cell(:,cell)', FeatureThis.Cell(:,cell)',p_value);
                    % fprintf('CellStatus UTest: %d. CellStatus BTest: %d, Zscore: %2.2f\n',CellStatusU,CellStatusB,CellZscoreB);
                    
                    ZscoreData = [ZscoreData CellZscoreB];
                    
                    if CellStatusB && CellStatusU && CellDiff > DiffTrhreshold
                        NeuronSpecData(Giter).Trial = sprintf('Trial%d',trial);
                        NeuronSpecData(Giter).Feature = FeatureThis.Name;
                        NeuronSpecData(Giter).NeuronSpecNum = NeuronSpecData(Giter).NeuronSpecNum + 1;
                        NeuronSpecData(Giter).NeuronSpecInd = [NeuronSpecData(Giter).NeuronSpecInd cell];
                        NeuronSpecData(Giter).NeuronSpecZscore = [NeuronSpecData(Giter).NeuronSpecZscore CellZscoreB];
                        NeuronSpecData(Giter).BaseLineData = [NeuronSpecData(Giter).BaseLineData BaseLineThis.Cell(:,cell)];
                        NeuronSpecData(Giter).NeuronSpecData = [NeuronSpecData(Giter).NeuronSpecData FeatureThis.Cell(:,cell)];
                        NeuronSpecData(Giter).NeuronDiff = [NeuronSpecData(Giter).NeuronDiff CellDiff];
                        CellDiffData = [CellDiffData CellDiff];
                    end
                end
                Giter = Giter + 1;
            else
                fprintf('Feature %s not found\n',FeatureThis.Name);
                clear FeatureThis;
            end            
        end
        clear BaseLineThis;
        
        % definition of Trace12
        NeuronSpecData(Giter).Trial = sprintf('Trial%d',trial);
        NeuronSpecData(Giter).Feature = sprintf('trace%d12',trial);
        
        IndexTrace1 = find(strcmp({NeuronSpecData.Feature}, sprintf('trace%d1',trial)));
        IndexTrace2 = find(strcmp({NeuronSpecData.Feature}, sprintf('trace%d2',trial)));
        [~, Ind1, Ind2] = intersect(NeuronSpecData(IndexTrace1).NeuronSpecInd, NeuronSpecData(IndexTrace2).NeuronSpecInd);
        
        NeuronSpecData(Giter).NeuronSpecInd = NeuronSpecData(IndexTrace1).NeuronSpecInd(Ind1);
        NeuronSpecData(Giter).NeuronSpecNum = length(NeuronSpecData(Giter).NeuronSpecInd);
        
        NeuronSpecData(Giter).NeuronSpecZscore = NeuronSpecData(IndexTrace1).NeuronSpecZscore(Ind1);
        NeuronSpecData(Giter).BaseLineData = NeuronSpecData(IndexTrace1).BaseLineData(:,Ind1);
        NeuronSpecData(Giter).NeuronSpecData = [NeuronSpecData(IndexTrace1).NeuronSpecData(:,Ind1); NeuronSpecData(IndexTrace2).NeuronSpecData(:,Ind2)];
        Giter = Giter + 1;
        
        % definition of Trace123
        NeuronSpecData(Giter).Trial = sprintf('Trial%d',trial);
        NeuronSpecData(Giter).Feature = sprintf('trace%d123',trial);
        
        IndexTrace1 = find(strcmp({NeuronSpecData.Feature}, sprintf('trace%d3',trial)));
        IndexTrace2 = find(strcmp({NeuronSpecData.Feature}, sprintf('trace%d12',trial)));
        [~, Ind1, Ind2] = intersect(NeuronSpecData(IndexTrace1).NeuronSpecInd, NeuronSpecData(IndexTrace2).NeuronSpecInd);
        
        NeuronSpecData(Giter).NeuronSpecInd = NeuronSpecData(IndexTrace1).NeuronSpecInd(Ind1);
        NeuronSpecData(Giter).NeuronSpecNum = length(NeuronSpecData(Giter).NeuronSpecInd);
        
        NeuronSpecData(Giter).NeuronSpecZscore = NeuronSpecData(IndexTrace1).NeuronSpecZscore(Ind1);
        NeuronSpecData(Giter).BaseLineData = NeuronSpecData(IndexTrace1).BaseLineData(:,Ind1);
        NeuronSpecData(Giter).NeuronSpecData = [NeuronSpecData(IndexTrace1).NeuronSpecData(:,Ind1); NeuronSpecData(IndexTrace2).NeuronSpecData(:,Ind2)];  
        Giter = Giter + 1;
    end
    TraceData(group).NeuronSpecData = NeuronSpecData;
end
save(sprintf('%sNeuronSpecData_3sigma_MADscoredDiff.mat',PathOut));

%% shock recalculation

for group = 1:3
    fprintf('Analysis of %d group for shock feature started\n',group);
    TraceData(group).NeuronSpecData(end+1).Trial = 'TrialAll';
    TraceData(group).NeuronSpecData(end).Feature = 'shock';
    TraceData(group).NeuronSpecData(end).NeuronSpecNum = 0;
    
    FeatureShock.Index = find(strcmp(FeaturesHeaders, 'shock'));
    FeatureShock.Line = table2array(TraceData(group).Features(:,FeatureShock.Index));
    FeatureShock.Cell = zeros(sum(FeatureShock.Line)/7,size(TraceData(group).NeuronDataNorm,2));
    
    BaseLineShock.Cell = zeros(20,size(TraceData(group).NeuronDataNorm,2));
    
    for trial = 1:7
        BaseLineShock.Index = find(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineShock.Line = table2array(TraceData(group).Features(:,BaseLineShock.Index));
        
        for cell = 1:TraceData(group).NeuronNum
            
            TempArray = TraceData(group).NeuronDataNorm(FeatureShock.Line.*TraceData(group).NeuronDataNorm(:,cell)~=0,cell);
            FeatureShock.Cell(:,cell) = (TempArray(1:6)+TempArray(7:12)+TempArray(13:18)+TempArray(19:24)+TempArray(25:30)+TempArray(31:36)+TempArray(37:42))./7;
            
            BaseLineShock.Cell(:,cell) = BaseLineShock.Cell(:,cell) + TraceData(group).NeuronDataNorm(BaseLineShock.Line.*TraceData(group).NeuronDataNorm(:,cell)~=0,cell);
            
        end
    end
    
    for cell = 1:TraceData(group).NeuronNum
        BaseLineShock.Cell(:,cell) = BaseLineShock.Cell(:,cell)./7;
        
        % Calculate specialization of neuron-feature
        [CellStatusB, CellZscoreB, CellDiff] = Bootstrap(BaseLineShock.Cell(:,cell)', FeatureShock.Cell(:,cell)', NumIter, SigmaValue);
        
        % u-test implementation
        [CellStatusU] = UTest(BaseLineShock.Cell(:,cell)', FeatureShock.Cell(:,cell)',p_value);
        
        if CellStatusB && CellStatusU && CellDiff > DiffTrhreshold
            TraceData(group).NeuronSpecData(end).NeuronSpecNum = TraceData(group).NeuronSpecData(end).NeuronSpecNum + 1;
            TraceData(group).NeuronSpecData(end).NeuronSpecInd = [TraceData(group).NeuronSpecData(end).NeuronSpecInd cell];
            TraceData(group).NeuronSpecData(end).NeuronSpecZscore = [TraceData(group).NeuronSpecData(end).NeuronSpecZscore CellZscoreB];
            TraceData(group).NeuronSpecData(end).BaseLineData = [TraceData(group).NeuronSpecData(end).BaseLineData BaseLineShock.Cell(:,cell)];
            TraceData(group).NeuronSpecData(end).NeuronSpecData = [TraceData(group).NeuronSpecData(end).NeuronSpecData FeatureShock.Cell(:,cell)];
            TraceData(group).NeuronSpecData(end).NeuronDiff = [TraceData(group).NeuronSpecData(end).NeuronDiff CellDiff];
        end
    end
end
save(sprintf('%sNeuronSpecData_MADDiff.mat',PathOut));

%% additional plot tools
% HeatMap([NeuronSpecData.BaseLineData' NeuronSpecData.NeuronSpecData'],'Colormap','cool');

% average Ca2+ signal baseline-feature
for group = 1:3
    for feature = 1:size(TraceData(group).NeuronSpecData,2)
        
        BaseFeatureLine = [TraceData(group).NeuronSpecData(feature).BaseLineData; TraceData(group).NeuronSpecData(feature).NeuronSpecData];
        
%         h=figure;
%         for cell = 1:size(BaseFeatureLine,2)
%             plot(1:size(BaseFeatureLine,1),  BaseFeatureLine(:,cell)); 
%             hold on;
%         end
        
        h = figure;
        BaseFeatureLineMean = mean(BaseFeatureLine,2);
        plot(1:size(BaseFeatureLineMean,1),  BaseFeatureLineMean');
        xlabel('Time, s');
        ylabel('Raw Ca2+');
        title(sprintf('Group %s\nAverage Ca2+ activity of %s neurons',TraceData(group).GroupName, TraceData(group).NeuronSpecData(feature).Feature));
        saveas(h, sprintf('%s%s_%s.png', PathPlot,TraceData(group).GroupName, TraceData(group).NeuronSpecData(feature).Feature));
        delete(h);
        
    end
end


%% show all traces from group

FillColor = {};
FillColor{1} = [0.8, 0.8, 0.8];  % gray Baseline
FillColor{2} = [1, 1, 0];        % yellow sound
FillColor{3} = [0, 0.5, 0.5];    % cyan 1 trace1
FillColor{4} = [0, 0.8, 0.8];    % cyan 2 trace2
FillColor{5} = [0, 1, 1];        % cyan 3 trace3
FillColor{6} = [1, 0, 0];        % red shock
Transparency = 0.3;
FeaturePlotList = {'baseline','sound','trace1','trace2','trace3','shock'};

for group = 1:6
    HH = 0;
    
    h=figure;
    for cell=1:TraceData(group).NeuronNum        
        plot(1:1294, TraceData(group).NeuronDataNorm(:,cell)+HH); hold on;
        HH = HH + max(TraceData(group).NeuronDataNorm(:,cell));
    end
    
    % filling fearue area
    for trial=1:7
        for feature = 1:length(FeaturePlotList)-1
            switch feature
                case {1,2}
                    Plot.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d',FeaturePlotList{feature}, trial)));
                    lineIndices = [min(find(table2array(TraceData(group).Features(:,Plot.Index)))), max(find(table2array(TraceData(group).Features(:,Plot.Index))))]; %#ok<MXFND>
                case {3,4,5}
                    Plot.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d%s',FeaturePlotList{feature}(1:end-1), trial,FeaturePlotList{feature}(end))));
                    lineIndices = [min(find(table2array(TraceData(group).Features(:,Plot.Index)))), max(find(table2array(TraceData(group).Features(:,Plot.Index))))]; %#ok<MXFND>
            end
            
            for i = 1:length(lineIndices)-1
                fill([lineIndices(i)-0.5, lineIndices(i+1)+0.5, lineIndices(i+1)+0.5, lineIndices(i)-0.5],...
                    [0, 0, HH, HH], FillColor{feature}, 'FaceAlpha', Transparency);
            end
        end
    end
    
    % for shock
    feature = 6;
    Plot.Index = find(strcmp(FeaturesHeaders, sprintf('%s',FeaturePlotList{feature})));
    [~, ~, lineIndices] = findSeriesOfOnes(table2array(TraceData(group).Features(:,Plot.Index)));
    for i = 1:2:length(lineIndices)-1
        fill([lineIndices(i)-0.5, lineIndices(i+1)+0.5, lineIndices(i+1)+0.5, lineIndices(i)-0.5],...
            [0, 0, HH, HH], FillColor{feature}, 'FaceAlpha', Transparency);
    end
    
    xlabel('Time, s');
    ylabel('Norm Ca2+ (Mad method)');
    title(sprintf('Group: %s',TraceData(group).GroupName));
    saveas(h, sprintf('%sAllTraces\\%s_traces.fig', PathPlot, TraceData(group).GroupName));
    delete(h);
end

%% show spec populations from group

FillColor = {};
FillColor{1} = [0.8, 0.8, 0.8];  % gray Baseline
FillColor{2} = [1, 1, 0];        % yellow sound
FillColor{3} = [0, 0.5, 0.5];    % cyan 1 trace1
FillColor{4} = [0, 0.8, 0.8];    % cyan 2 trace2
FillColor{5} = [0, 1, 1];        % cyan 3 trace3
FillColor{6} = [1, 0, 0];        % red shock
Transparency = 0.3;
FeaturePlotList = {'baseline','sound','trace1','trace2','trace3','shock'};

for group = 1:6
    
    for spec = 1:size(TraceData(group).NeuronSpecData,2)
        HH = 0;
        h=figure;
        IndSpec = TraceData(group).NeuronSpecData(spec).NeuronSpecInd;
        indTemp = 1;
        for cell = IndSpec
            plot(1:1294, TraceData(group).NeuronDataNorm(:,cell)+HH); hold on;
            
            % text z-score and diff
            if spec == 43
                IndTextPlot = 4;
            else
                IndTextPlot = find(strcmp(FeaturesHeaders, sprintf('baseline%d',str2num(TraceData(1).NeuronSpecData(spec).Trial(end)))));
            end
            textPositionX = min(find(table2array(TraceData(group).Features(:,IndTextPlot)))) - 20; %#ok<MXFND>
            textPositionY = HH+5;
            if ~isempty(TraceData(group).NeuronSpecData(spec).NeuronDiff)
                textString = sprintf('Z: %2.2f. Diff: %2.2f',TraceData(group).NeuronSpecData(spec).NeuronSpecZscore(indTemp),TraceData(group).NeuronSpecData(spec).NeuronDiff(indTemp));
            else
                textString = sprintf('Z: %2.2f. Diff: ??',TraceData(group).NeuronSpecData(spec).NeuronSpecZscore(indTemp));
            end
            text(textPositionX, textPositionY, textString, 'FontSize', 8, 'FontWeight', 'bold', 'Color', 'red');
                        
            HH = HH + max(TraceData(group).NeuronDataNorm(:,cell));
            indTemp = indTemp + 1;
        end
        
        % filling feature area
        if spec == 43
            trials  = 1;
        else
            trials = str2num(TraceData(1).NeuronSpecData(spec).Trial(end));%#ok<ST2NM>
        end
        for trial = trials 
            for feature = 1:length(FeaturePlotList)-1
                switch feature
                    case {1,2}
                        Plot.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d',FeaturePlotList{feature}, trial)));
                        lineIndices = [min(find(table2array(TraceData(group).Features(:,Plot.Index)))), max(find(table2array(TraceData(group).Features(:,Plot.Index))))]; %#ok<MXFND>
                    case {3,4,5}
                        Plot.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d%s',FeaturePlotList{feature}(1:end-1), trial,FeaturePlotList{feature}(end))));
                        lineIndices = [min(find(table2array(TraceData(group).Features(:,Plot.Index)))), max(find(table2array(TraceData(group).Features(:,Plot.Index))))]; %#ok<MXFND>
                end
                
                for i = 1:length(lineIndices)-1
                    fill([lineIndices(i)-0.5, lineIndices(i+1)+0.5, lineIndices(i+1)+0.5, lineIndices(i)-0.5],...
                        [0, 0, HH, HH], FillColor{feature}, 'FaceAlpha', Transparency);
                end
            end
        end
        
        % for shock
        feature = 6;
        Plot.Index = find(strcmp(FeaturesHeaders, sprintf('%s',FeaturePlotList{feature})));
        [~, ~, lineIndices] = findSeriesOfOnes(table2array(TraceData(group).Features(:,Plot.Index)));
        for i = 1:2:length(lineIndices)-1
            fill([lineIndices(i)-0.5, lineIndices(i+1)+0.5, lineIndices(i+1)+0.5, lineIndices(i)-0.5],...
                [0, 0, HH, HH], FillColor{feature}, 'FaceAlpha', Transparency);
        end
        
        title(sprintf('Group: %s. Feature: %s. NumNeurons: %d',TraceData(group).GroupName, TraceData(group).NeuronSpecData(spec).Feature,TraceData(group).NeuronSpecData(spec).NeuronSpecNum));
        xlabel('Time, s');
        ylabel('Norm Ca2+ (Mad method)');
        saveas(h, sprintf('%sAllSpecNeurons\\%s_%s_traces.fig', PathPlot, TraceData(group).GroupName,TraceData(group).NeuronSpecData(spec).Feature));
        delete(h);
    end
end
%% plot for spec data

group = 1;
spec = 2;

h = figure;
HH = 0;
for cell = TraceData(group).NeuronSpecData(spec).NeuronSpecInd
    if cell == 1
        HH = 0;
    else
        HH = HH + max(TraceData(group).NeuronDataNorm(:,cell-1));
    end
    
    plot(1:1294, TraceData(group).NeuronDataNorm(:,cell)+HH); hold on;
end

for line = [71 91 111 113 131 151 170]
    xline(line, 'r'); hold on;
end


%% searching of CS-Trace and *-only populations

for group = 1:size(TraceData,2)
    NeuronPopData = struct('Feature', [], 'NeuronNum', 0, 'NeuronInd', [], 'PercentAll', [], 'PercentCS', []);
    Fiter = 1;
    
    CSTraceNeuronPercentALL = zeros(7,3);
    CSTraceNeuronPercentCS = zeros(7,3);
    CSTraceNeuronNum = zeros(7,3);
    
    TraceOnlyNeuronPercentALL = zeros(7,3);
    TraceOnlyNeuronPercentTr = zeros(7,3);
    TraceOnlyNeuronNum = zeros(7,3);
    
    for trial = 1:7
        CSIndexThis = find(strcmp({TraceData(group).NeuronSpecData.Feature} , sprintf('sound%d', trial)));
        
        for trace = 1:3
            
            switch trace
                case 1
                    TraceIndexThis = find(strcmp({TraceData(group).NeuronSpecData.Feature} , sprintf('trace%d%d', trial, trace)));
                case 2
                    TraceIndexThis = find(strcmp({TraceData(group).NeuronSpecData.Feature} , sprintf('trace%d1%d', trial, trace)));
                case 3
                    TraceIndexThis = find(strcmp({TraceData(group).NeuronSpecData.Feature} , sprintf('trace%d12%d', trial, trace)));
            end
            
            % definition of CSTrace
            NeuronPopData(Fiter).Feature = sprintf('CSTrace%d%d',trial,trace);
            [~, IndCS, IndTr] = intersect(TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecInd, TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecInd);
            NeuronPopData(Fiter).NeuronInd = TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecInd(IndCS);
            NeuronPopData(Fiter).NeuronNum = length(NeuronPopData(Fiter).NeuronInd);
            NeuronPopData(Fiter).PercentAll = round((NeuronPopData(Fiter).NeuronNum/TraceData(group).NeuronNum)*100);
            NeuronPopData(Fiter).PercentCS = round((NeuronPopData(Fiter).NeuronNum/TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecNum)*100);
            
            NeuronPopData(Fiter).NeuronSpecZscore = TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecZscore(IndCS);
            NeuronPopData(Fiter).BaseLineData = TraceData(group).NeuronSpecData(CSIndexThis).BaseLineData(:,IndCS);
            NeuronPopData(Fiter).NeuronSpecData = [TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecData(:,IndCS); TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecData(:,IndTr)];
            
            CSTraceNeuronPercentALL(trial,trace) =  NeuronPopData(Fiter).PercentAll;
            CSTraceNeuronPercentCS(trial,trace) = NeuronPopData(Fiter).PercentCS;
            CSTraceNeuronNum(trial,trace) = NeuronPopData(Fiter).NeuronNum;
            
            Fiter = Fiter + 1;
            
            % definition of CS-only
%             if trace > 1
                NeuronPopData(Fiter).Feature = sprintf('CSOnly%d%d',trial,trace);
                
                [~, ~, IndTr] = intersect(NeuronPopData(Fiter-1).NeuronInd, TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecInd);
                TempInd = TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecInd;
                TempInd(IndTr) = 0;
                IndCsOnly = find(TempInd~=0);
                CellCSOnly = TempInd(IndCsOnly);
                NeuronPopData(Fiter).NeuronInd = TempInd(TempInd~=0);
                
                NeuronPopData(Fiter).NeuronNum = length(NeuronPopData(Fiter).NeuronInd);
                NeuronPopData(Fiter).PercentAll = round((NeuronPopData(Fiter).NeuronNum/TraceData(group).NeuronNum)*100);
                NeuronPopData(Fiter).PercentCS = round((NeuronPopData(Fiter).NeuronNum/TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecNum)*100);
                
                NeuronPopData(Fiter).NeuronSpecZscore = TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecZscore(IndCsOnly);
                NeuronPopData(Fiter).BaseLineData = TraceData(group).NeuronSpecData(CSIndexThis).BaseLineData(:,IndCsOnly);
                % ToDo: need trace periods of CellCSOnly neurons
                %             NeuronPopData(Fiter).NeuronSpecData = [TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecData(:,IndCsOnly); TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecData(:,???)];
                
                Fiter = Fiter + 1;
%             end
            
            % definition of Trace-only
            NeuronPopData(Fiter).Feature = sprintf('TraceOnly%d%d',trial, trace);
            
            [~, ~, IndTr] = intersect(NeuronPopData(Fiter-2).NeuronInd, TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecInd);
            TempInd = TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecInd;
            TempInd(IndTr) = 0;
            IndTraceOnly = find(TempInd~=0);
            CellTraceOnly = TempInd(IndTraceOnly);
            NeuronPopData(Fiter).NeuronInd = TempInd(TempInd~=0);
            
            NeuronPopData(Fiter).NeuronNum = length(NeuronPopData(Fiter).NeuronInd);
            NeuronPopData(Fiter).PercentAll = round((NeuronPopData(Fiter).NeuronNum/TraceData(group).NeuronNum)*100);
            NeuronPopData(Fiter).PercentCS = round((NeuronPopData(Fiter).NeuronNum/TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecNum)*100);
            
            NeuronPopData(Fiter).NeuronSpecZscore = TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecZscore(IndTraceOnly);
            NeuronPopData(Fiter).BaseLineData = TraceData(group).NeuronSpecData(TraceIndexThis).BaseLineData(:,IndTraceOnly);
            
            % ToDo: need CS-period periods of CellTraceOnly neurons
            % NeuronPopData(Fiter).NeuronSpecData = [TraceData(group).NeuronSpecData(CSIndexThis).NeuronSpecData(:,????); TraceData(group).NeuronSpecData(TraceIndexThis).NeuronSpecData(:,NeuronPopData(Fiter).NeuronInd)];
            
            TraceOnlyNeuronPercentALL(trial,trace) = NeuronPopData(Fiter).PercentAll;
            TraceOnlyNeuronPercentTr(trial,trace) = NeuronPopData(Fiter).PercentCS;
            TraceOnlyNeuronNum(trial,trace) = NeuronPopData(Fiter).NeuronNum;
            
            Fiter = Fiter + 1;
            
        end
        
    end
    TraceData(group).NeuronPopData = NeuronPopData;
    
    TraceData(group).CSTraceNeuronNum = CSTraceNeuronNum;
    TraceData(group).TraceOnlyNeuronNum = TraceOnlyNeuronNum;
    
    TraceData(group).CSTraceNeuronPercentALL = CSTraceNeuronPercentALL;
    TraceData(group).CSTraceNeuronPercentCS = CSTraceNeuronPercentCS;
    
    TraceData(group).TraceOnlyNeuronPercentALL = TraceOnlyNeuronPercentALL;
    TraceData(group).TraceOnlyNeuronPercentTr = TraceOnlyNeuronPercentTr;
end
save(sprintf('%sNeuronSpecData_PopDataMadDiff.mat',PathOut));



root = 'g:\_Projects\_2024_Trace\';
NumIter = 1000;
SigmaValue = 3;
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

TraceData = struct('GroupName', [],'FileName', [], 'Features', [], 'NeuronData', [], 'NeuronInd', [], 'NeuronNum', []);

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

save(sprintf('%sTraceDataAllGroups.mat',PathOut));

%% recalculation shock period to 6 seconds

ShockPeriod = 6; % in seconds
ShockTime = 2; % in seconds
for group=1:3
    ShockFrame = find(table2array(TraceData(group).Features(:,4)) == 1);
    disp(ShockFrame);
    for frame = ShockTime:ShockTime:length(ShockFrame)
        TraceData(group).Features(ShockFrame(frame)+1:ShockFrame(frame)+ShockPeriod-ShockTime,4) = array2table(1);
    end
end
save(sprintf('%sTraceDataAllGroups.mat',PathOut));

%% searching spesializations of neurons

% FeatureList = {'sound','shock','trace1','trace2','trace3'};
FeatureList = {'sound','trace1','trace2','trace3'};
for group = 1:size(TraceData,2)
    
    fprintf('Analysis of %s group started\n',TraceData(group).GroupName);
    
    NeuronSpecData = struct('Trial',[],'Feature',[],'NeuronSpecNum',[],'NeuronSpecInd',[],'NeuronSpecZscore',[],'BaseLineData',[],'NeuronSpecData',[]);
    
    Giter = 1;
    for trial = 1:7
        fprintf('Analysis of %d trial started\n',trial);
        
        % create a mask for baselineN
        BaseLineThis.Name = sprintf('baseline%d',trial);
        BaseLineThis.Index = find(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineThis.Line = table2array(TraceData(group).Features(:,BaseLineThis.Index));
        BaseLineThis.Cell = zeros(sum(BaseLineThis.Line),size(TraceData(group).NeuronData,2));
        
        for feature = 1:length(FeatureList)
            
            switch feature
                case 1
                    FeatureThis.Name = sprintf('%s%d',FeatureList{feature} ,trial);
                    FeatureThis.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d',FeatureList{feature},trial)));
%                 case 2
%                     FeatureThis.Name = FeatureList{feature};
%                     FeatureThis.Index = find(strcmp(FeaturesHeaders, FeatureList{feature}));
                case {2,3,4}
                    FeatureThis.Name = sprintf('%s%d%s',FeatureList{feature}(1:end-1),trial,FeatureList{feature}(end));
                    FeatureThis.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d%s',FeatureList{feature}(1:end-1),trial,FeatureList{feature}(end))));
            end
            
            FeatureThis.Line = table2array(TraceData(group).Features(:,FeatureThis.Index));
            FeatureThis.Cell = zeros(sum(FeatureThis.Line),size(TraceData(group).NeuronData,2));
            NeuronSpecData(Giter).NeuronSpecNum = 0;
            if sum(FeatureThis.Line) ~= 0
                for cell = 1:TraceData(group).NeuronNum
                    
                    FeatureThis.Cell(:,cell) = TraceData(group).NeuronData(FeatureThis.Line.*TraceData(group).NeuronData(:,cell)~=0,cell);
                    
                    BaseLineThis.Cell(:,cell) = TraceData(group).NeuronData(BaseLineThis.Line.*TraceData(group).NeuronData(:,cell)~=0,cell);
                    
                    % Calculate specialization of neuron-feature
                    [CellStatus, CellZscore] = Bootstrap(BaseLineThis.Cell(:,cell)', FeatureThis.Cell(:,cell)', NumIter, SigmaValue);
                    
                    if CellStatus
                        NeuronSpecData(Giter).Trial = sprintf('Trial%d',trial);
                        NeuronSpecData(Giter).Feature = FeatureThis.Name;
                        NeuronSpecData(Giter).NeuronSpecNum = NeuronSpecData(Giter).NeuronSpecNum + 1;
                        NeuronSpecData(Giter).NeuronSpecInd = [NeuronSpecData(Giter).NeuronSpecInd cell];
                        NeuronSpecData(Giter).NeuronSpecZscore = [NeuronSpecData(Giter).NeuronSpecZscore CellZscore];
                        NeuronSpecData(Giter).BaseLineData = [NeuronSpecData(Giter).BaseLineData BaseLineThis.Cell(:,cell)];
                        NeuronSpecData(Giter).NeuronSpecData = [NeuronSpecData(Giter).NeuronSpecData FeatureThis.Cell(:,cell)];
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
save(sprintf('%sNeuronSpecData_3sigma.mat',PathOut));

%% shock recalculation

for group = 1:3
    fprintf('Analysis of %d group for shock feature started\n',group);
    TraceData(group).NeuronSpecData(end+1).Trial = 'TrialAll';
    TraceData(group).NeuronSpecData(end).Feature = 'shock';
    TraceData(group).NeuronSpecData(end).NeuronSpecNum = 0;
    
    FeatureShock.Index = find(strcmp(FeaturesHeaders, 'shock'));
    FeatureShock.Line = table2array(TraceData(group).Features(:,FeatureShock.Index));
    FeatureShock.Cell = zeros(sum(FeatureShock.Line)/7,size(TraceData(group).NeuronData,2));
    
    BaseLineShock.Cell = zeros(20,size(TraceData(group).NeuronData,2));
    
    for trial = 1:7
        BaseLineShock.Index = find(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineShock.Line = table2array(TraceData(group).Features(:,BaseLineShock.Index));
        
        for cell = 1:TraceData(group).NeuronNum
            
            TempArray = TraceData(group).NeuronData(FeatureShock.Line.*TraceData(group).NeuronData(:,cell)~=0,cell);
            FeatureShock.Cell(:,cell) = (TempArray(1:6)+TempArray(7:12)+TempArray(13:18)+TempArray(19:24)+TempArray(25:30)+TempArray(31:36)+TempArray(37:42))./7;
            
            BaseLineShock.Cell(:,cell) = BaseLineShock.Cell(:,cell) + TraceData(group).NeuronData(BaseLineShock.Line.*TraceData(group).NeuronData(:,cell)~=0,cell);
            
        end
    end
    
    for cell = 1:TraceData(group).NeuronNum
        BaseLineShock.Cell(:,cell) = BaseLineShock.Cell(:,cell)./7;
        
        % Calculate specialization of neuron-feature
        [CellStatus, CellZscore] = Bootstrap(BaseLineShock.Cell(:,cell)', FeatureShock.Cell(:,cell)', NumIter, SigmaValue);
        
        if CellStatus
            TraceData(group).NeuronSpecData(end).NeuronSpecNum = TraceData(group).NeuronSpecData(end).NeuronSpecNum + 1;
            TraceData(group).NeuronSpecData(end).NeuronSpecInd = [TraceData(group).NeuronSpecData(end).NeuronSpecInd cell];
            TraceData(group).NeuronSpecData(end).NeuronSpecZscore = [TraceData(group).NeuronSpecData(end).NeuronSpecZscore CellZscore];
            TraceData(group).NeuronSpecData(end).BaseLineData = [TraceData(group).NeuronSpecData(end).BaseLineData BaseLineShock.Cell(:,cell)];
            TraceData(group).NeuronSpecData(end).NeuronSpecData = [TraceData(group).NeuronSpecData(end).NeuronSpecData FeatureShock.Cell(:,cell)];
        end
    end
end
save(sprintf('%sNeuronSpecData_3sigma_shock.mat',PathOut));

%% additional tools
% HeatMap([NeuronSpecData.BaseLineData' NeuronSpecData.NeuronSpecData'],'Colormap','cool');

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
save(sprintf('%sNeuronSpecData_PopData.mat',PathOut));


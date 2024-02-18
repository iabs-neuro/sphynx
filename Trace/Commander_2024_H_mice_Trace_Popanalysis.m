
root = 'g:\_Projects\_2024_Trace\';
NumIter = 1000;
SigmaValue = 3;
PathOut = sprintf('%sPopAnalysis\\',root);

%% loading ready data

PathTraceData = sprintf('%sPopAnalysis\\TraceDataAllGroups.mat',root);
load(PathTraceData);

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

for group = 3:length(Groups)
    
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

FeatureList = {'sound','shock','trace1','trace2','trace3'};
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
                case 2
                    FeatureThis.Name = FeatureList{feature};
                    FeatureThis.Index = find(strcmp(FeaturesHeaders, FeatureList{feature}));
                case {3,4,5}
                    FeatureThis.Name = sprintf('%s%d%s',FeatureList{feature}(1:end-1),trial,FeatureList{feature}(end));
                    FeatureThis.Index = find(strcmp(FeaturesHeaders, sprintf('%s%d%s',FeatureList{feature}(1:end-1),trial,FeatureList{feature}(end))));
            end
            
            FeatureThis.Line = table2array(TraceData(group).Features(:,FeatureThis.Index));
            FeatureThis.Cell = zeros(sum(FeatureThis.Line),size(TraceData(group).NeuronData,2));
            NeuronSpecData(Giter).NeuronSpecNum = 0;
            if sum(FeatureThis.Line) ~= 0
                for cell = 1:TraceData(group).NeuronNum
                    
                    % FeatureThis.Cell(:,cell) = TraceData(group).NeuronData(find(FeatureThis.Line.*TraceData(group).NeuronData(:,cell)),cell);
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
    end
    TraceData(group).NeuronSpecData = NeuronSpecData;
end
save(sprintf('%sNeuronSpecData_2sigma.mat',PathOut));


%% additional tools
HeatMap([NeuronSpecData.BaseLineData' NeuronSpecData.NeuronSpecData'],'Colormap','cool');

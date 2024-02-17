%% paths and names

root = 'g:\_Projects\_2024_Trace\';

PathFeatures = sprintf('%sFeatures\',root);
PathTraces = sprintf('%sTraces\',root);
PathTraceData = sprintf('%sPopAnalysis\TraceDataAllGroups.mat',root);

PathOut = 'd:\Projects\Trace\PopAnalysis\';

Tr1D_G00 = {'H02_1D','H10_1D','H11_1D','H14_1D'};
Tr1D_G20 = {'H03_1D','H15_1D','H16_1D','H19_1D'};
Tr1D_G60 = {'H04_1D','H05_1D','H13_1D'};
% Tr1D_G60 = {'H04_1D','H05_1D','H13_1D','H23_1D'};

Tr2D_G00 = {'H02_2D','H10_2D','H11_2D','H14_2D'};
Tr2D_G20 = {'H03_2D','H15_2D','H16_2D','H19_2D'};
Tr2D_G60 = {'H04_2D','H05_2D','H13_2D'};
% Tr2D_G60 = {'H04_2D','H05_2D','H13_2D','H23_2D'};


Groups = {Tr1D_G00,Tr1D_G20,Tr1D_G60,Tr2D_G00,Tr2D_G20,Tr2D_G60};
GroupsNames = {'Tr1D_G00','Tr1D_G20','Tr1D_G60','Tr2D_G00','Tr2D_G20','Tr2D_G60'};

TraceData = struct('GroupName', [],'FileName', [], 'Features', [], 'NeuronData', [], 'NeuronInd', [], 'NeuronNum', []);

%% creation struct for synchronized traces and features

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

save(sprintf('%s\\TraceDataAllGroups.mat',PathOut));

%% searching spesializations of neurons

load(PathTraceData);
TraceData.SpecNeuron = [];
FeatureList = ['sound','shock','trace1','trace2','trace3'];

for group = 1:size(TraceData,2)
    for trial = 1:7
        
        % create a mask for baselineN        
        BaseLineThis.Name = FeaturesHeaders(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineThis.Index = find(strcmp(FeaturesHeaders, sprintf('baseline%d',trial)));
        BaseLineThis.Line = table2array(TraceData(group).Features(:,BaseLineThis.Index));
        BaseLineThis.Cell = zeros(sum(BaseLineThis.Line),size(TraceData(group).NeuronData,2));
        
        for cell = 1:TraceData(group).NeuronNum
            BaseLineThis.Cell(:,cell) = TraceData(group).NeuronData(find(BaseLineThis.Line.*TraceData(group).NeuronData(:,cell)),cell);
            
            for feature = 1:length(FeatureList)
                
                % Calculate specialization of neuron-feature
                
%                 TraceData.SpecNeuron.
                
                
                
            end
        end
    end
end




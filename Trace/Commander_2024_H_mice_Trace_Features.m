%% paths and names

FreezPath = 'd:\Projects\Trace\FreezResults\';
ProtocolPath = 'd:\Projects\Trace\Trace_behav_Pop.mat';
load(ProtocolPath)

% Trace1DTr00 = 'd:\Projects\Trace\Protocols\Trace_1D_Tr00.csv';
% Trace1DTr20 = 'd:\Projects\Trace\Protocols\Trace_1D_Tr20.csv';
% Trace1DTr60 = 'd:\Projects\Trace\Protocols\Trace_1D_Tr60.csv';
% Trace2D = 'd:\Projects\Trace\Protocols\Trace_2D.csv';

PathOut = 'd:\Projects\Trace\Features\';

Tr00 = {'H02_1D','H10_1D','H11_1D','H14_1D'};
Tr20 = {'H03_1D','H15_1D','H16_1D','H19_1D'};
Tr60 = {'H04_1D','H05_1D','H13_1D','H23_1D'};
Tr2D  = {'H02_2D','H03_2D','H04_2D','H05_2D','H10_2D','H11_2D','H13_2D','H14_2D','H15_2D','H16_2D','H19_2D','H23_2D'};

% % 1D Tr00
% FileNames = Tr00;
% Protocol = Trace1DTr00;

% % 1D Tr20
% FileNames = Tr20;
% Protocol = Trace1DTr20;

% % 1D Tr60
% FileNames = Tr60;
% Protocol = Trace1DTr60;

% 2D 
FileNames = Tr2D;
Protocol = Trace2D;

%% Features calculations

for file = 1:length(FileNames)
    
    Features.Data = [];
    Features.Name = {
        'between', 'baseline1', 'sound1', 'shock', 'trace11', 'trace12', 'trace13',...
        'baseline2', 'sound2', 'trace21', 'trace22', 'trace23',...
        'baseline3', 'sound3', 'trace31', 'trace32', 'trace33',...
        'baseline4', 'sound4', 'trace41', 'trace42', 'trace43',...
        'baseline5', 'sound5', 'trace51', 'trace52', 'trace53',...
        'baseline6', 'sound6', 'trace61', 'trace62', 'trace63',...
        'baseline7', 'sound7', 'trace71', 'trace72', 'trace73'};
    
    for act=1:size(Protocol,1)
        for FeatureName = 1:size(Features.Name,2)
            if ismember(Protocol.between(act), categorical(Features.Name(FeatureName)))
                Features.Data(Protocol.VarName3(act)+1:Protocol.VarName3(act) + Protocol.VarName4(act),FeatureName) = 1;
            end
        end
    end
    
    Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);
    writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, FileNames{file}));
end

for i=1:37
        plot(1:38820,Features.Data(:,i)*i); hold on;
end

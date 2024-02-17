%% paths and names

FreezPath = 'd:\Projects\Trace\FreezResults\';
ProtocolPath = 'd:\Projects\Trace\Trace_behav.mat';
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

% % 2D 
% FileNames = Tr2D;
% Protocol = Trace2D;

%% Features calculations

for file = 1:length(FileNames)
    
    load(sprintf('%sTRACE_%s_WorkSpace_13_5_36_22.mat',FreezPath,FileNames{file}),'MotIndThresFreez');
    
    Freezing = MotIndThresFreez(2,:);
    n_frames = length(Freezing);
    
    Features.Data = [];
    Features.Name = {'freezing', 'shock', 'sound', 'trace1', 'trace2', 'trace3', 'trace12', 'trace123', 'cstrace1','cstrace2','cstrace3','cstrace12','cstrace123'};
    Features.Data(1:n_frames,1) = Freezing;
    
    
    for act=1:size(Protocol,1)
        for FeatureName = 1:size(Features.Name,2)
            if ismember(Protocol.before(act), categorical(Features.Name(FeatureName)))
                Features.Data(Protocol.VarName3(act)+1:Protocol.VarName3(act) + Protocol.VarName4(act),FeatureName) = 1;
            end
        end
    end
    
    % trace12
    Features.Data(1:n_frames,7) = Features.Data(1:n_frames,4)+Features.Data(1:n_frames,5);
    % trace123
    Features.Data(1:n_frames,8) = Features.Data(1:n_frames,4)+Features.Data(1:n_frames,5)+Features.Data(1:n_frames,6);
    % cstrace1
    Features.Data(1:n_frames,9) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,4);
    % cstrace2
    Features.Data(1:n_frames,10) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,5);
    % cstrace3
    Features.Data(1:n_frames,11) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,6);
    % cstrace12
    Features.Data(1:n_frames,12) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,7);
    % cstrace123
    Features.Data(1:n_frames,13) = Features.Data(1:n_frames,3)+Features.Data(1:n_frames,8);

    
    Features.Table = array2table(Features.Data, 'VariableNames', Features.Name);
    writetable(Features.Table, sprintf('%s\\%s_Features.csv',PathOut, FileNames{file}));
end

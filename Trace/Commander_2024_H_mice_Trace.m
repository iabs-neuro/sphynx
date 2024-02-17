%% Components in seconds
% Components_1D_Tr00 = [90,20,2,18,20,20,92,20,2,18,20,20,92,20,2,18,20,20,92,20,2,18,20,20,92,20,2,18,20,20,92,20,2,18,20,20,92,20,2,18,20,20,92];
% Components_1D_Tr20 = [90,20,20,2,18,20,92,20,20,2,18,20,92,20,20,2,18,20,92,20,20,2,18,20,92,20,20,2,18,20,92,20,20,2,18,20,92,20,20,2,18,20,92];
% Components_1D_Tr60 = [90,20,20,20,20,2,90,20,20,20,20,2,90,20,20,20,20,2,90,20,20,20,20,2,90,20,20,20,20,2,90,20,20,20,20,2,90,20,20,20,20,2,90];
% Components_2D      = [90,20,20,20,20,92,20,20,20,20,92,20,20,20,20,92,20,20,20,20,92,20,20,20,20,92,20,20,20,20,92,20,20,20,20,92];

Components_1D_Tr00 = '90 20 2 18 20 20 92 20 2 18 20 20 92 20 2 18 20 20 92 20 2 18 20 20 92 20 2 18 20 20 92 20 2 18 20 20 92 20 2 18 20 20 92';
Components_1D_Tr20 = '90 20 20 2 18 20 92 20 20 2 18 20 92 20 20 2 18 20 92 20 20 2 18 20 92 20 20 2 18 20 92 20 20 2 18 20 92 20 20 2 18 20 92';
Components_1D_Tr60 = '90 20 20 20 20 2 90 20 20 20 20 2 90 20 20 20 20 2 90 20 20 20 20 2 90 20 20 20 20 2 90 20 20 20 20 2 90 20 20 20 20 2 90';
Components_2D      = '90 20 20 20 20 92 20 20 20 20 92 20 20 20 20 92 20 20 20 20 92 20 20 20 20 92 20 20 20 20 92 20 20 20 20 92';

VideoPath = 'd:\Projects\Trace\RawVideo\';
OutPath = 'd:\Projects\Trace\Features\';

Tr2D  = {'H02_2D','H03_2D','H04_2D','H05_2D','H10_2D','H11_2D','H13_2D','H14_2D','H15_2D','H16_2D','H19_2D','H23_2D'};
Tr00 = {'H02_1D','H10_1D','H11_1D','H14_1D'};
Tr20 = {'H03_1D','H15_1D','H16_1D','H19_1D'};
Tr60 = {'H04_1D','H05_1D','H13_1D','H23_1D'};

%% FREEZING CALCULATION

% 1D Training Tr00
FileNames = Tr00;
Components = Components_1D_Tr00;
PctComponentTimeFreezing1DTr00 = zeros(length(FileNames),43);
for file = 1:length(FileNames)
    FileName = sprintf('TRACE_%s.wmv',FileNames{file});    
    display(FileName);
    [PctComponentTimeFreezing] = VideoFreezingFuncG(1,VideoPath,FileName,3, Components, Components, 13,5,36,22,154);
    PctComponentTimeFreezing1DTr00(file,1:43) = PctComponentTimeFreezing(2,:);
end

% 1D Training Tr20
FileNames = Tr20;
Components = Components_1D_Tr20;
PctComponentTimeFreezing1DTr20 = zeros(length(FileNames),43);
for file = 1:length(FileNames)
    FileName = sprintf('TRACE_%s.wmv',FileNames{file});    
    display(FileName);
    [PctComponentTimeFreezing] = VideoFreezingFuncG(1,VideoPath,FileName,3, Components, Components, 13,5,36,22,154);
    PctComponentTimeFreezing1DTr20(file,1:43) = PctComponentTimeFreezing(2,:);
end

% 1D Training Tr60
FileNames = Tr60;
Components = Components_1D_Tr60;
PctComponentTimeFreezing1DTr60 = zeros(length(FileNames),43);
for file = 1:length(FileNames)
    FileName = sprintf('TRACE_%s.wmv',FileNames{file});    
    display(FileName);
    [PctComponentTimeFreezing] = VideoFreezingFuncG(1,VideoPath,FileName,3, Components, Components, 13,5,36,22,154);
    PctComponentTimeFreezing1DTr60(file,1:43) = PctComponentTimeFreezing(2,:);
end


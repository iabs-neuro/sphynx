%% parameters
MarkSizeF = 7;
MarkSizeT = 2;
FontSize = 15;
TimeSession = 600; % 600 second 
bin_size = 10;
CenterDiam = 20; % in sm
%% paths and names
% filenames = {
%     'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
%     'CC_H04_1D','CC_H04_2D','CC_H05_1D','CC_H05_2D','CC_H06_1D','CC_H06_2D',...
%     'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
%     'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D','CC_H12_1D','CC_H12_2D',...
%     'CC_H13_1D','CC_H13_2D','CC_H14_1D','CC_H14_2D','CC_H15_1D','CC_H15_2D',...
%     'CC_H16_1D','CC_H16_2D','CC_H17_1D','CC_H17_2D',...
%     'CC_H19_1D','CC_H19_2D','CC_H22_1D','CC_H22_2D','CC_H23_1D','CC_H23_2D'
%     };

% 1D Control Group
FileNames{1} = {'CC_H01_1D','CC_H03_1D','CC_H07_1D','CC_H09_1D'};
% 1D Poloski Group
FileNames{2} = {'CC_H02_1D','CC_H04_1D','CC_H08_1D','CC_H14_1D','CC_H19_1D','CC_H23_1D'};
% 2D Sectora
FileNames{3} = {
    'CC_H01_2D','CC_H02_2D','CC_H03_2D','CC_H04_2D','CC_H06_2D',...
    'CC_H07_2D','CC_H08_2D','CC_H09_2D','CC_H11_2D','CC_H12_2D',...
    'CC_H13_2D','CC_H14_2D','CC_H19_2D','CC_H23_2D'
    };

PathMat = 'd:\_WORK\CC\MatPC\';
PathPreset = 'd:\_WORK\CC\Presets\';
PathOut = 'd:\_WORK\CC\PlaceCells\';

%% main
%% creating fields distribution
for file = 1:length(filenames)
    % loading data
    FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,filenames{file});
    FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,filenames{file});
    load(FilenameMat, 'Cell_IC', 'FieldsIC','SpikeFieldsReal','test_zone5','x_int_sm','y_int_sm');
    load(FilenamePreset);
    
    % fixing bug
    for field  = 1:length(SpikeFieldsReal)
        SpikeFieldsReal(field).x_mass_real = SpikeFieldsReal(field).x_mass_real(end);
        SpikeFieldsReal(field).y_mass_real = SpikeFieldsReal(field).y_mass_real(end);
    end
    
    % drawing centers of fields
    %     MainFrame = Options.GoodVideoFrame;
    MainFrame = round((uint8(ArenaAndObjects(2).maskborder*255) + uint8(ArenaAndObjects(3).maskborder*255) + uint8(ArenaAndObjects(4).maskborder*255) + uint8(Options.GoodVideoFrame))./2);
    MainFrame = insertShape(MainFrame,'filledcircle', [x_int_sm*Options.pxl2sm y_int_sm*Options.pxl2sm ones(length(x_int_sm),1)*MarkSizeT;],'Color','green','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
    for field = 1:length(SpikeFieldsReal)
        MainFrame = insertShape(MainFrame,'filledcircle', [SpikeFieldsReal(field).x_mass_real*Options.pxl2sm SpikeFieldsReal(field).y_mass_real*Options.pxl2sm MarkSizeF],'Color','red','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
    end
    
    imshow(MainFrame);
    title(strrep(filenames{file}, '_', '\_'), 'FontSize', FontSize);
    saveas(gcf, sprintf('%s%s_fields.png',PathOut,filenames{file}));
    delete(gcf);
end

%% common fields stat for 1D
FieldStat1DControl = struct('CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
FieldStat1DStripes = struct('CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
FieldStat2DSectors = struct('CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);

%%
for group = 1:length(FileNames)
    for mouse = 1:length(FileNames{group})
        
        % loading data
        FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,FileNames{group}{mouse});
        FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,FileNames{group}{mouse});
        load(FilenameMat, 'Cell_IC', 'FieldsIC','SpikeFieldsReal','test_zone5','MapFieldsIC','x_int_sm','y_int_sm');
        load(FilenamePreset);
        
        % creation struct
        FieldStat2DSectors.CellNumberAll = [FieldStat2DSectors.CellNumberAll; size(Cell_IC,2)];
        FieldStat2DSectors.CellNumberActivePercent = [FieldStat2DSectors.CellNumberActivePercent; sum(Cell_IC(7,:) > 5)/FieldStat2DSectors.CellNumberAll(mouse)*100];
        FieldStat2DSectors.FiringRate = [FieldStat2DSectors.FiringRate; (Cell_IC(7,:)/TimeSession*60)'];
        FieldStat2DSectors.FiringRateMean = [FieldStat2DSectors.FiringRateMean; mean(Cell_IC(7,:)/TimeSession*60)];
        FieldStat2DSectors.PlaceCellNumberPercent = [FieldStat2DSectors.PlaceCellNumberPercent; sum(Cell_IC(2,:))/FieldStat2DSectors.CellNumberAll(mouse)*100];
        FieldStat2DSectors.CellICAll = [FieldStat2DSectors.CellICAll; Cell_IC(6,~isnan(Cell_IC(6,:)))'];        
        FieldStat2DSectors.CellICAllMean = [FieldStat2DSectors.CellICAllMean; mean(Cell_IC(6,~isnan(Cell_IC(6,:))))];
        FieldStat2DSectors.CellICPlaceCells = [FieldStat2DSectors.CellICPlaceCells; mean(Cell_IC(6,Cell_IC(2,:)==1))];
        FieldStat2DSectors.FieldsNumber = [FieldStat2DSectors.FieldsNumber; size(FieldsIC,2)];
        FieldStat2DSectors.FieldsNumberPerNeuron = [FieldStat2DSectors.FieldsNumberPerNeuron; test_zone5(test_zone5>0)'];
        FieldStat2DSectors.FieldsNumberPerNeuronMean = [FieldStat2DSectors.FieldsNumberPerNeuronMean; mean(test_zone5(test_zone5>0))];
        FieldStat2DSectors.FieldsSquare = [FieldStat2DSectors.FieldsSquare; sum((reshape(MapFieldsIC, [], size(MapFieldsIC, 3))>0))'];
        FieldStat2DSectors.FieldsSquareMean = [FieldStat2DSectors.FieldsSquareMean; mean(sum((reshape(MapFieldsIC, [], size(MapFieldsIC, 3))>0)))];
        
        clear 'Cell_IC' 'FieldsIC' 'SpikeFieldsReal' 'test_zone5' 'MapFieldsIC' 'x_int_sm' 'y_int_sm';
        
    end
end
%% histograms

%% for stripes specific stats
PathOut = 'd:\_WORK\CC\FieldsDistrib\';
StripeStat = struct('PlaceFieldsIndexCenter',[],'PlaceFieldsIndexBorder',[],'PlaceFieldsNumberCenter',[],'PlaceFieldsNumberBorder',[],'PlaceFieldsNumberCenterPercent',[],'PlaceFieldsNumberBorderPercent',[],'FiringRate',[],'CellIC',[],'FieldsSquare',[]);
for group = 1
    for mouse = 1:length(FileNames{group})
        
        % loading data
        FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,FileNames{group}{mouse});
        FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,FileNames{group}{mouse});
        load(FilenameMat, 'Cell_IC', 'FieldsIC','SpikeFieldsReal','test_zone5','MapFieldsIC','x_int_sm','y_int_sm');
        load(FilenamePreset);
        
        % fixing bug
        for field  = 1:length(SpikeFieldsReal)
            SpikeFieldsReal(field).x_mass_real = round(SpikeFieldsReal(field).x_mass_real(end)*Options.pxl2sm);
            SpikeFieldsReal(field).y_mass_real = round(SpikeFieldsReal(field).y_mass_real(end)*Options.pxl2sm);
        end      
        
        BWDMask = bwdist(~ArenaAndObjects(1).maskfilled);  
        BWDMask(BWDMask<CenterDiam*Options.pxl2sm) = 0;
        
        BWDMask(BWDMask>0) = 1;
        
%         MainFrame = uint8((Options.GoodVideoFrame+uint8(BWDMask.*255))./2);
%         imshow(MainFrame);
        
        FieldsCenter = [];
        FieldsBorder = [];
        for field  = 1:size(SpikeFieldsReal,2)
            if BWDMask(SpikeFieldsReal(field).y_mass_real,SpikeFieldsReal(field).x_mass_real)
                FieldsCenter = [FieldsCenter field];
            else
                FieldsBorder = [FieldsBorder field];
            end            
        end
        StripeStat.PlaceFieldsIndexCenter = [StripeStat.PlaceFieldsIndexCenter; FieldsCenter'];
        StripeStat.PlaceFieldsIndexBorder = [StripeStat.PlaceFieldsIndexBorder; FieldsBorder'];
        
        x_mass_real = [];
        y_mass_real = [];
        for field  = 1:size(SpikeFieldsReal,2)
            x_mass_real = [x_mass_real; SpikeFieldsReal(field).x_mass_real];
            y_mass_real = [y_mass_real; SpikeFieldsReal(field).y_mass_real];
        end
        
        h = figure;
        plot(x_mass_real(FieldsCenter),y_mass_real(FieldsCenter), 'r*', 'MarkerSize',5);hold on;
        plot(x_mass_real(FieldsBorder),y_mass_real(FieldsBorder), 'k*', 'MarkerSize',5);
        saveas(h, sprintf('%s%s_stripes.png',PathOut,FileNames{group}{mouse}));
        delete(h);

        StripeStat.PlaceFieldsNumberCenter = [StripeStat.PlaceFieldsNumberCenter; length(FieldsCenter)];
        StripeStat.PlaceFieldsNumberBorder = [StripeStat.PlaceFieldsNumberBorder; length(FieldsBorder)];
        
        StripeStat.PlaceFieldsNumberCenterPercent = [StripeStat.PlaceFieldsNumberCenterPercent; length(FieldsCenter)/size(SpikeFieldsReal,2)*100];
        StripeStat.PlaceFieldsNumberBorderPercent = [StripeStat.PlaceFieldsNumberBorderPercent; length(FieldsBorder)/size(SpikeFieldsReal,2)*100];
        
    end
end

StripeStat1DControl = StripeStat;
% StripeStat1DStripes = StripeStat;
%% 
FieldStat1DControl.CellIndex = [ones(342,1);ones(428,1)*2;ones(150,1)*3;ones(607,1)*4];
FieldStat1DStripes.CellIndex = [ones(572,1);ones(516,1)*2;ones(390,1)*3;ones(418,1)*4;ones(590,1)*5;ones(1360,1)*6];

numbers = [221, 595, 280, 218, 220, 329, 559, 391, 348, 392, 534, 636, 656, 1017];
CellIndex = [];
for i = 1:numel(numbers)
    CellIndex = [CellIndex; ones(numbers(i), 1) * i];
end
FieldStat2DSectors.CellIndex = CellIndex;

%% for sectors specific stats
PathOut = 'd:\_WORK\CC\FieldsDistrib\';
StripeStat = struct('PlaceFieldsIndex',[],'PlaceFieldsNumber',[],'FiringRate',[],'CellIC',[],'FieldsSquare',[]);
Sectors = [];
for group = 3
    for mouse = 1:length(FileNames{group})
        
        % loading data
        FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,FileNames{group}{mouse});
        FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,FileNames{group}{mouse});
        load(FilenameMat, 'Cell_IC', 'FieldsIC','SpikeFieldsReal','test_zone5','MapFieldsIC','x_int_sm','y_int_sm');
        load(FilenamePreset);
        
        % fixing bug
        for field  = 1:length(SpikeFieldsReal)
            SpikeFieldsReal(field).x_mass_real = round(SpikeFieldsReal(field).x_mass_real(end)*Options.pxl2sm);
            SpikeFieldsReal(field).y_mass_real = round(SpikeFieldsReal(field).y_mass_real(end)*Options.pxl2sm);
        end
        
        FieldsSectors = zeros(size(SpikeFieldsReal,2),6);
        for field  = 1:size(SpikeFieldsReal,2)
            for sector = 1:6
                if ArenaAndObjects(sector+1).maskfilled(SpikeFieldsReal(field).y_mass_real,SpikeFieldsReal(field).x_mass_real)
                    FieldsSectors(field,sector) = field;
                end
            end            
        end

        StripeStat(mouse).PlaceFieldsIndex = {FieldsSectors(FieldsSectors(:,1)>0,1)...
            FieldsSectors(FieldsSectors(:,2)>0,2) FieldsSectors(FieldsSectors(:,3)>0,3)...
            FieldsSectors(FieldsSectors(:,4)>0,4) FieldsSectors(FieldsSectors(:,5)>0,5)...
            FieldsSectors(FieldsSectors(:,6)>0,6)};   
        
        x_mass_real = [];
        y_mass_real = [];
        for field  = 1:size(SpikeFieldsReal,2)
            x_mass_real = [x_mass_real; SpikeFieldsReal(field).x_mass_real];
            y_mass_real = [y_mass_real; SpikeFieldsReal(field).y_mass_real];
        end
        
        h = figure;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 1}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,1}), 'r*', 'MarkerSize',5);hold on;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 2}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,2}), 'k*', 'MarkerSize',5);hold on;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 3}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,3}), 'g*', 'MarkerSize',5);hold on;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 4}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,4}), 'b*', 'MarkerSize',5);
        saveas(h, sprintf('%s%s_stripes.png',PathOut,FileNames{group}{mouse}));
        delete(h);
        
%         StripeStat(mouse).PlaceFieldsNumber = [...
%             length(StripeStat(mouse).PlaceFieldsIndex{1,1})/size(SpikeFieldsReal,2)*100 ...
%             length(StripeStat(mouse).PlaceFieldsIndex{1,2})/size(SpikeFieldsReal,2)*100 ...
%             length(StripeStat(mouse).PlaceFieldsIndex{1,3})/size(SpikeFieldsReal,2)*100 ...
%             length(StripeStat(mouse).PlaceFieldsIndex{1,4})/size(SpikeFieldsReal,2)*100 ...
%             length(StripeStat(mouse).PlaceFieldsIndex{1,5})/size(SpikeFieldsReal,2)*100 ...
%             length(StripeStat(mouse).PlaceFieldsIndex{1,6})/size(SpikeFieldsReal,2)*100 ...
%             ];
        
        StripeStat(mouse).PlaceFieldsNumber = [...
            length(StripeStat(mouse).PlaceFieldsIndex{1,1}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,2}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,3}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,4}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,5}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,6}) ...
            ];
        
        Sectors = [Sectors;StripeStat(mouse).PlaceFieldsNumber];
    end
end

% StripeStat1DControl = StripeStat;
% StripeStat1DStripes = StripeStat;
StripeStat2DSectors = StripeStat;
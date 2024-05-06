%% parameters
MarkSizeF = 7;
MarkSizeT = 2;
FontSize = 15;
TimeSession = 600; % 600 second 
bin_size = 7; % in sm
CenterDiam = (98-78)/2; % in sm
%% paths and names
% all recirded mice
% filenames = {
%     'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
%     'CC_H04_1D','CC_H04_2D','CC_H05_1D','CC_H05_2D','CC_H06_1D','CC_H06_2D',...
%     'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
%     'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D','CC_H12_1D','CC_H12_2D',...
%     'CC_H13_1D','CC_H13_2D','CC_H14_1D','CC_H14_2D','CC_H15_1D','CC_H15_2D',...
%     'CC_H16_1D','CC_H16_2D','CC_H17_1D','CC_H17_2D',...
%     'CC_H19_1D','CC_H19_2D','CC_H22_1D','CC_H22_2D','CC_H23_1D','CC_H23_2D'
%     };

% only behavior and calcium mice good enough for Nikita's diploma
filenames = {
    'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
    'CC_H04_1D','CC_H04_2D','CC_H06_2D',...
    'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
    'CC_H11_2D','CC_H12_2D',...
    'CC_H13_2D','CC_H14_1D','CC_H14_2D',...
    'CC_H19_1D','CC_H19_2D','CC_H23_1D','CC_H23_2D'
    };

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

PathMat = 'd:\Projects\СС\MATPCNew\MAT_3sigma\';
PathPreset = 'd:\Projects\СС\Presets\';
PathOut = 'd:\Projects\СС\PlaceCells\3sigma\';

%% main
%% creating fields distribution
for file = 1:length(filenames)
    % loading data
    FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,filenames{file});
    FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,filenames{file});
    load(FilenameMat, 'Cell_IC', 'FieldsIC','SpikeFieldsReal','test_zone5','x_int_sm','y_int_sm');
    load(FilenamePreset);
    
%     % fixing bug
%     for field  = 1:length(SpikeFieldsReal)
%         SpikeFieldsReal(field).x_mass_real = SpikeFieldsReal(field).x_mass_real(end);
%         SpikeFieldsReal(field).y_mass_real = SpikeFieldsReal(field).y_mass_real(end);
%     end
    
    % drawing centers of fields
    %     MainFrame = Options.GoodVideoFrame;
    %     MainFrame = round((uint8(ArenaAndObjects(2).maskborder*255) + uint8(ArenaAndObjects(3).maskborder*255) + uint8(ArenaAndObjects(4).maskborder*255) + uint8(Options.GoodVideoFrame))./2);
    
    MainFrame = ind2rgb(Options.GoodVideoFrame, gray(256));
    MainFrame = insertShape(MainFrame,'filledcircle', [x_int_sm*Options.pxl2sm y_int_sm*Options.pxl2sm ones(length(x_int_sm),1)*MarkSizeT;],'Color','green','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
    for field = 1:length(SpikeFieldsReal)
        MainFrame = insertShape(MainFrame,'filledcircle', [SpikeFieldsReal(field).x_mass_real*Options.pxl2sm SpikeFieldsReal(field).y_mass_real*Options.pxl2sm MarkSizeF],'Color','red','LineWidth',1, 'Opacity', 1, 'SmoothEdges', false);
    end    
    imshow(MainFrame);
    hold on; 
    for object  = 2:size(ArenaAndObjects,2)
        plot(ArenaAndObjects(object).border_x, ArenaAndObjects(object).border_y, 'k', 'LineWidth', 1);
        hold on;
    end
    title(strrep(filenames{file}, '_', '\_'), 'FontSize', FontSize);
    saveas(gcf, sprintf('%s%s_fields.png',PathOut,filenames{file}));
    delete(gcf);
end

%% common fields stat
% FieldStat1DControl = struct('CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
% FieldStat1DStripes = struct('CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
% FieldStat2DSectors = struct('CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
FieldStat{1} = struct('CellIndex',[],'CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
FieldStat{2} = struct('CellIndex',[],'CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);
FieldStat{3} = struct('CellIndex',[],'CellNumberAll',[],'CellNumberActivePercent',[],'FiringRate',[],'FiringRateMean',[],'PlaceCellNumberPercent',[],'CellICAll',[],'CellICAllMean',[],'CellICPlaceCells',[],'FieldsNumber',[],'FieldsNumberPerNeuron',[],'FieldsNumberPerNeuronMean',[],'FieldsSquare',[],'FieldsSquareMean',[]);

for group = 1:length(FileNames)
    for mouse = 1:length(FileNames{group})
        
        % loading data
        FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,FileNames{group}{mouse});
        FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,FileNames{group}{mouse});
        load(FilenameMat, 'Cell_IC', 'FieldsIC','test_zone5','MapFieldsIC');
        load(FilenamePreset);
        
        % creation struct
        FieldStat{group}.CellIndex = [FieldStat{group}.CellIndex; ones(size(Cell_IC,2),1)*mouse];
        FieldStat{group}.CellNumberAll = [FieldStat{group}.CellNumberAll; sum(Cell_IC(7,:) > 5)];
        FieldStat{group}.CellNumberActivePercent = [FieldStat{group}.CellNumberActivePercent; sum(Cell_IC(7,:) > 5)/size(Cell_IC,2)*100];
        FieldStat{group}.FiringRate = [FieldStat{group}.FiringRate; (Cell_IC(7,:)/TimeSession*60)'];
        FieldStat{group}.FiringRateMean = [FieldStat{group}.FiringRateMean; mean(Cell_IC(7,:)/TimeSession*60)];
        FieldStat{group}.PlaceCellNumberPercent = [FieldStat{group}.PlaceCellNumberPercent; sum(Cell_IC(2,:))/FieldStat{group}.CellNumberAll(mouse)*100];
        FieldStat{group}.CellICAll = [FieldStat{group}.CellICAll; Cell_IC(6,~isnan(Cell_IC(6,:)))'];        
        FieldStat{group}.CellICAllMean = [FieldStat{group}.CellICAllMean; mean(Cell_IC(6,~isnan(Cell_IC(6,:))))];
        FieldStat{group}.CellICPlaceCells = [FieldStat{group}.CellICPlaceCells; mean(Cell_IC(6,Cell_IC(2,:)==1))];
        FieldStat{group}.FieldsNumber = [FieldStat{group}.FieldsNumber; size(FieldsIC,2)];
        FieldStat{group}.FieldsNumberPerNeuron = [FieldStat{group}.FieldsNumberPerNeuron; test_zone5(test_zone5>0)'];
        FieldStat{group}.FieldsNumberPerNeuronMean = [FieldStat{group}.FieldsNumberPerNeuronMean; mean(test_zone5(test_zone5>0))];
        FieldStat{group}.FieldsSquare = [FieldStat{group}.FieldsSquare; (sum((reshape(MapFieldsIC, [], size(MapFieldsIC, 3))>0)).*bin_size^2/100)']; % in dm^2
        FieldStat{group}.FieldsSquareMean = [FieldStat{group}.FieldsSquareMean; mean(sum((reshape(MapFieldsIC, [], size(MapFieldsIC, 3))>0)).*bin_size^2/100)];
        
        clear 'Cell_IC' 'FieldsIC' 'SpikeFieldsReal' 'test_zone5' 'MapFieldsIC' 'x_int_sm' 'y_int_sm';
        
    end
end
%% histograms

%% for stripes specific stats
PathOut = 'd:\Projects\СС\FieldsDistrib\3sigma\';
StripeStat = struct('PlaceFieldsIndexCenter',[],'PlaceFieldsIndexBorder',[],'PlaceFieldsNumberCenter',[],'PlaceFieldsNumberBorder',[],'PlaceFieldsNumberCenterPercent',[],'PlaceFieldsNumberBorderPercent',[],'FiringRate',[],'CellIC',[],'FieldsSquare',[]);
for group = 1
    for mouse = 1:length(FileNames{group})
        
        % loading data
        FilenameMat = sprintf('%sWorkSpace_%s_Features.mat',PathMat,FileNames{group}{mouse});
        FilenamePreset = sprintf('%s%s_Preset.mat',PathPreset,FileNames{group}{mouse});
        load(FilenameMat, 'Cell_IC', 'FieldsIC','SpikeFieldsReal','test_zone5','MapFieldsIC','x_int_sm','y_int_sm');
        load(FilenamePreset);
        
%         % fixing bug
%         for field  = 1:length(SpikeFieldsReal)
%             SpikeFieldsReal(field).x_mass_real = round(SpikeFieldsReal(field).x_mass_real(end)*Options.pxl2sm);
%             SpikeFieldsReal(field).y_mass_real = round(SpikeFieldsReal(field).y_mass_real(end)*Options.pxl2sm);
%         end      
        
        BWDMask = bwdist(~ArenaAndObjects(1).maskfilled);  
        BWDMask(BWDMask<CenterDiam*Options.pxl2sm) = 0;
        
        BWDMask(BWDMask>0) = 1;
        
%         MainFrame = uint8((Options.GoodVideoFrame+uint8(BWDMask.*255))./2);
%         imshow(MainFrame);
        
        FieldsCenter = [];
        FieldsBorder = [];
        for field  = 1:size(SpikeFieldsReal,2)
            if BWDMask(round(SpikeFieldsReal(field).y_mass_real*Options.pxl2sm),round(SpikeFieldsReal(field).x_mass_real*Options.pxl2sm))
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
        MainFrame = ind2rgb(Options.GoodVideoFrame, gray(256));
        imshow(MainFrame);
        hold on;
        for object  = 2:size(ArenaAndObjects,2)
            plot(ArenaAndObjects(object).border_x, ArenaAndObjects(object).border_y, 'k', 'LineWidth', 1);
            hold on;
        end
        plot(x_mass_real(FieldsCenter)*Options.pxl2sm,y_mass_real(FieldsCenter)*Options.pxl2sm, 'r*', 'MarkerSize',5);hold on;
        plot(x_mass_real(FieldsBorder)*Options.pxl2sm,y_mass_real(FieldsBorder)*Options.pxl2sm, 'g*', 'MarkerSize',5);
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
% FieldStat1DControl.CellIndex = [ones(342,1);ones(428,1)*2;ones(150,1)*3;ones(607,1)*4];
% FieldStat1DStripes.CellIndex = [ones(572,1);ones(516,1)*2;ones(390,1)*3;ones(418,1)*4;ones(590,1)*5;ones(1360,1)*6];
% 
% numbers = [221, 595, 280, 218, 220, 329, 559, 391, 348, 392, 534, 636, 656, 1017];
% CellIndex = [];
% for i = 1:numel(numbers)
%     CellIndex = [CellIndex; ones(numbers(i), 1) * i];
% end
% FieldStat2DSectors.CellIndex = CellIndex;

%% for sectors specific stats

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
        
        FieldsSectors = zeros(size(SpikeFieldsReal,2),4);
        for field  = 1:size(SpikeFieldsReal,2)
            for sector = 1:4
                if ArenaAndObjects(sector+1).maskfilled(SpikeFieldsReal(field).y_mass_real,SpikeFieldsReal(field).x_mass_real)
                    FieldsSectors(field,sector) = field;
                end
            end            
        end

        StripeStat(mouse).PlaceFieldsIndex = {FieldsSectors(FieldsSectors(:,1)>0,1)...
            FieldsSectors(FieldsSectors(:,2)>0,2) FieldsSectors(FieldsSectors(:,3)>0,3)...
            FieldsSectors(FieldsSectors(:,4)>0,4) };   
        
        x_mass_real = [];
        y_mass_real = [];
        for field  = 1:size(SpikeFieldsReal,2)
            x_mass_real = [x_mass_real; SpikeFieldsReal(field).x_mass_real];
            y_mass_real = [y_mass_real; SpikeFieldsReal(field).y_mass_real];
        end
        
        h = figure;
        
        MainFrame = ind2rgb(Options.GoodVideoFrame, gray(256));
        imshow(MainFrame);
        hold on;
        for object  = 2:size(ArenaAndObjects,2)
            plot(ArenaAndObjects(object).border_x, ArenaAndObjects(object).border_y, 'k', 'LineWidth', 1);
            hold on;
        end
        
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 1}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,1}), 'r*', 'MarkerSize',5);hold on;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 2}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,2}), 'k*', 'MarkerSize',5);hold on;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 3}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,3}), 'g*', 'MarkerSize',5);hold on;
        plot(x_mass_real(StripeStat(mouse).PlaceFieldsIndex{1, 4}),y_mass_real(StripeStat(mouse).PlaceFieldsIndex{1,4}), 'b*', 'MarkerSize',5);
        saveas(h, sprintf('%s%s_stripes.png',PathOut,FileNames{group}{mouse}));
        delete(h);
        
        StripeStat(mouse).PlaceFieldsNumber = [...
            length(StripeStat(mouse).PlaceFieldsIndex{1,1}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,2}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,3}) ...
            length(StripeStat(mouse).PlaceFieldsIndex{1,4}) ...
            ];
        
        Sectors = [Sectors;StripeStat(mouse).PlaceFieldsNumber];
    end
end

% StripeStat1DControl = StripeStat;
% StripeStat1DStripes = StripeStat;
StripeStat2DSectors = StripeStat;

%%
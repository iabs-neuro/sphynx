%% paths and names
% если дата не синхронизирована, все равно можно запускать, тогда в 11
% строчке PlaceFieldAnalyzer указать 'FC' в переменной CorrectionTrackMode


%указать свой путь к папке, где будут спайки и координаты и доп файл с
%координатами
path = 'd:\OR_2023\_Calcium\';

%указать все имена файлов
filenames = {
    'M5',...
    'M14',...
    'M16',...
    'M22old',...
    'M27old'...
%     'M20old',...
%     'M21old',...
%     'M22old',...
%     'M25old',...
%     'M27old'
};
session = {'Predtrain','Test'};
filename_V = 'ArenaAndCupsCoord.txt';
CellsInformZscore = [];
CellsInformNumber = [];
%% main part
for exp = 1:2
    for file = 1:length(filenames)
        % маски для названий файлов
        
        % для координат
        filename = sprintf('%s_%s_coord.csv', filenames{file}, session{exp});
        %для спайков
        filenameNV = sprintf('spikes_%s_%s.csv', filenames{file}, session{exp});
        
        [CellsInformThis] = PlaceFieldAnalyzer(path, filename, filenameNV, filename_V, 1, 1, 0, 0,'IC_orig');
        if ~isempty(CellsInformThis)
            CellsInformNumber(exp,file) = size(CellsInformThis,2);
            CellsInformZscore = [CellsInformZscore CellsInformThis(7,:)];
        end
    end
end
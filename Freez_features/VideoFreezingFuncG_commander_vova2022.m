%commander for freezing calculation 
%%
dlg_data = inputdlg({'How many folders do you want calculate?'}, 'Parameters', 1, {'1'});
FoldersCount = str2num(dlg_data{1});
path = cell(1,FoldersCount);

for folder = 1:FoldersCount 
    [~, path{folder}] = uigetfile('*.wmv','Select some file', 'g:\_Projects\_APTSD [2022]\APTSD\Video\');
end
%%
for folder = 1:FoldersCount    
    files = dir(sprintf('%s\\*.wmv',path{folder}));
    n_files = length(files);    
    for file = 1:n_files 
        
%         % test and generalized
%         [comp5] = VideoFreezingFuncG(files(file).folder,files(file).name, 3, '180','180', 13, 5, 30, 15, 144);
%         Component5test(folder,file) = round(comp5(2));
%    
        % sens
        [comp5] = VideoFreezingFuncG(files(file).folder,files(file).name, 3, '300','300', 13, 5, 30, 15, 150);
        Component5test(file) = round(comp5);
        
%         Component5test(2,file) = round(comp5(2,2));
%         if file <6
%             % train (good sessions)
            [comp5] = VideoFreezingFuncG(files(file).folder,files(file).name, 3, '170 10 50 10 50 10 60','170 10 50 10 50 10 60', 13, 5, 30, 15, 144);
%             Component5test(folder,file) = round(comp5(2));
%         else            
%             % train (bad session)
%             [comp5] = VideoFreezingFuncG(files(file).folder,files(file).name, 3, '170 10 50 10 25','170 10 50 10 25', 13, 5, 30, 15, 144);
%             Component5test(folder,file) = round(comp5(2));
%         end
        
    %   [comp5] = VideoFreezingFuncG(files(file).folder,files(file).name,3, '170 10 50','170 10 50', 13, 5, 18, 15, 144);
    end   
%     path{folder}
%     files.name
%     Component(folder,:)
end


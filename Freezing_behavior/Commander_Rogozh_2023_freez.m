%commander for freezing calculation 
%%
dlg_data = inputdlg({'How many folders do you want calculate?'}, 'Parameters', 1, {'1'});
FoldersCount = str2double(dlg_data{1});
path = cell(1,FoldersCount);

lvl = [130 130 130 130 130 130 130 130 130 130 130 130 130 130 130 130 130 130 130 130];

for folder = 1:FoldersCount
    [~, path{folder}] = uigetfile('*.wmv','Select some file', 'g:\_Projects\_APTSD [2022]\APTSD\Video\');
end

%%
for folder = 1:FoldersCount
    files = dir(sprintf('%s\\*.wmv',path{folder}));
    n_files = length(files);
    FreezAll = zeros(1,n_files);
    for file = 1:n_files
        [Freez] = VideoFreezingFuncG(1, files(file).folder,files(file).name, 3, '300','300', 13, 5, 30, 15, lvl(file));
        FreezAll(file) = round(Freez(2,1));
    end
end


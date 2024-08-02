%%
Path = 'g:\_OtherProjects\STFP\_Features\Features_sync\';
PathOut = 'g:\_OtherProjects\STFP\_Features\Features_sync_LocPlace\';
FileNames = {'STFP1_D6','STFP3_D6','STFP4_D3','STFP9_D6'};

%% main part
for file = 1:length(FileNames) 
    
    fprintf(FileNames{file});
    FileName = sprintf('%s_Features.csv', FileNames{file});
    
    %% loading data
    FeaturesTable = readtable(sprintf('%s%s', Path,FileName));
    Features = table2array(FeaturesTable);
    [~,fileDLC,~] = xlsread(sprintf('%s%s', Path,FileName));
    FilenameOut = FileName;    
    
    %% calculation coordinate features during locomotion
    X_new = Features(:,1).*Features(:,8);
    Y_new = Features(:,1).*Features(:,8);
    X_new(X_new == 0) = NaN;
    Y_new(Y_new == 0) = NaN;
    
    Features = [Features X_new Y_new];
    
    %% save    
    % Создание числовых массивов и ячеек с заголовками
    headers1 = strsplit(fileDLC{1},',');
    headers1 = [headers1 'xlocomotion' 'ylocomotion'];
    
    % Запись заголовков в первые три строчки
    name = sprintf('%s%s',PathOut,FilenameOut);
    writecell(headers1, name, 'WriteMode', 'append');
    writematrix(Features, name, 'WriteMode', 'append');

end

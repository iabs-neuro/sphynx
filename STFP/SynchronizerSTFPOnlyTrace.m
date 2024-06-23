function SynchronizerSTFPOnlyTrace(Path,PathOut, filename)
% переделать для синхронизации фич, а не трека DLC
% 16.01.24 vvp
% снчала сделал анализ, а потом фичи синхронизую, без тресов кальция. фичи
% подрезаны под app и disapp
% 14.06.24 проверено

%% defining all vital parameters

CorrectionTrackMode = 'NVista'; % {'NVista', 'FC', 'none'} for different mode of correction sync
t_kcorr = 4000; %correction coefficient for VT and NV time distortion for 'NVista' (1 frame on t_kcorr frames screwing)

%%
if nargin<3
    %%    
    [filename, Path]  = uigetfile('*.csv','Load the FEATURES file','g:\_OtherProjects\STFP\_Features\');
    PathOut = 'g:\_OtherProjects\STFP\_Features\_Features_sync\';
end

%% loading data

file = readtable(sprintf('%s%s', Path,filename));

[~,fileDLC,~] = xlsread(sprintf('%s%s', Path,filename));

FilenameOut = filename;

%% Preparing data
y_orig = table2array(file);

% correction of time distortion NV and VT
switch CorrectionTrackMode
    case 'NVista'
        k = 1;        
        y_bad = [];
        for i=1:length(y_orig)
            if mod(i, t_kcorr) ~= 0
                y_bad(k,:) = y_orig(i,:);
                k=k+1;
            end
        end     
end

%% save

% Создание числовых массивов и ячеек с заголовками
headers1 = strsplit(fileDLC{1},',');

% Запись заголовков в первые три строчки
name = sprintf('%s%s',PathOut,FilenameOut);
writecell(headers1, name, 'WriteMode', 'append');
writematrix(y_bad, name, 'WriteMode', 'append');

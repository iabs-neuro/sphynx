function SynchronizerSTFP(path, filename, filenameNV, filename_V, start, app, endd, n_objects, field_method)

%% defining all vital parameters
PathOut = 'G:\_Projects\STFP\Behavior\';
FilenameCut = 4; % cut x symbol from filename for main filename
CorrectionTrackMode = 'NVista'; % {'NVista', 'FC', 'none'} for different mode of correction sync
t_kcorr = 4000; %correction coefficient for VT and NV time distortion for 'NVista' (1 frame on t_kcorr frames screwing)

%% 
if nargin<9
    %%
    %loading videotracking
    [filename, path]  = uigetfile('*.csv','load the VT file','f:\_Projects\STFP\_RESULTS\STFP_1\D6\');
    
    %loading spike file
    [filenameNV, ~]  = uigetfile('*.csv','load the spikes','f:\_Projects\STFP\_RESULTS\STFP_1\D6\');
      
    %loading neuro file
    [filename_V, ~]  = uigetfile('*.csv','load the neuro','f:\_Projects\STFP\_RESULTS\STFP_1\D6\'); 
    
    %time and criteria parameters 
    prompt = {'Time of VideoTracking start', 'Appearance time', 'Endings time', 'Number of objects', 'Place Field method calculation {Peak,IC_orig,IC_multi}'}; 
    default_data = {'192', '970', '73188', '0', 'IC_orig'};
    options.Resize='on';
    dlg_data = inputdlg(prompt, 'Parameters', 1, default_data, options);
    start = str2num(dlg_data{1});
    app = str2num(dlg_data{2});
    endd = str2num(dlg_data{3});
    n_objects = str2num(dlg_data{4});
    field_method = dlg_data{5};    
end

%% loading data
% file = load(sprintf('%s%s', path, filename));
file = readtable(sprintf('%s%s', path,filename));

[~,fileDLC,~] = xlsread(sprintf('%s%s', path,filename));

file_NV_bad = load(sprintf('%s%s', path, filenameNV));
file_V_bad = load(sprintf('%s%s', path, filename_V));

% FilenameOut = filename(1:end-FilenameCut);
FilenameOut = filename(1:11);

%% Preparing data

if endd == 0
    end_track = size(file,1);
    end_spike = size(file_NV_bad,1);
else
    end_track = endd;
end

y_orig = table2array(file(app:end_track, :));

% correction of time distortion NV and VT
switch CorrectionTrackMode
    case 'NVista'
        k = 1;x_bad = [];y_bad = [];
        for i=1:length(y_orig)
            if mod(i, t_kcorr) ~= 0
                y_bad(k,:) = y_orig(i,:);
                k=k+1;
            end
        end     
end

n_frames=length(y_bad);
NV_start = app-start+1;
file_NV = file_NV_bad(NV_start:NV_start+n_frames-1,:);
file_V = file_V_bad(NV_start:NV_start+n_frames-1,:);

%% save
csvwrite(sprintf('%s\\_NeuroTraces\\%s_neuro.csv',PathOut,FilenameOut), file_V);
csvwrite(sprintf('%s\\_NeuroSpikes\\%s_spikes.csv',PathOut,FilenameOut), file_NV);

% Создание числовых массивов и ячеек с заголовками
headers1 = strsplit(fileDLC{1},',');
headers2 = strsplit(fileDLC{2},',');
headers3 = strsplit(fileDLC{3},',');
headers4 = strsplit(fileDLC{4},',');

% Запись заголовков в первые три строчки
name = sprintf('%s\\_Tracks\\%s_traces.csv',PathOut,FilenameOut);
writecell(headers1(1:end), name, 'WriteMode', 'append');
writecell(headers2(1:end), name, 'WriteMode', 'append');
writecell(headers3(1:end), name, 'WriteMode', 'append');
writecell(headers4(1:end), name, 'WriteMode', 'append');
writematrix(y_bad(:, 1:end), name, 'WriteMode', 'append');

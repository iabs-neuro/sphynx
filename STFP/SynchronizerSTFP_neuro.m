function SynchronizerSTFP_neuro(path_track,filename,path_neuro, filename_V, start, app)

%% defining all vital parameters
PathOut = 'i:\_STFP\_CalciumData\Traces_sync\';

%% 
if nargin<6
    %%
    %loading videotracking
    [filename, path_track]  = uigetfile('*.csv','load the VT file','i:\_STFP\_VideoData\5_Features\');
    
     %loading neuro file
    [filename_V, path_neuro]  = uigetfile('*.csv','load the neuro','i:\_STFP\_CalciumData\Traces\'); 

    %time and criteria parameters 
    prompt = {'Time of VideoTracking start', 'Appearance time', 'Endings time'}; 
    default_data = {'391', '1560', '73782'};
    options.Resize='on';
    dlg_data = inputdlg(prompt, 'Parameters', 1, default_data, options);
    start = str2num(dlg_data{1});
    app = str2num(dlg_data{2});
   
end

%% loading data
file = readtable(sprintf('%s%s', path_track,filename));
file_V_bad = load(sprintf('%s%s', path_neuro, filename_V));
FilenameOut = filename_V;

%% Preparing data

n_frames= size(file,1);
NV_start = app-start+1;
file_V = file_V_bad(NV_start:NV_start+n_frames-1,:);

%% save
csvwrite(sprintf('%s%s',PathOut,FilenameOut), file_V);



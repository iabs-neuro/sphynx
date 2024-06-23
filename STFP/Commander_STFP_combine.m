% 14.06.24 синхронизую 1,3,4 мышей всех сессий

Path = 'c:\Users\1\Projects\STFP\5.1_Features_not_sync\';
PathOut = 'c:\Users\1\Projects\STFP\5_Features\';
FileNames = {
    'A01_D1_T1','A01_D2_T1','A01_D3_T1','A01_D4_T1','A01_D5_T1','A01_D6_T1',...
    'A03_D1_T1','A03_D2_T1','A03_D3_T1','A03_D4_T1','A03_D5_T1','A03_D6_T1',...
    'A04_D1_T1','A04_D2_T1','A04_D3_T1','A04_D4_T1','A04_D5_T1','A04_D6_T1',...
    };

%% main part
% синхронизация фичей
for file = 1:length(FileNames)    
    fprintf(FileNames{file});
    FileName = sprintf('STFP_%s_Features.csv', FileNames{file});
    SynchronizerSTFPOnlyTrace(Path,PathOut, FileName);
end
%% синхронизация neuro (засинхронить фичи. потом по ним подрезать нейро)
path_track = 'c:\Users\1\Projects\STFP\5_Features\';
path_neuro = 'i:\_STFP\_CalciumData\Traces\';
start = [391,245,199,451,461,192,461,597,231,313,31,242,246,191,313,392,306,354];
app = [1560,920,900,720,1140,970,1233,1410,800,1317,920,1130,1300,1100,1050,1730,1160,1400];
% for file = 14:length(FileNames)    
for file = 13
    fprintf(FileNames{file});
    filename_V = sprintf('STFP_%s_traces.csv', FileNames{file});
%     filename = sprintf('STFP_%s_track.csv', FileNames{file});
    filename = sprintf('STFP_%s_Features.csv', FileNames{file});
    SynchronizerSTFP_neuro(path_track,filename,path_neuro, filename_V, start(file), app(file))
end

%% old version
% fprintf('STFP_3_D6');
% SynchronizerSTFP('F:\_Projects\STFP\_RESULTS\STFP_3\D6\', 'STFP3_D6.csv', 'spikes_recording_20191212_132531-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20191212_132531-000_corrected_neuropil_30_0.8.csv_conc.csv',  242, 1130, 73197, 0,'IC_orig');

% fprintf('STFP_4_D3');
% SynchronizerSTFP('F:\_Projects\STFP\_RESULTS\STFP_4\D3\', 'STFP4_D3.csv', 'spikes_recording_20200319_134444-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20200319_134444-000_corrected_neuropil_30_0.8.csv_conc.csv', 313, 1050, 73137, 0,'IC_orig');

% fprintf('STFP_5_D3');
% SynchronizerSTFP('F:\_Projects\STFP\_RESULTS\STFP_5\D3\', 'STFP5_D3.csv', 'spikes_recording_20200319_145500-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20200319_145500-000_corrected_neuropil_30_0.8.csv_conc.csv', 210, 1020, 73249, 0,'IC_orig');

% fprintf('STFP_7_D3');
% SynchronizerSTFP('F:\_Projects\STFP\_RESULTS\STFP_7\D3\', 'STFP7_D3.csv', 'spikes_recording_20200619_153957-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20200619_153957-000_corrected_neuropil_30_0.8.csv_conc.csv', 160, 600, 73685, 0,'IC_orig');

% fprintf('STFP_9_D6');
% SynchronizerSTFP('F:\_Projects\STFP\_RESULTS\STFP_9\D6\', 'STFP9_D6.csv', 'spikes_recording_20200628_150634-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20200628_150634-000_corrected_neuropil_30_0.8.csv_conc.csv', 143, 820, 26481, 0,'IC_orig');

% fprintf('STFP_1_D5_T2');
% SynchronizerSTFP('G:\_Projects\STFP\_RESULTS\STFP_1\D5_T2\', 'STFP1_D5_T2_traces.csv', 'spikes_recording_20191211_154559_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20191211_154559_corrected_neuropil_30_0.8.csv_conc.csv', 223, 900, 72525, 0,'IC_orig');
% fprintf('STFP_3_D5_T2');
% SynchronizerSTFP('G:\_Projects\STFP\_RESULTS\STFP_3\D5_T2\', 'STFP3_D5_T2_traces.csv', 'spikes_recording_20191211_170103-000_corrected_neuropil_30_0.8.csv_conc.csv','recording_20191211_170103-000_corrected_neuropil_30_0.8.csv_conc.csv', 334, 800, 72510, 0,'IC_orig');
% fprintf('STFP_4_D2_T2');
% SynchronizerSTFP('G:\_Projects\STFP\_RESULTS\STFP_4\D2_T2\', 'STFP4_D2_T2_traces.csv', 'spikes_recording_20200318_174531-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20200318_174531-000_corrected_neuropil_30_0.8.csv_conc.csv', 476, 1950, 73942, 0,'IC_orig');
% fprintf('STFP_9_D5_T2');
% SynchronizerSTFP('G:\_Projects\STFP\_RESULTS\STFP_9\D5_T2\', 'STFP9_D5_T2_traces.csv', 'spikes_recording_20200627_210159-000_corrected_neuropil_30_0.8.csv_conc.csv', 'recording_20200627_210159-000_corrected_neuropil_30_0.8.csv_conc.csv', 235, 850, 27836, 0,'IC_orig');

% SynchronizerSTFP('G:\_Projects\STFP\_RESULTS\STFP_7\D2_T2\', 'STFP_7_D2_T2_1_sm.csv_conc_correct.csv', 'spikes_recording_20200618_192213-000_corrected_neuropil_30_0.8.csv_conc.csv', 274, 760, 60799, 0,'IC_orig');

path = 'w:\Projects\NOL\BehaviorData\0_Raw_combined\';
pathout = 'w:\Projects\NOL\BehaviorData\1_Raw\';

filename = {
't1.avi'  't2.avi' 't3.avi' 't4.avi' 't5.avi' ...
'tr1.avi' 'tr2.avi' 'tr3.avi' 'tr4.avi' 'tr5.avi'
};
%% main

for file = 1:length(filename)
%     fprintf(' ');
   CroppVideo(path, filename{file}, pathout, 'division', 1024)
end
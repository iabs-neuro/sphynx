name0 = 'PTSD_FC_replays_22_12_2021 ';
path = 'e:\_Projects\Olya_freez [2021]\video_pkl\';
name = ['1_33'; '2_35'; '3_36';'4_37';'5_40';'6_43'; '7_44';'8_46'; '9_47';'10_51'; '11_54'; '12_56'; '13_34'; '14_38'; '15_39'; '16_41'; '17_42'; '18_45'; '19_48'; '20_50'; '21_53'; '22_55'; '23_57'; '24_58'; '25_59'];
% name = [33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,50,51,53,54,55,56,57,58,59];

% CompUp = '170 130 60';
% CompDown = '170 130 60';
% Freez(1:length(name), 1:3)=0;
for i=1:length(name)
    filename = sprintf('%s%s.wmv_MotInd_12.csv', name0, name(i));    
    FreezFilt(path,filename,name(i));
%     [comp] = FreezFilt(path,filename);
%     Freez(i,1) = comp(2,1);
%     Freez(i,2) = comp(2,3);
%     Freez(i,3) = comp(2,2);
end
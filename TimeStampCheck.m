%% paths and names
filenames = {
    'CC_H01_1D','CC_H01_2D','CC_H02_1D','CC_H02_2D','CC_H03_1D','CC_H03_2D',...
    'CC_H04_1D','CC_H04_2D','CC_H05_1D','CC_H05_2D','CC_H06_1D','CC_H06_2D',...
    'CC_H07_1D','CC_H07_2D','CC_H08_1D','CC_H08_2D','CC_H09_1D','CC_H09_2D',...
    'CC_H10_1D','CC_H10_2D','CC_H11_1D','CC_H11_2D','CC_H12_1D','CC_H12_2D',...
    'CC_H13_1D','CC_H13_2D','CC_H14_1D','CC_H14_2D','CC_H15_1D','CC_H15_2D',...
    'CC_H16_1D','CC_H16_2D','CC_H17_1D','CC_H17_2D',...
    'CC_H19_1D','CC_H19_2D','CC_H22_1D','CC_H22_2D','CC_H23_1D','CC_H23_2D'
    };
PathCA = 'd:\_WORK\CC\TimeStampsCalcium\';
PathBE = 'd:\_WORK\CC\TimeStampsBehavior\';

%% main
TSS = cell(1,length(filenames));
 for file = 1:length(filenames)
     TS_CA = readtable(sprintf('%s%s_timestamp.csv', PathCA, filenames{file}));
     TS_BE = readtable(sprintf('%s%s_VT_TS.csv', PathBE, filenames{file}));
     Ca = table2array(TS_CA);
     Beh = table2array(TS_BE);
     
     behd(1,1) = (Beh(2)-Beh(1))/10000000;
     behd(1,2) = (Beh(3)-Beh(2))/10000000;
     behd(1,3) = (Beh(4)-Beh(3))/10000000;
     
     behd(2,1) = (Ca(2)-Ca(1))/10000000;
     behd(2,2) = (Ca(3)-Ca(2))/10000000;
     behd(2,3) = (Ca(4)-Ca(3))/10000000;
     
     behd(3,1) = (Ca(1)-Beh(1))/10000000;
     behd(3,2) = (Ca(2)-Beh(2))/10000000;
     behd(3,3) = (Ca(3)-Beh(3))/10000000;
     
     behd(4,1) = (Ca(end)-Beh(end))/10000000;
     behd(4,2) = (Ca(end-1)-Beh(end-1))/10000000;
     behd(4,3) = (Ca(end-2)-Beh(end-2))/10000000;
     
     TSS{file} = behd;
     fprintf('%s: Отставание кальция в начале и в конце: %f %f\n', filenames{file}, behd(3,1),behd(4,1));
 end
 
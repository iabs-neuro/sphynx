%% paths and names

% % 1D
% filenames = {
%     'F01_1D', 'F06_1D', 'F08_1D', 'F12_1D', 'F05_1D', 'F19_1D', 'F11_1D',... % FAD-MK
%     'F20_1D', 'F04_1D', 'F07_1D', 'F14_1D', 'F09_1D', 'F10_1D', 'F15_1D',... % FAD-SL
%     'F26_1D', 'F29_1D', 'F34_1D', 'F36_1D', 'F38_1D', 'F31_1D', 'F41_1D', 'F53_1D', 'F54_1D',... % BL_MK
%     'F28_1D', 'F30_1D', 'F40_1D', 'F32_1D', 'F37_1D', 'F48_1D', 'F43_1D', 'F35_1D', 'F52_1D' % BL_SL
%     };

% 3D
filenames = {
    'F01_3D', 'F06_3D', 'F08_3D', 'F12_3D', 'F05_3D', 'F19_3D', 'F11_3D',... % FAD-MK
    'F20_3D', 'F04_3D', 'F07_3D', 'F14_3D', 'F09_3D', 'F10_3D', 'F15_3D',... % FAD-SL
    'F26_3D', 'F29_3D', 'F34_3D', 'F36_3D', 'F38_3D', 'F31_3D', 'F41_3D', 'F53_3D', 'F54_3D',... % BL_MK
    'F28_3D', 'F30_3D', 'F40_3D', 'F32_3D', 'F37_3D', 'F48_3D', 'F43_3D', 'F35_3D', 'F52_3D' % BL_SL
    };

% Filenames = {
%     'F28', 'F30', 'F40', 'F32', 'F37', 'F35', ...         % BL_SL
%     'F26', 'F34', 'F38', 'F31', 'F41', 'F53', 'F54',...   % BL_MK
%     'F20', 'F07', 'F14', 'F09',...                        % FAD-SL
%     'F01', 'F12', 'F19', 'F11'                            % FAD-MK
%     };


path = 'h:\H_mice\RFC_РНФ\VideoData\RFC_alldays\';

n_files = length(filenames);
Component_3D = zeros(1,n_files);

%% main commander

for file = 14:n_files
    fprintf('Psocessing of %s\n',filenames{file});
    filename = sprintf('RFC_%s.wmv', filenames{file});
    [comp] = VideoFreezingFuncG(1,path,filename, 3, '300','300', 13, 5, 30, 15, 144);
    Component_3D(file) = round(comp(2,1));
end

%% main commander (load)
%
% for file = 1:n_files
%     fprintf('Psocessing of %s\n',filenames{file});
%     filename = sprintf('RFC_%s.wmv', filenames{file});
%     load(sprintf('%s\\RFC_%s_WorkSpace_13_5_30_15.mat', path, filenames{file}), 'PctComponentTimeFreezing');
%     Component_1D(file) = round(PctComponentTimeFreezing(2,1));
% end

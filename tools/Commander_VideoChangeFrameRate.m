%% commander
pathvideo = 'e:\Projects\3DM\BehaviorData\2wave\2_Combined\';
filenames = {
    'J05_5D','J06_5D','J12_4D','J13_5D','J14_5D','J18_4D','J19_5D','J23_5D','J24_5D','J30_5D','J52_5D','J57_4D','J59_4D','J61_4D'
    };
newFrameRates = {91.5,89.5,66.0,66.0,91.2,87.7,66.0,91.2,66.0,91.2,66.0,88.3,66.0,66.0};

for file = 1:length(filenames)
    inputVideoPath = fullfile(pathvideo, sprintf('3DM_%s.mp4', filenames{file}));
    VideoChangeFrameRate(inputVideoPath, newFrameRates{file});
end

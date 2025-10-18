%% paths and filenames

Identificator = 'STFP';
PathVideo = 'i:\_STFP\_VideoData\1_RawData\';
PathDLC = 'i:\_STFP\_VideoData\2_DLC\';
PathOut = 'i:\_STFP\_VideoData\4_Sphynx\';

PathPreset = 'i:\_STFP\_VideoData\3_Presets\';

% for 2 cups sessions
FileNames = {
    'A01_D1_T1','A01_D2_T1','A01_D3_T1','A01_D4_T1','A01_D5_T1','A01_D6_T1',...
    'A03_D1_T1','A03_D2_T1','A03_D3_T1','A03_D4_T1','A03_D5_T1','A03_D6_T1',...
    'A04_D1_T1','A04_D2_T1','A04_D3_T1','A04_D4_T1','A04_D5_T1','A01_D6_T1',...
    };
StartTime = [1560,920,900,720,1140,970,1233,1410,800,1317,920,1130,1300,1100,1050,1730,1160,1400];
EndTime = [73782,26200,71869,73687,75063,73188,66897,73631,73962,73405,73129,73197,71066,73645,73137,73599,74940,73605];

% % for 2 mice session
% FileNames = {'A01_D5_T2','A03_D5_T2','A04_D2_T2'};
% StartTime = [900 800 1950];
% EndTime = [72525 72510 73942];

FilesNumber = length(FileNames);

%% variables initiation

% common features
FreezingPercent = zeros(1,FilesNumber);
FreezingNumber = zeros(1,FilesNumber);
FreezingMeanTime = zeros(1,FilesNumber);

% RearsPercent = zeros(1,FilesNumber);
% RearsNumber = zeros(1,FilesNumber);
% RearsMeanTime = zeros(1,FilesNumber);

RestOtherLocomotionPercent = zeros(3,FilesNumber);
RestOtherLocomotionNumber = zeros(3,FilesNumber);
RestOtherLocomotionMeanTime = zeros(3,FilesNumber);
RestOtherLocomotionDistance = zeros(3,FilesNumber);
RestOtherLocomotionMeanDistance = zeros(3,FilesNumber);
RestOtherLocomotionVelocity = zeros(3,FilesNumber);

Distance = zeros(1,FilesNumber);
Velocity = zeros(1,FilesNumber);

% specific features
SpecificActsNumberValue = [];
SpecificActsPercentValue = [];
SpecificActsMeanTimeValue = [];

%% main part
for file = 1:length(FileNames)
    
    FilenameVideo = sprintf('%s_%s.m4v', Identificator, FileNames{file});
    FilenameDLC = sprintf('%s_%s_track.csv',Identificator, FileNames{file});
    
    FilenamePreset = sprintf('%s_%s_Preset.mat', Identificator, FileNames{file});
    fprintf('Processing of %s_%s\n', Identificator, FileNames{file})
    
    [Acts, BodyPartsTraces] = BehaviorAnalyzerSTFP(PathVideo, FilenameVideo, PathDLC, FilenameDLC, PathOut, StartTime(file), EndTime(file), PathPreset, FilenamePreset);
    
    SpecificActsNumberValue = [SpecificActsNumberValue [Acts.ActNumber]'];
    SpecificActsPercentValue = [SpecificActsPercentValue [Acts.ActPercent]'];
    SpecificActsMeanTimeValue = [SpecificActsMeanTimeValue [Acts.ActMeanTime]'];
    if file == length(FileNames)
        SpecificActsNumber = table(names, SpecificActsNumberValue, 'VariableNames', {'Name', 'Value'});
        SpecificActsPercent = table(names, SpecificActsPercentValue, 'VariableNames', {'Name', 'Value'});
        SpecificActsMeanTime = table(names, SpecificActsMeanTimeValue, 'VariableNames', {'Name', 'Value'});
    end
    
    % variables calculaion
    
    FreezingPercent(file) = Acts(4).ActPercent;
    FreezingNumber(file) = Acts(4).ActNumber;
    FreezingMeanTime(file) = Acts(4).ActMeanTime;
    
    %     RearsPercent(file) = Acts(5).ActPercent;
    %     RearsNumber(file) = Acts(5).ActNumber;
    %     RearsMeanTime(file) = Acts(5).ActMeanTime;
    
    RestOtherLocomotionPercent(1:3,file) = [Acts(1).ActPercent; Acts(2).ActPercent; Acts(3).ActPercent];
    RestOtherLocomotionNumber(1:3,file) = [Acts(1).ActNumber; Acts(2).ActNumber; Acts(3).ActNumber];
    RestOtherLocomotionMeanTime(1:3,file) = [Acts(1).ActMeanTime; Acts(2).ActMeanTime; Acts(3).ActMeanTime];
    RestOtherLocomotionDistance(1:3,file) = [Acts(1).Distance; Acts(2).Distance; Acts(3).Distance];
    RestOtherLocomotionMeanDistance(1:3,file) = [Acts(1).ActMeanDistance; Acts(2).ActMeanDistance; Acts(3).ActMeanDistance];
    RestOtherLocomotionVelocity(1:3,file) = RestOtherLocomotionDistance(1:3,file)./(RestOtherLocomotionMeanTime(1:3,file).*RestOtherLocomotionNumber(1:3,file))*100;
    
    Distance(file) = BodyPartsTraces(12).AverageDistance;
    Velocity(file) = BodyPartsTraces(12).AverageSpeed;
    
    clear 'Acts' 'BodyPartsTraces';
end


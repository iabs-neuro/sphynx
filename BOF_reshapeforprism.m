%%
IndexControl = [4 5 6 9 11 12 13 16];
IndexTraget = [1 2 3 7 8 10 14 15];

% 2-5T
% ObjectNumberC = ObjectNumber([1 5 3 6],IndexControl);
% ObjectNumberT = ObjectNumber([1 5 3 6],IndexTraget);
% 
% ObjectPercentC = ObjectPercent([1 5 3 6],IndexControl);
% ObjectPercentT = ObjectPercent([1 5 3 6],IndexTraget);
% 
% ObjectMeanTimeC = ObjectMeanTime([1 5 3 6],IndexControl);
% ObjectMeanTimeT = ObjectMeanTime([1 5 3 6],IndexTraget);
% 
% ObjectMeanDistanceC = ObjectMeanDistance([1 5 3 6],IndexControl);
% ObjectMeanDistanceT = ObjectMeanDistance([1 5 3 6],IndexTraget);
% 
% ObjectDistanceC = ObjectDistance([1 5 3 6],IndexControl);
% ObjectDistanceT = ObjectDistance([1 5 3 6],IndexTraget);

% 1T
ObjectNumberC = ObjectNumber(:,IndexControl);
ObjectNumberT = ObjectNumber(:,IndexTraget);

ObjectPercentC = ObjectPercent(:,IndexControl);
ObjectPercentT = ObjectPercent(:,IndexTraget);

ObjectMeanTimeC = ObjectMeanTime(:,IndexControl);
ObjectMeanTimeT = ObjectMeanTime(:,IndexTraget);

ObjectMeanDistanceC = ObjectMeanDistance(:,IndexControl);
ObjectMeanDistanceT = ObjectMeanDistance(:,IndexTraget);

ObjectDistanceC = ObjectDistance(:,IndexControl);
ObjectDistanceT = ObjectDistance(:,IndexTraget);

%%
RestOtherLocomotionPercentC = RestOtherLocomotionPercent(:,IndexControl);
RestOtherLocomotionPercentT = RestOtherLocomotionPercent(:,IndexTraget);

RestOtherLocomotionNumberC = RestOtherLocomotionNumber(:,IndexControl);
RestOtherLocomotionNumberT = RestOtherLocomotionNumber(:,IndexTraget);

RestOtherLocomotionMeanTimeC = RestOtherLocomotionMeanTime(:,IndexControl);
RestOtherLocomotionMeanTimeT = RestOtherLocomotionMeanTime(:,IndexTraget);

RestOtherLocomotionDistanceC = RestOtherLocomotionDistance(:,IndexControl);
RestOtherLocomotionDistanceT = RestOtherLocomotionDistance(:,IndexTraget);

RestOtherLocomotionMeanDistanceC = RestOtherLocomotionMeanDistance(:,IndexControl);
RestOtherLocomotionMeanDistanceT = RestOtherLocomotionMeanDistance(:,IndexTraget);

RestOtherLocomotionVelocityC = RestOtherLocomotionVelocity(:,IndexControl);
RestOtherLocomotionVelocityT = RestOtherLocomotionVelocity(:,IndexTraget);

DistanceC = Distance(:,IndexControl);
DistanceT = Distance(:,IndexTraget);

VelocityC = Velocity(:,IndexControl);
VelocityT = Velocity(:,IndexTraget);

FreezingPercentC = FreezingPercent(:,IndexControl);
FreezingPercentT = FreezingPercent(:,IndexTraget);

FreezingNumberC = FreezingNumber(:,IndexControl);
FreezingNumberT = FreezingNumber(:,IndexTraget);

FreezingMeanTimeC = FreezingMeanTime(:,IndexControl);
FreezingMeanTimeT = FreezingMeanTime(:,IndexTraget);

RearsPercentC = RearsPercent(:,IndexControl);
RearsPercentT = RearsPercent(:,IndexTraget);

RearsNumberC = RearsNumber(:,IndexControl);
RearsNumberT = RearsNumber(:,IndexTraget);

RearsMeanTimeC = RearsMeanTime(:,IndexControl);
RearsMeanTimeT = RearsMeanTime(:,IndexTraget);

WallsMiddleCenterPercentC = WallsMiddleCenterPercent(:,IndexControl);
WallsMiddleCenterPercentT = WallsMiddleCenterPercent(:,IndexTraget);

WallsMiddleCenterNumberC = WallsMiddleCenterNumber(:,IndexControl);
WallsMiddleCenterNumberT = WallsMiddleCenterNumber(:,IndexTraget);

WallsMiddleCenterMeanTimeC = WallsMiddleCenterMeanTime(:,IndexControl);
WallsMiddleCenterMeanTimeT = WallsMiddleCenterMeanTime(:,IndexTraget);

WallsMiddleCenterDistanceC = WallsMiddleCenterDistance(:,IndexControl);
WallsMiddleCenterDistanceT = WallsMiddleCenterDistance(:,IndexTraget);

WallsMiddleCenterMeanDistanceC = WallsMiddleCenterMeanDistance(:,IndexControl);
WallsMiddleCenterMeanDistanceT = WallsMiddleCenterMeanDistance(:,IndexTraget);

WallsMiddleCenterVelocityC = WallsMiddleCenterVelocity(:,IndexControl);
WallsMiddleCenterVelocityT = WallsMiddleCenterVelocity(:,IndexTraget);

% %% 4T

% CornersWallsCenterPercentC = CornersWallsCenterPercent(:,IndexControl);
% CornersWallsCenterPercentT = CornersWallsCenterPercent(:,IndexTraget);
% 
% CornersWallsCenterNumberC = CornersWallsCenterNumber(:,IndexControl);
% CornersWallsCenterNumberT = CornersWallsCenterNumber(:,IndexTraget);
% 
% CornersWallsCenterMeanTimeC = CornersWallsCenterMeanTime(:,IndexControl);
% CornersWallsCenterMeanTimeT = CornersWallsCenterMeanTime(:,IndexTraget);
% 
% CornersWallsCenterDistanceC = CornersWallsCenterDistance(:,IndexControl);
% CornersWallsCenterDistanceT = CornersWallsCenterDistance(:,IndexTraget);
% 
% CornersWallsCenterMeanDistanceC = CornersWallsCenterMeanDistance(:,IndexControl);
% CornersWallsCenterMeanDistanceT = CornersWallsCenterMeanDistance(:,IndexTraget);
% 
% CornersWallsCenterVelocityC = CornersWallsCenterVelocity(:,IndexControl);
% CornersWallsCenterVelocityT = CornersWallsCenterVelocity(:,IndexTraget);
% % 

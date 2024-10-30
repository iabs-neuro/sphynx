
%% AllBodyParts
Thresholdcm = 19.4;
TempArray = zeros(n_frames,1);
for i=1:n_frames
    for part=1:BodyPartsNumber
        TempArray(i) = TempArray(i) + sqrt((BodyPartsTracesMainX(Point.Center,i)-BodyPartsTracesMainX(part,i))^2 + (BodyPartsTracesMainY(Point.Center,i)-BodyPartsTracesMainY(part,i))^2);
    end
end
TempArraySmooth = smooth(TempArray, Options.FrameRate);
Rears_auto = double(TempArraySmooth < Thresholdcm*Options.pxl2sm);

[Rears_auto_ref,~,~,~,~,~] = RefineLine(Rears_auto, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
TempArraySmoothcm = TempArraySmooth/Options.pxl2sm;

h = figure;
plot(time(6000:10801), TempArraySmoothcm(6000:10801), 'g', 'LineWidth', 1); hold on;
plot(time(6000:10801), Rears_auto_ref(6000:10801)*Thresholdcm, 'b.', 'MarkerSize',15); hold on;
plot(time(6000:10801), rears_human(6000:10801)*(Thresholdcm+0.3), 'r.', 'MarkerSize',13);
ax = gca;
ax.FontSize = 20;
ax.FontName = 'Times New Roman';
% legend('Расстояние "AllBodyParts"','Автоматическое выделение', 'Экспертное выделение', 'FontSize', 16,'FontName','Times New Roman');
xlabel('Время, с', 'FontSize', 25,'FontName','Times New Roman');
ylabel('Расстояние, см', 'FontSize', 25,'FontName','Times New Roman');
ylim([5, 30]); 
xlim([200, 360]); 
axis square;
[SensitivityThis, PrecisionThis] = RearsManualVsAutoCalc(rears_human, Rears_auto_ref);
SensitivityThis
PrecisionThis
%% TailBase
Thresholdcm = 2.7;
TempArray = zeros(n_frames,1);
for i=1:n_frames
    for part = [Point.LeftHindLimb Point.RightHindLimb]
        TempArray(i) = TempArray(i) + sqrt((BodyPartsTracesMainX(Point.Tailbase,i)-BodyPartsTracesMainX(part,i))^2 + (BodyPartsTracesMainY(Point.Tailbase,i)-BodyPartsTracesMainY(part,i))^2);
    end
end
TempArraySmooth = smooth(TempArray, ceil(Options.FrameRate/2));
Rears_auto = double(TempArraySmooth < Thresholdcm*Options.pxl2sm);
[Rears_auto_ref,~,~,~,~,~] = RefineLine(Rears_auto, Options.MinLengthActInFrames, Options.MinLengthActInFrames);
TempArraySmoothcm = TempArraySmooth/Options.pxl2sm;

Rears_auto_ref(Rears_auto_ref==0) = NaN;
rears_human(rears_human==0) = NaN;

h = figure;
plot(time(6000:10801), TempArraySmoothcm(6000:10801), 'g', 'LineWidth', 1); hold on;
plot(time(6000:10801), Rears_auto_ref(6000:10801)*Thresholdcm, 'b.', 'MarkerSize',15); hold on;
plot(time(6000:10801), rears_human(6000:10801)*mean(Thresholdcm+0.08), 'r.', 'MarkerSize',13);
ax = gca;
ax.FontSize = 20;
ax.FontName = 'Times New Roman';
legend('Расстояние "TailBase"','Автоматическое выделение', 'Экспертное выделение', 'FontSize', 16,'FontName','Times New Roman');
xlabel('Время, с', 'FontSize', 25,'FontName','Times New Roman');
ylabel('Расстояние, см ', 'FontSize', 25,'FontName','Times New Roman');

ylim([0, 5]); 
xlim([200, 360]); 
axis square;
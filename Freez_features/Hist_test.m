% hist(a,20);
% h = findobj(gca,'Type','patch');
% title('grafg','FontSize', 18);
% xlabel('dgvs','FontSize', 16);
% ylabel('dgvs','FontSize', 16);
% h.FaceColor = [0 0.5 0.5];
% h.EdgeColor = 'w';


h = histogram(a,20);
h.Normalization = 'probability';
title('Распределение ширины фибрилл','FontSize', 16);
xlabel('Ширина фибрилл, нм','FontSize', 16);
ylabel('Вероятность','FontSize', 16);
h.FaceColor = [0 0.5 0.5];
% h.FaceColor = 'r';
h.EdgeColor = 'w';
grid on


h = histogram(b,20);
h.Normalization = 'probability';
title('Length','FontSize', 18);
xlabel('dgvs','FontSize', 16);
ylabel('dgvs','FontSize', 16);
% h.FaceColor = [0 0.5 0.5];
% h.FaceColor = 'c';
h.EdgeColor = 'w';
grid on

h = histogram(b,20);
h.Normalization = 'probability';
title('Распределение длины фибрилл','FontSize', 16);
xlabel('Длина фибрилл, нм','FontSize', 16);
ylabel('Вероятность','FontSize', 16);
% h.FaceColor = [0 0.5 0.5];
% h.FaceColor = 'r';
h.EdgeColor = 'w';
grid on


% hist(a,20);
% h = findobj(gca,'Type','patch');
% title('grafg','FontSize', 18);
% xlabel('dgvs','FontSize', 16);
% ylabel('dgvs','FontSize', 16);
% h.FaceColor = [0 0.5 0.5];
% h.EdgeColor = 'w';


h = histogram(a,20);
h.Normalization = 'probability';
title('������������� ������ �������','FontSize', 16);
xlabel('������ �������, ��','FontSize', 16);
ylabel('�����������','FontSize', 16);
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
title('������������� ����� �������','FontSize', 16);
xlabel('����� �������, ��','FontSize', 16);
ylabel('�����������','FontSize', 16);
% h.FaceColor = [0 0.5 0.5];
% h.FaceColor = 'r';
h.EdgeColor = 'w';
grid on


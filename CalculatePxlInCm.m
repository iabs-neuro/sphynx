function [pixelsPerCentimeter, x_kcorr] = CalculatePxlInCm(frame)

PxlThreshold = 3;
x_kcorr = 1;

% Отображение кадра
imshow(frame);
title('Выберите 4 точки: 2 по вертикали, 2 по горизонтали (порядок важен)');

% Выбор двух точек на кадре
[x, y] = ginput(4);

% Вычисление расстояния между точками в пикселях
% distancePixels1 = sqrt((x(2) - x(1))^2 + (y(2) - y(1))^2);
% distancePixels2 = sqrt((x(4) - x(3))^2 + (y(4) - y(3))^2);
distancePixels1 = sqrt((y(2) - y(1))^2);
distancePixels2 = sqrt((x(4) - x(3))^2);

% Ввод пользователя: сколько сантиметров соответствует расстоянию между
% точками
distanceCentimeters1 = input('Сколько сантиметров между 1 и 2 точкой? ');
distanceCentimeters2 = input('Сколько сантиметров между 3 и 4 точкой? ');

% Вычисление разрешения пксл/см
pixelsPerCentimeterY = distancePixels1 / distanceCentimeters1;
pixelsPerCentimeterX = distancePixels2 / distanceCentimeters2;


if abs(pixelsPerCentimeterX-pixelsPerCentimeterY)/(pixelsPerCentimeterX)*100 > PxlThreshold
    pixelsPerCentimeter = pixelsPerCentimeterY;
    x_kcorr = pixelsPerCentimeterY/pixelsPerCentimeterX;
    fprintf('Количество пикселей на сантиметр между 1-2 (ось Y): %.2f пксл/см\n', pixelsPerCentimeterY);
    fprintf('Количество пикселей на сантиметр между 3-4 (ось X): %.2f пксл/см\n', pixelsPerCentimeterX);
    fprintf('Количество пикселей на сантиметр отличается между осями: x_kcorr %.2f пксл/см\n', x_kcorr);
else
    pixelsPerCentimeter = (pixelsPerCentimeterY+pixelsPerCentimeterX)/2;
    fprintf('Количество пикселей на сантиметр между 1-2 (ось Y): %.2f пксл/см\n', pixelsPerCentimeterY);
    fprintf('Количество пикселей на сантиметр между 3-4 (ось X): %.2f пксл/см\n', pixelsPerCentimeterX);
    fprintf('Среднее количество пикселей на сантиметр: %.2f пксл/см\n', pixelsPerCentimeter);
end

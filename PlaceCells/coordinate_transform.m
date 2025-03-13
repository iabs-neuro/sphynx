function [x_transformed, y_transformed] = coordinate_transform(x, y, point_origin, rotation_angle, method, mode)
% Функция для трансформации координат
%
% Входные параметры:
% x, y               - массивы координат
% point_origin       - точка начала координат новой СО
% rotation_angle     - угол поворота в радианах
% method             - метод преобразования: 'Translation', 'Rotation', 'Both'
% mode               - режим: 'Forward' (прямое) или 'Inverse' (обратное)
%
% Выходные параметры:
% x_transformed, y_transformed - преобразованные координаты

% Извлечение параметров
dx = -point_origin(1);
dy = -point_origin(2);
theta = rotation_angle;

% Преобразование координат
switch lower(method)
    case 'translation'
        % Только трансляция
        if strcmpi(mode, 'Forward')
            x_transformed = x + dx;
            y_transformed = y + dy;
        elseif strcmpi(mode, 'Inverse')
            x_transformed = x - dx;
            y_transformed = y - dy;
        else
            error('Режим должен быть "Forward" или "Inverse".');
        end
        
    case 'rotation'
        % Только ротация (вокруг начала координат)
        if strcmpi(mode, 'Forward')
            x_transformed = cos(theta) * x - sin(theta) * y;
            y_transformed = sin(theta) * x + cos(theta) * y;
        elseif strcmpi(mode, 'Inverse')
            % Обратное вращение
            x_transformed = cos(-theta) * x - sin(-theta) * y;
            y_transformed = sin(-theta) * x + cos(-theta) * y;
        else
            error('Режим должен быть "Forward" или "Inverse".');
        end
        
    case 'both'
        % Трансляция + ротация
        if strcmpi(mode, 'Forward')
            % 1. Сдвигаем координаты
            x_shifted = x + dx;
            y_shifted = y + dy;
            
            % 2. Выполняем вращение
            x_transformed = cos(theta) * x_shifted - sin(theta) * y_shifted;
            y_transformed = sin(theta) * x_shifted + cos(theta) * y_shifted;
            
        elseif strcmpi(mode, 'Inverse')
            % Обратное преобразование
            % 1. Обратное вращение
            x_rotated = cos(-theta) * x - sin(-theta) * y;
            y_rotated = sin(-theta) * x + cos(-theta) * y;
            
            % 2. Обратная трансляция
            x_transformed = x_rotated - dx;
            y_transformed = y_rotated - dy;
            
        else
            error('Режим должен быть "Forward" или "Inverse".');
        end
        
    otherwise
        error('Метод должен быть "Translation", "Rotation" или "Both".');
end
end
function create_3d_trajectory_gif(MouseCenterX, MouseCenterY, MouseCenterZ, Filename, varargin)
% CREATE_3D_TRAJECTORY_GIF Создает вращающуюся GIF-анимацию 3D траектории
%
% Входные параметры:
%   MouseCenterX, MouseCenterY, MouseCenterZ - координаты траектории
%   Filename - имя файла для заголовка и сохранения GIF
%
% Дополнительные параметры (пары "имя-значение"):
%   'OutputPath' - путь для сохранения (по умолчанию - текущая папка)
%   'GifName' - имя файла GIF (по умолчанию: '3d_trajectory.gif')
%   'FigSize' - размер фигуры [ширина высота] (по умолчанию [1000 1000])
%   'RotationSpeed' - скорость вращения (градусов/кадр, по умолчанию 2)
%   'Elevation' - угол возвышения камеры (по умолчанию 30)
%   'DelayTime' - задержка между кадрами (по умолчанию 0.05 сек)
%   'LineWidth' - толщина линии (по умолчанию 2)
%   'LineColor' - цвет линии (по умолчанию 'm' - пурпурный)
%   'ShowVisualization' - показывать ли окно визуализации (по умолчанию true)

    % Парсинг дополнительных параметров
    p = inputParser;
    addParameter(p, 'OutputPath', pwd, @ischar);
    addParameter(p, 'GifName', '3d_trajectory.gif', @ischar);
    addParameter(p, 'FigSize', [1000 1000], @isnumeric);
    addParameter(p, 'RotationSpeed', 2, @isnumeric);
    addParameter(p, 'Elevation', 30, @isnumeric);
    addParameter(p, 'DelayTime', 0.05, @isnumeric);
    addParameter(p, 'LineWidth', 2, @isnumeric);
    addParameter(p, 'LineColor', 'm', @ischar);
    addParameter(p, 'ShowVisualization', true, @islogical);
    
    parse(p, varargin{:});
    params = p.Results;

    % Полный путь к файлу
    gif_path = fullfile(params.OutputPath, params.GifName);
    
    % Расчет количества кадров
    total_rotation = 360;
    frames_per_loop = ceil(total_rotation/params.RotationSpeed);
    
    % Настройка фигуры (видимость зависит от параметра)
    if params.ShowVisualization
        h = figure('Position', [300 300 params.FigSize(1) params.FigSize(2)], ...
                   'Color', 'white', ...
                   'Name', '3D Trajectory Animation');
    else
        h = figure('Position', [300 300 params.FigSize(1) params.FigSize(2)], ...
                   'Color', 'white', ...
                   'Visible', 'off');
    end
    
    % Рисуем 3D траекторию
    plot3(MouseCenterX, MouseCenterY, MouseCenterZ, ...
          'Color', params.LineColor, ...
          'LineWidth', params.LineWidth);
    
    % Настройка осей и подписей
    xlabel('X, cm', 'FontSize', 20);
    ylabel('Y, cm', 'FontSize', 20);
    zlabel('Z, cm', 'FontSize', 20);
    grid on;
    title(sprintf('%s. Mouse Tracking', strrep(Filename, '_', '\_')), ...
          'FontSize', 20);
    
    % Настройки отображения
    axis equal tight;
    view(3);
    set(gca, 'FontSize', 16);
    
    % Дополнительные 3D эффекты
    light('Position', [1 1 1], 'Style', 'infinite');
    lighting gouraud;
    material dull;
    
    % Создание анимации
    for i = 1:frames_per_loop
        % Вращение сцены
        view(params.RotationSpeed*i, params.Elevation);
        
        % Захват кадра
        frame = getframe(h);
        im = frame2im(frame);
        [imind, cm] = rgb2ind(im, 256);
        
        % Запись в GIF
        if i == 1
            imwrite(imind, cm, gif_path, 'gif', ...
                   'Loopcount', inf, ...
                   'DelayTime', params.DelayTime);
        else
            imwrite(imind, cm, gif_path, 'gif', ...
                   'WriteMode', 'append', ...
                   'DelayTime', params.DelayTime);
        end
    end
    
    close(h);
    fprintf('GIF анимация сохранена: %s\n', gif_path);
end
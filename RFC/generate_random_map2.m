function [map, center] = generate_random_map2(map_size, map_type, sigma)
% Генерация случайной карты с возвратом центра для гауссовых пятен
    if nargin < 3
        sigma = 2;
    end
    
    if strcmp(map_type, 'gaussian') || strcmp(map_type, 'gaussian_split')
        
        % Случайный центр гауссова пятна
        center = rand(1, 2) .* (map_size - 1) + 1;
        
        % Создаем координатную сетку
        [X, Y] = meshgrid(1:map_size(2), 1:map_size(1));
        
        % Гауссово пятно
        gaussian = exp(-((X - center(2)).^2 + (Y - center(1)).^2) / (2 * sigma^2));
        
        % Нормализуем и добавляем немного шума
        map = gaussian + 0.1 * rand(map_size);
        map = map / max(map(:));
        
    else
        % Случайный шум
        map = randn(map_size);
        center = []; % Центр не определен для шума
    end
end
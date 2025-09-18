function random_map = generate_random_map(map_size, map_type, sigma)
% Генерация случайной карты активности
    
    if strcmpi(map_type, 'noise')
        % Случайный шум (равномерное распределение)
        random_map = rand(map_size);
        
    elseif strcmpi(map_type, 'gaussian')
        % Гауссово пятно в случайном месте
        random_map = zeros(map_size);
        
        % Случайные координаты центра пятна
        center_x = randi([3, map_size(1)-2]);
        center_y = randi([3, map_size(2)-2]);
        
        % Создаем гауссово пятно
        [X, Y] = meshgrid(1:map_size(2), 1:map_size(1));
        gaussian = exp(-((X - center_y).^2 + (Y - center_x).^2) / (2*sigma^2));
        
        % Нормализуем и добавляем немного шума
        random_map = gaussian + 0.1 * rand(map_size);
        random_map = random_map / max(random_map(:));
        
    else
        error('Неизвестный тип карты. Используйте ''noise'' или ''gaussian''');
    end
end
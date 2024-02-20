function [startIndices, endIndices, indicesArray] = findSeriesOfOnes(array)
    % Инициализация переменных
    startIndices = [];
    endIndices = [];
    
    % Поиск серий единиц
    inSeries = false;
    
    for i = 1:length(array)
        if array(i) == 1
            if ~inSeries
                % Начало новой серии
                startIndices = [startIndices, i];
                inSeries = true;
            end
        else
            if inSeries
                % Конец серии
                endIndices = [endIndices, i-1];
                inSeries = false;
            end
        end
    end
    
    % Проверка, если серия заканчивается в конце массива
    if inSeries
        endIndices = [endIndices, length(array)];
    end
    
    indicesArray = sort([startIndices endIndices]);
end

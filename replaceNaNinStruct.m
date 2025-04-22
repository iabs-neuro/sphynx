function S = replaceNaNinStruct(S)
% REPLACENANINSTRUCT Заменяет NaN на 0 в числовых полях структуры или массива структур
%   S = replaceNaNinStruct(S) обрабатывает:
%     - одиночные структуры,
%     - массивы структур,
%     - вложенные структуры.

if isstruct(S)
    if numel(S) == 1  % Одиночная структура
        fields = fieldnames(S);
        for i = 1:numel(fields)
            currentField = S.(fields{i});
            if isnumeric(currentField)
                currentField(isnan(currentField)) = 0;
                S.(fields{i}) = currentField;
            elseif isstruct(currentField)  % Рекурсия для вложенных структур
                S.(fields{i}) = replaceNaNinStruct(currentField);
            end
        end
    else  % Массив структур (обрабатываем каждый элемент)
        for k = 1:numel(S)
            S(k) = replaceNaNinStruct(S(k));
        end
    end
end
end
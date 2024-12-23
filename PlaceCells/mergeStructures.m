function result = mergeStructures(struct1, struct2)

% combine 2 structs by adding new fields
    result = struct1;    
    fields2 = fieldnames(struct2);
    for i = 1:numel(fields2)
        result.(fields2{i}) = struct2.(fields2{i});
    end
end

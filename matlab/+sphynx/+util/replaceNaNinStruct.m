function S = replaceNaNinStruct(S)
% REPLACENANINSTRUCT  Recursively replace NaN with 0 in numeric struct fields.
%
%   S = sphynx.util.replaceNaNinStruct(S) walks a struct (or struct
%   array, including nested), replacing NaN entries in numeric fields
%   with 0. Non-numeric fields are left as-is.
%
%   Ported from legacy functions/replaceNaNinStruct.m.

    if ~isstruct(S)
        return;
    end
    if numel(S) == 1
        fields = fieldnames(S);
        for i = 1:numel(fields)
            v = S.(fields{i});
            if isnumeric(v)
                v(isnan(v)) = 0;
                S.(fields{i}) = v;
            elseif isstruct(v)
                S.(fields{i}) = sphynx.util.replaceNaNinStruct(v);
            end
        end
    else
        for k = 1:numel(S)
            S(k) = sphynx.util.replaceNaNinStruct(S(k));
        end
    end
end

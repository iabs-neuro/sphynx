function x = ratio_to_double(r)
% ratio_to_double("30000/1001") -> 29.97
    r = string(r);
    if r == "0/0" || r == "" || r == "N/A"
        x = NaN; return;
    end
    parts = split(r, "/");
    if numel(parts) == 2
        num = str2double(parts(1));
        den = str2double(parts(2));
        if isfinite(num) && isfinite(den) && den ~= 0
            x = num / den;
        else
            x = NaN;
        end
    else
        x = str2double(r);
        if ~isfinite(x), x = NaN; end
    end
end
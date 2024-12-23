function [mouse] = identificator_unpuck(mouse)

% mouse.params_paths.FilenameOut = 'FOF_F01_1D_1T';

parts = strsplit(mouse.params_paths.filenameOut, '_');
parts_count = length(parts);

mouse.exp = parts{1};

if parts_count > 1
    if contains(parts{2}, {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}) && ~endsWith(parts{2}, {'D', 'T'})
        mouse.id = parts{2};
    elseif endsWith(parts{2}, 'D')
        mouse.day = parts{2};
    elseif endsWith(parts{2}, 'T')
        mouse.trial = parts{2};
    end
end

if parts_count > 2
    if endsWith(parts{3}, 'D')
        mouse.day = parts{3};
    elseif endsWith(parts{3}, 'T')
        mouse.trial = parts{3};
    end
end

if parts_count > 3
    if endsWith(parts{4}, 'D')
        mouse.day = parts{4};
    elseif endsWith(parts{4}, 'T')
        mouse.trial = parts{4};
    end
end

end
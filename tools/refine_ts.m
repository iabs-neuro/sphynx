function refine_ts(inputFolder, outputFolder)
% remove_each_10000th_row(inputFolder, outputFolder)
% Deletes every 10000-th row from each CSV in inputFolder and saves to outputFolder
%
% Assumptions:
% - inputFolder contains only .csv files (or you only want to process .csv)
% - each CSV has exactly one numeric column (with or without header)

    if nargin < 2
        error('Usage: remove_each_10000th_row(inputFolder, outputFolder)');
    end

    if ~isfolder(inputFolder)
        error('Input folder not found: %s', inputFolder);
    end
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    files = dir(fullfile(inputFolder, '*.csv'));
    if isempty(files)
        warning('No CSV files found in: %s', inputFolder);
        return;
    end

    for k = 1:numel(files)
        inPath = fullfile(files(k).folder, files(k).name);
        outPath = fullfile(outputFolder, files(k).name);

        % Read
        T = readtable(inPath, 'PreserveVariableNames', true);

        % Validate: exactly one numeric column
        isNumCol = varfun(@isnumeric, T, 'OutputFormat', 'uniform');
        if width(T) ~= 1 || ~isNumCol(1)
            error('File "%s": expected exactly 1 numeric column. Found width=%d, numeric=%d', ...
                files(k).name, width(T), isNumCol(1));
        end

        n = height(T);
        idxToRemove = 10000:10000:n;  % every 10000th row
        if ~isempty(idxToRemove)
            T(idxToRemove, :) = [];
        end

        % Write with the same filename
        writematrix(T{:,1}, outPath);

        fprintf('Processed: %-40s  rows %d -> %d\n', files(k).name, n, height(T));
    end
end

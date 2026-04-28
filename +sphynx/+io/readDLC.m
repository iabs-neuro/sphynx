function out = readDLC(csvPath, varargin)
% READDLC  Parse a DeepLabCut tracking CSV file.
%
%   out = sphynx.io.readDLC(csvPath, ...)
%
%   DLC CSV format:
%     row 1: scorer, scorer-name, scorer-name, ...
%     row 2: bodyparts, name1, name1, name1, name2, name2, name2, ...
%     row 3: coords, x, y, likelihood, x, y, likelihood, ...
%     row 4+: frameIdx, x1, y1, l1, x2, y2, l2, ...
%
%   Output struct fields:
%     bodyPartsNames - 1xP cell array of part names
%     X              - PxN matrix of x positions
%     Y              - PxN matrix of y positions
%     likelihood     - PxN matrix of likelihoods
%     nFrames        - N
%
%   Optional name-value:
%     'StartFrame' - first frame to read (default 1)
%     'EndFrame'   - last frame (default 0 = read all)

    p = inputParser;
    addRequired(p, 'csvPath');
    addParameter(p, 'StartFrame', 1, @(v) isnumeric(v) && v >= 1);
    addParameter(p, 'EndFrame', 0, @(v) isnumeric(v) && v >= 0);
    parse(p, csvPath, varargin{:});

    if ~isfile(csvPath)
        error('sphynx:readDLC:notFound', 'DLC csv not found: %s', csvPath);
    end

    % Read header lines to get part names
    fid = fopen(csvPath, 'r');
    if fid < 0
        error('sphynx:readDLC:cannotOpen', 'Cannot open: %s', csvPath);
    end
    cleaner = onCleanup(@() fclose(fid));
    headerLines = cell(3, 1);
    for k = 1:3
        headerLines{k} = fgetl(fid);
    end

    bodyPartsTokens = strsplit(headerLines{2}, ',');
    bodyPartsTokens = bodyPartsTokens(2:end);  % drop the leading 'bodyparts' label
    nCols = numel(bodyPartsTokens);
    if mod(nCols, 3) ~= 0
        error('sphynx:readDLC:malformed', ...
            'Expected 3 columns per part, got %d data columns', nCols);
    end
    nParts = nCols / 3;
    out.bodyPartsNames = cell(1, nParts);
    for part = 1:nParts
        out.bodyPartsNames{part} = bodyPartsTokens{(part-1)*3 + 1};
    end

    % Now read the data table (skip the 3 header rows)
    data = readmatrix(csvPath, 'NumHeaderLines', 3);
    % Column 1 is frame index; subsequent triplets are x, y, likelihood per part.
    nFrames = size(data, 1);

    startF = p.Results.StartFrame;
    endF = p.Results.EndFrame;
    if endF == 0 || endF > nFrames
        endF = nFrames;
    end
    sliceRows = startF:endF;

    out.X = zeros(nParts, numel(sliceRows));
    out.Y = zeros(nParts, numel(sliceRows));
    out.likelihood = zeros(nParts, numel(sliceRows));
    for part = 1:nParts
        col = (part-1)*3 + 2;  % +2 because column 1 is frame index
        out.X(part, :) = data(sliceRows, col)';
        out.Y(part, :) = data(sliceRows, col + 1)';
        out.likelihood(part, :) = data(sliceRows, col + 2)';
    end
    out.nFrames = numel(sliceRows);
end

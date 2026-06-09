function out = readDLC(csvPath, varargin)
% READDLC  Parse a DeepLabCut tracking CSV file (single- or multi-animal).
%
%   out = sphynx.io.readDLC(csvPath, ...)
%
%   Single-animal DLC CSV format (3 header rows):
%     row 1: scorer, scorer-name, scorer-name, ...
%     row 2: bodyparts, name1, name1, name1, name2, name2, name2, ...
%     row 3: coords, x, y, likelihood, x, y, likelihood, ...
%     row 4+: frameIdx, x1, y1, l1, x2, y2, l2, ...
%
%   Multi-animal DLC CSV format (4 header rows, '_el.csv' files):
%     row 1: scorer, ...
%     row 2: individuals, animal1, animal1, animal1, animal2, ..., single, ...
%     row 3: bodyparts, ...
%     row 4: coords, ...
%     row 5+: data
%
%   For multi-animal: auto-detects all individuals (logged), then picks
%   the one with the most non-NaN x/y entries for analysis. Trackers
%   labelled 'single' (typically one bodypart like a miniscope LED) are
%   excluded from the selection -- only true multi-bodypart animals
%   compete. Returns that animal's columns only.
%
%   Output struct fields:
%     bodyPartsNames    - 1xP cell array of part names
%     X                 - PxN matrix of x positions
%     Y                 - PxN matrix of y positions
%     likelihood        - PxN matrix of likelihoods
%     nFrames           - N
%     individuals       - 1xK cell array of unique individual names
%                         (multi-animal only; absent for single-animal)
%     selectedIndividual - name of the picked individual
%                         (multi-animal only)
%
%   Optional name-value:
%     'StartFrame' - first frame to read (default 1)
%     'EndFrame'   - last frame (default 0 = read all)
%     'Individual' - force a specific individual by name (multi-animal
%                    only; default: auto-pick most-populated)

    p = inputParser;
    addRequired(p, 'csvPath');
    addParameter(p, 'StartFrame', 1, @(v) isnumeric(v) && v >= 1);
    addParameter(p, 'EndFrame', 0, @(v) isnumeric(v) && v >= 0);
    addParameter(p, 'Individual', '', @ischar);
    parse(p, csvPath, varargin{:});

    if ~isfile(csvPath)
        error('sphynx:readDLC:notFound', 'DLC csv not found: %s', csvPath);
    end

    % Peek 4 header rows so we can decide single- vs multi-animal layout.
    fid = fopen(csvPath, 'r');
    if fid < 0
        error('sphynx:readDLC:cannotOpen', 'Cannot open: %s', csvPath);
    end
    cleaner = onCleanup(@() fclose(fid));
    headerLines = cell(4, 1);
    for k = 1:4
        headerLines{k} = fgetl(fid);
        if ~ischar(headerLines{k})
            error('sphynx:readDLC:truncated', ...
                'CSV ended before header line %d', k);
        end
    end

    row2 = strsplit(headerLines{2}, ',');
    isMultiAnimal = ~isempty(row2) && strcmpi(strtrim(row2{1}), 'individuals');

    if isMultiAnimal
        numHeaderLines = 4;
        bodyPartsTokens = strsplit(headerLines{3}, ',');
        individualsTokens = row2(2:end);   % drop the 'individuals' label
    else
        numHeaderLines = 3;
        bodyPartsTokens = strsplit(headerLines{2}, ',');
        individualsTokens = {};
    end
    bodyPartsTokens = bodyPartsTokens(2:end);   % drop the leading label
    nCols = numel(bodyPartsTokens);
    if mod(nCols, 3) ~= 0
        error('sphynx:readDLC:malformed', ...
            'Expected 3 columns per part, got %d data columns', nCols);
    end

    % Read the numeric matrix.
    data = readmatrix(csvPath, 'NumHeaderLines', numHeaderLines, ...
        'DecimalSeparator', '.');
    nFrames = size(data, 1);

    startF = p.Results.StartFrame;
    endF = p.Results.EndFrame;
    if endF == 0 || endF > nFrames
        endF = nFrames;
    end
    sliceRows = startF:endF;

    if isMultiAnimal
        [partColsZeroBased, partNames, picked, allIndividuals] = ...
            pickMultiAnimal(individualsTokens, bodyPartsTokens, ...
                            data, p.Results.Individual);
        out.individuals = allIndividuals;
        out.selectedIndividual = picked;
        sphynx.util.log('info', ...
            '[readDLC] multi-animal: %d individuals found {%s}; selected "%s" (%d body parts)', ...
            numel(allIndividuals), strjoin(allIndividuals, ', '), picked, ...
            numel(partNames));
    else
        nParts = nCols / 3;
        partNames = cell(1, nParts);
        partColsZeroBased = zeros(1, nParts);
        for part = 1:nParts
            partNames{part} = bodyPartsTokens{(part-1)*3 + 1};
            partColsZeroBased(part) = (part-1)*3;
        end
    end

    nParts = numel(partNames);
    out.bodyPartsNames = partNames;
    out.X = zeros(nParts, numel(sliceRows));
    out.Y = zeros(nParts, numel(sliceRows));
    out.likelihood = zeros(nParts, numel(sliceRows));
    for part = 1:nParts
        % +2 because column 1 of data is the frame index and partCols are
        % zero-based offsets into the (data-minus-frame-index) columns.
        col = partColsZeroBased(part) + 2;
        out.X(part, :) = data(sliceRows, col)';
        out.Y(part, :) = data(sliceRows, col + 1)';
        out.likelihood(part, :) = data(sliceRows, col + 2)';
    end
    % Normalize DLC missing sentinel: some exporters (notably
    % superanimal_topviewmouse) write -1.0 for "no detection". Pixel
    % coords are always >= 0, so anything negative is unambiguously
    % missing. Convert to NaN so downstream filters (Hampel, sgolay)
    % treat it correctly.
    missMask = (out.X < 0) | (out.Y < 0);
    out.X(missMask) = NaN;
    out.Y(missMask) = NaN;
    out.likelihood(missMask) = NaN;
    out.nFrames = numel(sliceRows);
end

function [partColsZeroBased, partNames, picked, allIndividuals] = ...
        pickMultiAnimal(individualsTokens, bodyPartsTokens, data, forced)
    % Group columns by individual. Pick the individual with the most
    % non-NaN (x AND y) entries across all frames.

    nDataCols = numel(individualsTokens);
    if mod(nDataCols, 3) ~= 0
        error('sphynx:readDLC:malformed', ...
            'Multi-animal: column counts inconsistent (%d not divisible by 3)', ...
            nDataCols);
    end

    % Walk in triplets -- each triplet is (x, y, likelihood) for one
    % bodypart of one individual. Group triplets by their individual.
    nTriplets = nDataCols / 3;
    tripletIndividual = cell(1, nTriplets);
    tripletBodyPart   = cell(1, nTriplets);
    for t = 1:nTriplets
        c0 = (t-1)*3 + 1;
        tripletIndividual{t} = strtrim(individualsTokens{c0});
        tripletBodyPart{t}   = strtrim(bodyPartsTokens{c0});
    end

    allIndividuals = unique(tripletIndividual, 'stable');

    % Animal candidates: any individual with > 1 distinct bodypart.
    % This excludes 'single' trackers (typically 1 bodypart like a
    % miniscope LED). If no candidate qualifies, fall back to all.
    candidates = {};
    for k = 1:numel(allIndividuals)
        name = allIndividuals{k};
        bps  = unique(tripletBodyPart(strcmp(tripletIndividual, name)));
        if numel(bps) > 1
            candidates{end+1} = name; %#ok<AGROW>
        end
    end
    if isempty(candidates)
        candidates = allIndividuals;
    end

    % Forced selection wins if provided and valid.
    if ~isempty(forced)
        if any(strcmp(allIndividuals, forced))
            picked = forced;
        else
            error('sphynx:readDLC:unknownIndividual', ...
                'Forced Individual "%s" not in CSV; available: {%s}', ...
                forced, strjoin(allIndividuals, ', '));
        end
    else
        % Auto-pick: most "populated" (x AND y) entries. A value is
        % populated when it is neither NaN nor the DLC missing sentinel
        % (DeepLabCut writes -1.0 for "no detection" in some pipelines,
        % including the superanimal_topviewmouse exports).
        bestScore = -1;
        picked = candidates{1};
        for k = 1:numel(candidates)
            name = candidates{k};
            triplets = find(strcmp(tripletIndividual, name));
            score = 0;
            for ti = triplets
                c0 = (ti-1)*3 + 2;   % +2 for frame index
                xs = data(:, c0);
                ys = data(:, c0 + 1);
                populated = ~isnan(xs) & ~isnan(ys) & xs >= 0 & ys >= 0;
                score = score + sum(populated);
            end
            if score > bestScore
                bestScore = score;
                picked = name;
            end
        end
    end

    pickedTripletIdx = find(strcmp(tripletIndividual, picked));
    nParts = numel(pickedTripletIdx);
    partNames = cell(1, nParts);
    partColsZeroBased = zeros(1, nParts);
    for k = 1:nParts
        ti = pickedTripletIdx(k);
        partNames{k} = tripletBodyPart{ti};
        partColsZeroBased(k) = (ti-1)*3;
    end
end

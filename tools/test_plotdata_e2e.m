function test_plotdata_e2e()
% TEST_PLOTDATA_E2E  Build wide CSV from converted CC + 2 fake groups,
% then exercise the +stats/+plot pipeline headlessly.

    here = fileparts(mfilename('fullpath'));
    outDir = fullfile(here, '..', 'docs', 'tests', 'plotdata_e2e');
    if ~isfolder(outDir); mkdir(outDir); end

    % --- Build batch + super-table CSV ---
    d = 'H:\Dataset\BehaviorData\CC\5_BehaviorMAT_new';
    files = dir(fullfile(d, '*_WorkSpace.mat'));
    fprintf('Reading %d CC sessions...\n', numel(files));
    batch = struct('SessionName', {}, 'Acts', {}, 'Distance', {}, 'Velocity', {});
    for k = 1:numel(files)
        S = load(fullfile(files(k).folder, files(k).name));
        rec.SessionName = regexprep(files(k).name, '_WorkSpace\.mat$', '');
        rec.Acts = S.Acts;
        bcIdx = find(strcmpi({S.BodyPartsTraces.BodyPartName}, 'bodycenter'), 1);
        if isempty(bcIdx); bcIdx = numel(S.BodyPartsTraces); end
        rec.Distance = S.BodyPartsTraces(bcIdx).AverageDistance;
        rec.Velocity = S.BodyPartsTraces(bcIdx).AverageSpeed;
        batch(end+1) = rec; %#ok<AGROW>
    end

    % Fake 2-group metadata to exercise 2-way path
    sessNames = {batch.SessionName};
    miceUnique = unique(regexprep(sessNames, '_\dD$', ''));  % e.g. CC_H01
    meta = table( ...
        strcat('CC_', extractAfter(miceUnique, 'CC_'))', ...
        repmat({''}, numel(miceUnique), 1), ...
        repmat({''}, numel(miceUnique), 1), ...
        'VariableNames', {'mouse','group','sex'});
    % Split mice by number: H01..H10 = ctrl, rest = exp
    for i = 1:height(meta)
        nm = meta.mouse{i};
        n = sscanf(nm, 'CC_H%d');
        if isempty(n) || n <= 10; meta.group{i} = 'ctrl'; else; meta.group{i} = 'exp'; end
        meta.sex{i} = repmat('FM', 1, mod(n, 2) + 1); meta.sex{i} = meta.sex{i}(1);
    end
    % Mouse short form is "H01"; bring meta.mouse into same form so
    % buildSuperTable can join (normalize handles ID_ prefix; we use bare names).
    meta.mouse = strrep(meta.mouse, 'CC_', '');

    ST = sphynx.pipeline.buildSuperTable(batch, 'Metadata', meta, ...
        'SortBy', {'group','mouse'});
    csv = fullfile(outDir, 'super_table.csv');
    writetable(ST.Wide, csv);
    fprintf('Wrote %s (%dx%d)\n', csv, height(ST.Wide), width(ST.Wide));

    % --- Reload and test the helpers ---
    T = readtable(csv);
    fprintf('Reloaded: %d rows x %d cols, vars: %s\n', height(T), width(T), ...
        strjoin(T.Properties.VariableNames(1:min(6, width(T))), ', '));

    [metrics, factorCols, idCol] = sphynx.stats.extractMetrics(T);
    fprintf('Detected %d metrics; factors: %s; id=%s\n', ...
        numel(metrics), strjoin(factorCols, ','), idCol);
    fprintf('First 5 metric labels: %s\n', strjoin({metrics(1:min(5,end)).label}, ', '));

    % --- One-way (group only) on rest_percent ---
    mPick = findMetric(metrics, 'rest_percent');
    if ~isempty(mPick)
        L = sphynx.stats.metricToLong(T, mPick, idCol, factorCols);
        L = L(~isnan(L.value), :);
        % Restrict to one session for a true 1-way between-groups test.
        L1D = L(strcmp(L.session, '1D'), :);
        R = sphynx.stats.runTest(L1D, {'group'}, struct('test','auto'));
        fprintf('\n[1-way group, session=1D] %s: %s\n', mPick.label, R.note);

        % 2-way: group x session
        R2 = sphynx.stats.runTest(L, {'group'}, struct('test','auto'));
        fprintf('[auto with session] %s: %s\n', mPick.label, R2.note);
        fprintf('  pairwise rows: %d\n', height(R2.pairwise));
        for r = 1:min(8, height(R2.pairwise))
            fprintf('    %s vs %s : p=%.4g\n', R2.pairwise.groupA{r}, ...
                R2.pairwise.groupB{r}, R2.pairwise.p(r));
        end

        % Render headless and save
        fig = figure('Visible', 'off', 'Position', [100 100 720 540], 'Color', 'w');
        cleanup = onCleanup(@() close(fig));
        ax = axes(fig); %#ok<LAXES>
        style = struct('title', mPick.label, 'colormap','lines');
        sphynx.plot.barWithStats(ax, L, 'session', 'group', R2, style);
        out = fullfile(outDir, [mPick.label '.png']);
        exportgraphics(ax, out, 'Resolution', 200);
        fprintf('Wrote %s\n', out);
    else
        fprintf('rest_percent not found in metrics\n');
    end

    % --- 1-way on general distance, one-factor session only ---
    mDist = findMetric(metrics, 'distance_cm');
    if ~isempty(mDist)
        L = sphynx.stats.metricToLong(T, mDist, idCol, factorCols);
        L = L(~isnan(L.value), :);
        R = sphynx.stats.runTest(L, {}, struct('test','auto'));
        fprintf('\n[auto session-only] %s: %s\n', mDist.label, R.note);
        fig = figure('Visible', 'off', 'Position', [100 100 540 480], 'Color', 'w');
        cleanup = onCleanup(@() close(fig));
        ax = axes(fig); %#ok<LAXES>
        sphynx.plot.barWithStats(ax, L, 'session', '', R, struct('title','distance_cm'));
        out = fullfile(outDir, 'distance_cm.png');
        exportgraphics(ax, out, 'Resolution', 200);
        fprintf('Wrote %s\n', out);
    end
end

function m = findMetric(metrics, label)
    m = [];
    for k = 1:numel(metrics)
        if strcmp(metrics(k).label, label); m = metrics(k); return; end
    end
end

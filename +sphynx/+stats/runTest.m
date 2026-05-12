function R = runTest(L, factorNames, opts)
% RUNTEST  Auto-select and execute a statistical test on a long-form
% data block.
%
%   R = sphynx.stats.runTest(L, factorNames, opts)
%
%   Input:
%     L           - long table from metricToLong (cols subject, session,
%                   <factors...>, value).
%     factorNames - cellstr of factors to use (1 or 2 names from L). The
%                   implicit 'session' factor is treated specially: if it
%                   has >1 level, it is appended automatically when
%                   numel(factorNames) < 2.
%     opts        - struct with optional fields:
%                     test      'auto' (default) | 'ttest' | 'paired-ttest'
%                               | 'anova1' | 'anova2' | 'rm-anova'
%                     correction 'auto'|'tukey'|'bonferroni'|'holm'|'none'
%                     alpha     default 0.05
%
%   Output R:
%     .test       chosen test name (string)
%     .p          omnibus p-value (NaN if not applicable)
%     .stat       test statistic
%     .df         degrees of freedom (struct or vector)
%     .pairwise   table with columns groupA, groupB, p (Bonferroni-adjusted
%                 if correction not none) — for post-hoc / pairwise; empty
%                 if test is a single t-test.
%     .factors    cellstr of the factors actually used (after session
%                 auto-append).
%     .note       human-readable summary.
%     .nSubjects  number of unique subjects entering the test.

    if nargin < 3; opts = struct(); end
    opts = defaultOpts(opts);

    R = newResult();
    if isempty(L) || height(L) == 0
        R.note = 'no data'; return;
    end
    % Drop NaN values
    L = L(~isnan(L.value), :);
    if height(L) < 2
        R.note = 'not enough data'; return;
    end

    % Resolve effective factors: include 'session' if user picked <2 factors
    % and session is varying. Cap at 2.
    factorNames = factorNames(:)';
    if numel(factorNames) < 2 && any(strcmp(L.Properties.VariableNames, 'session'))
        sessVals = L.session;
        if ~iscell(sessVals); sessVals = cellstr(string(sessVals)); end
        if numel(unique(sessVals(~cellfun('isempty', sessVals)))) > 1 && ...
                ~any(strcmp(factorNames, 'session'))
            factorNames = [factorNames, {'session'}];
        end
    end
    factorNames = factorNames(1:min(2, numel(factorNames)));
    R.factors = factorNames;

    if isempty(factorNames)
        R.note = 'no factors with variation'; return;
    end

    % Detect within/between for chosen factors
    fInfo = sphynx.stats.detectFactors(L, factorNames);
    R.nSubjects = numel(unique(L.subject));

    % Pick test if auto
    chosen = opts.test;
    if strcmp(chosen, 'auto')
        chosen = pickAuto(L, factorNames, fInfo);
    end
    R.test = chosen;

    try
        switch chosen
            case 'ttest';        R = doTTest(R, L, factorNames, opts, false);
            case 'paired-ttest'; R = doTTest(R, L, factorNames, opts, true);
            case 'anova1';       R = doAnova1(R, L, factorNames, opts);
            case 'anova2';       R = doAnova2(R, L, factorNames, opts);
            case 'rm-anova';     R = doRMAnova(R, L, factorNames, fInfo, opts);
            otherwise
                R.note = sprintf('unknown test: %s', chosen);
        end
    catch ME
        R.note = sprintf('%s failed: %s', chosen, ME.message);
    end
end


function R = newResult()
    R = struct('test', '', 'p', NaN, 'stat', NaN, 'df', [], ...
        'pairwise', table('Size',[0 3],'VariableTypes',{'cell','cell','double'}, ...
            'VariableNames',{'groupA','groupB','p'}), ...
        'factors', {{}}, 'note', '', 'nSubjects', 0);
end


function opts = defaultOpts(opts)
    if ~isfield(opts, 'test') || isempty(opts.test);             opts.test = 'auto'; end
    if ~isfield(opts, 'correction') || isempty(opts.correction); opts.correction = 'auto'; end
    if ~isfield(opts, 'alpha');                                  opts.alpha = 0.05; end
end


function chosen = pickAuto(L, factorNames, fInfo)
    nF = numel(factorNames);
    if nF == 1
        nm = factorNames{1};
        within = false;
        for j = 1:numel(fInfo)
            if strcmp(fInfo(j).name, nm); within = fInfo(j).within; break; end
        end
        levels = unique(getFactor(L, nm));
        if numel(levels) <= 2
            if within; chosen = 'paired-ttest'; else; chosen = 'ttest'; end
        else
            if within; chosen = 'rm-anova'; else; chosen = 'anova1'; end
        end
    else
        anyWithin = false;
        for j = 1:numel(fInfo)
            if any(strcmp(factorNames, fInfo(j).name)) && fInfo(j).within
                anyWithin = true; break;
            end
        end
        if anyWithin; chosen = 'rm-anova'; else; chosen = 'anova2'; end
    end
end


function v = getFactor(L, nm)
    v = L.(nm);
    if ~iscell(v); v = cellstr(string(v)); end
end


function R = doTTest(R, L, factorNames, opts, paired)
    f = factorNames{1};
    g = getFactor(L, f);
    levels = unique(g, 'stable');
    if numel(levels) ~= 2
        R.note = sprintf('t-test needs exactly 2 levels of %s, got %d', f, numel(levels)); return;
    end
    if paired
        % Match by subject across the two levels (assumes within-subject)
        sa = L.subject(strcmp(g, levels{1}));
        sb = L.subject(strcmp(g, levels{2}));
        va = L.value(strcmp(g, levels{1}));
        vb = L.value(strcmp(g, levels{2}));
        [common, ia, ib] = intersect(sa, sb);
        if numel(common) < 2
            R.note = 'paired t-test needs >=2 paired subjects'; return;
        end
        [h, p, ci, stats] = ttest(va(ia), vb(ib), 'Alpha', opts.alpha); %#ok<ASGLU>
    else
        va = L.value(strcmp(g, levels{1}));
        vb = L.value(strcmp(g, levels{2}));
        [h, p, ci, stats] = ttest2(va, vb, 'Alpha', opts.alpha); %#ok<ASGLU>
    end
    R.p = p; R.stat = stats.tstat; R.df = stats.df;
    R.pairwise = table({levels{1}}, {levels{2}}, p, ...
        'VariableNames', {'groupA','groupB','p'});
    R.note = sprintf('%s t=%.3f, df=%.1f, p=%.4g', R.test, stats.tstat, stats.df, p);
end


function R = doAnova1(R, L, factorNames, opts)
    f = factorNames{1};
    g = getFactor(L, f);
    levels = unique(g, 'stable');
    [p, tbl, stats] = anova1(L.value, g, 'off');
    R.p = p; R.stat = tbl{2,5}; R.df = [tbl{2,3}, tbl{3,3}];
    % multcompare on stats
    try
        c = multcompare(stats, 'Display', 'off', 'CType', mcType(opts.correction, 'anova'));
    catch
        R.note = sprintf('anova1 p=%.4g (no multcompare)', p); return;
    end
    % stats.gnames is a cell array of group names
    gn = stats.gnames; if ~iscell(gn); gn = cellstr(gn); end
    pw = table('Size',[size(c,1), 3], 'VariableTypes',{'cell','cell','double'}, ...
        'VariableNames',{'groupA','groupB','p'});
    for r = 1:size(c,1)
        pw.groupA{r} = gn{c(r,1)};
        pw.groupB{r} = gn{c(r,2)};
        pw.p(r) = c(r, 6);
    end
    R.pairwise = pw;
    R.note = sprintf('anova1 (%s) F=%.3f, p=%.4g, n=%d levels', f, R.stat, p, numel(levels));
end


function R = doAnova2(R, L, factorNames, opts)
    f1 = factorNames{1}; f2 = factorNames{2};
    g1 = getFactor(L, f1); g2 = getFactor(L, f2);
    [p, tbl, stats] = anovan(L.value, {g1, g2}, ...
        'model', 'interaction', 'varnames', {f1, f2}, 'display', 'off');
    R.p = p(1);  % first factor's p as omnibus marker
    R.stat = tbl{2, 6};
    R.df = [tbl{2, 3}, tbl{end-1, 3}];
    % pairwise within each factor
    pairs = {};
    pwAll = {};
    try
        for fi = 1:2
            c = multcompare(stats, 'Dimension', fi, 'Display', 'off', ...
                'CType', mcType(opts.correction, 'anova'));
            gn = stats.varnames(fi); %#ok<NASGU>
            % stats.grpnames is for each factor
            gn = stats.grpnames{fi};
            if ~iscell(gn); gn = cellstr(gn); end
            for r = 1:size(c, 1)
                pwAll(end+1, :) = {[factorNames{fi} ':' gn{c(r,1)}], ...
                                   [factorNames{fi} ':' gn{c(r,2)}], c(r, 6)}; %#ok<AGROW>
            end
        end
    catch
    end
    if ~isempty(pwAll)
        R.pairwise = cell2table(pwAll, 'VariableNames', {'groupA','groupB','p'});
    end
    R.note = sprintf('2-way ANOVA: p(%s)=%.4g, p(%s)=%.4g, p(int)=%.4g', ...
        f1, p(1), f2, p(2), p(min(3, numel(p))));
end


function R = doRMAnova(R, L, factorNames, fInfo, opts)
    % Mixed-design via fitrm + ranova.
    % Within factor(s) are those flagged within; between = the rest.
    nF = numel(factorNames);
    within = false(1, nF);
    for k = 1:nF
        for j = 1:numel(fInfo)
            if strcmp(fInfo(j).name, factorNames{k})
                within(k) = fInfo(j).within; break;
            end
        end
    end
    withinNames  = factorNames(within);
    betweenNames = factorNames(~within);

    if isempty(withinNames)
        % All between → fall back to 1/2-way ANOVA.
        if nF == 1; R = doAnova1(R, L, factorNames, opts);
        else;       R = doAnova2(R, L, factorNames, opts);
        end
        return;
    end

    % Build a wide-by-subject table: rows=subject, cols=combinations of
    % within-factor levels. Between factors stay as columns.
    %
    % For MVP we only handle one within factor + 0/1 between factors,
    % which covers the common cases (session within; group between).
    if numel(withinNames) > 1
        R.note = 'multi-within RM not implemented; falling back to anovan';
        try
            allG = cell(1, nF);
            for k = 1:nF; allG{k} = getFactor(L, factorNames{k}); end
            [p, tbl, stats] = anovan(L.value, allG, ...
                'model', 'interaction', 'varnames', factorNames, 'display', 'off');
            R.p = p(1); R.stat = tbl{2,6};
        catch ME
            R.note = sprintf('anovan fallback failed: %s', ME.message);
        end
        return;
    end

    wn = withinNames{1};
    wlev = unique(getFactor(L, wn), 'stable');
    nW = numel(wlev);
    subj = unique(L.subject, 'stable');
    nS = numel(subj);
    Y = nan(nS, nW);
    btw = cell(nS, numel(betweenNames));
    for s = 1:nS
        for k = 1:nW
            mask = strcmp(L.subject, subj{s}) & strcmp(getFactor(L, wn), wlev{k});
            if any(mask); Y(s, k) = mean(L.value(mask), 'omitnan'); end
        end
        % Between factors (constant per subject by definition).
        for b = 1:numel(betweenNames)
            v = L.(betweenNames{b});
            if ~iscell(v); v = cellstr(string(v)); end
            v = v(strcmp(L.subject, subj{s}));
            if ~isempty(v); btw{s, b} = v{1}; else; btw{s, b} = ''; end
        end
    end
    wideTbl = array2table(Y, 'VariableNames', ...
        matlab.lang.makeValidName(strcat('w', wlev(:)')));
    for b = 1:numel(betweenNames)
        wideTbl.(betweenNames{b}) = btw(:, b);
    end
    % Fit RM model
    if isempty(betweenNames)
        rmModel = fitrm(wideTbl, sprintf('%s-%s ~ 1', wideTbl.Properties.VariableNames{1}, ...
            wideTbl.Properties.VariableNames{end}), ...
            'WithinDesign', table((1:nW)', 'VariableNames', {wn}));
    else
        rhs = strjoin(betweenNames, '*');
        rmModel = fitrm(wideTbl, sprintf('%s-%s ~ %s', wideTbl.Properties.VariableNames{1}, ...
            wideTbl.Properties.VariableNames{nW}, rhs), ...
            'WithinDesign', table((1:nW)', 'VariableNames', {wn}));
    end
    ra = ranova(rmModel, 'WithinModel', wn);
    % Pick the within main effect row.
    idxWithin = find(contains(string(ra.Properties.RowNames), wn), 1);
    if isempty(idxWithin)
        R.p = ra.pValue(1);
    else
        R.p = ra.pValue(idxWithin);
    end
    R.stat = ra.F(1);
    % Pairwise: collect within-factor + each between-factor. Within
    % uses numeric indices (1..nW) -> map back to level names.
    pwAll = cell(0, 3);
    try
        pw = multcompare(rmModel, wn, 'ComparisonType', ...
            mcType(opts.correction, 'rm'));
        idx1 = double(pw.(wn + "_1"));
        idx2 = double(pw.(wn + "_2"));
        levs  = wlev(idx1); levs2 = wlev(idx2);
        if ~iscell(levs);  levs  = cellstr(string(levs));  end
        if ~iscell(levs2); levs2 = cellstr(string(levs2)); end
        seen = containers.Map('KeyType','char','ValueType','logical');
        for r = 1:height(pw)
            key = strjoin(sort({levs{r}, levs2{r}}), '|');
            if ~seen.isKey(key)
                seen(key) = true;
                pwAll(end+1, :) = {levs{r}, levs2{r}, pw.pValue(r)}; %#ok<AGROW>
            end
        end
    catch
    end
    for b = 1:numel(betweenNames)
        try
            pw = multcompare(rmModel, betweenNames{b}, 'ComparisonType', ...
                mcType(opts.correction, 'rm'));
            la = pw.(betweenNames{b} + "_1");
            lb = pw.(betweenNames{b} + "_2");
            if ~iscell(la); la = cellstr(string(la)); end
            if ~iscell(lb); lb = cellstr(string(lb)); end
            seen = containers.Map('KeyType','char','ValueType','logical');
            for r = 1:height(pw)
                key = strjoin(sort({la{r}, lb{r}}), '|');
                if ~seen.isKey(key)
                    seen(key) = true;
                    pwAll(end+1, :) = {la{r}, lb{r}, pw.pValue(r)}; %#ok<AGROW>
                end
            end
        catch
        end
    end
    if ~isempty(pwAll)
        R.pairwise = cell2table(pwAll, 'VariableNames', {'groupA','groupB','p'});
    end
    R.note = sprintf('RM-ANOVA within=%s, between=[%s], F=%.3f, p=%.4g', wn, ...
        strjoin(betweenNames, ','), R.stat, R.p);
end


function s = mcType(corr, ctx)
    switch lower(corr)
        case 'auto'
            if strcmpi(ctx, 'rm'); s = 'tukey-kramer'; else; s = 'tukey-kramer'; end
        case 'tukey';      s = 'tukey-kramer';
        case 'bonferroni'; s = 'bonferroni';
        case 'holm';       s = 'bonferroni'; % multcompare doesn't have holm
        case 'none';       s = 'lsd';
        otherwise;         s = 'tukey-kramer';
    end
end

function results = evalActsLibrary(acts, ctx)
% EVALACTSLIBRARY  Evaluate every act in `acts` on `ctx` and return a
% containers.Map: name -> 1xN logical. Simple/special acts are processed
% first so complex acts can reference them.

    results = containers.Map();
    if isempty(acts); return; end

    % Pass 1: simple + special
    for k = 1:numel(acts)
        if ~strcmp(acts(k).type, 'complex')
            ctx.allActs = acts;
            ctx.resultsByName = results;
            results(acts(k).name) = sphynx.acts.applyAct(acts(k), ctx);
        end
    end
    % Pass 2: complex (now resultsByName is populated)
    for k = 1:numel(acts)
        if strcmp(acts(k).type, 'complex')
            ctx.allActs = acts;
            ctx.resultsByName = results;
            results(acts(k).name) = sphynx.acts.applyAct(acts(k), ctx);
        end
    end
end

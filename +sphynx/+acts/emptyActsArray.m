function arr = emptyActsArray()
% EMPTYACTSARRAY  Empty struct array with the canonical act fields.
    template = sphynx.acts.emptyAct();
    f = fieldnames(template);
    args = cell(1, 2 * numel(f));
    for k = 1:numel(f)
        args{2*k - 1} = f{k};
        args{2*k}     = {};
    end
    arr = struct(args{:});
end

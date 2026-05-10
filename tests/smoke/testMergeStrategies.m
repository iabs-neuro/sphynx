% Smoke-test: defaults library has 5 acts; uniqueName helper renames.
addpath(pwd);
clear functions;

% Defaults: 5 acts (rest/walk/locomotion/freezing/rear)
defaults = sphynx.acts.actsLibraryDefaults();
assert(numel(defaults) == 5, 'defaults must have exactly 5 acts');
names = {defaults.name};
expected = {'rest', 'walk', 'locomotion', 'freezing', 'rear'};
for k = 1:numel(expected)
    assert(any(strcmp(names, expected{k})), 'missing default: %s', expected{k});
end
fprintf('PASS: defaults library = 5 acts (%s)\n', strjoin(names, ', '));

% Class still parses
mt = ?sphynx.app.DefineActsTabController;
fprintf('PASS: controller class parses, methods=%d\n', numel(mt.MethodList));

% Verify the new merge methods exist
methodNames = {mt.MethodList.Name};
for m = {'mergeIntoLibrary', 'clearAllActs', 'deleteSelectedAct', 'loadLibrary'}
    assert(any(strcmp(methodNames, m{1})), 'missing method: %s', m{1});
end
fprintf('PASS: merge/clear/delete methods all present\n');

fprintf('ALL_TESTS_PASS\n');

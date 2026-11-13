% Smoke-test: defaults library has 7 acts; uniqueName helper renames.
addpath(pwd);
clear functions;

% Defaults: 7 acts (rest/walk/locomotion/freezing/rear/backing/turnaround)
defaults = sphynx.acts.actsLibraryDefaults();
assert(numel(defaults) == 7, 'defaults must have exactly 7 acts');
names = {defaults.name};
expected = {'rest', 'walk', 'locomotion', 'freezing', 'rear', 'backing', 'turnaround'};
for k = 1:numel(expected)
    assert(any(strcmp(names, expected{k})), 'missing default: %s', expected{k});
end
fprintf('PASS: defaults library = 7 acts (%s)\n', strjoin(names, ', '));

% Class still parses
mt = ?sphynx.app.DefineActsTabController;
fprintf('PASS: controller class parses, methods=%d\n', numel(mt.MethodList));

% Verify the new merge methods exist
methodNames = {mt.MethodList.Name};
for m = {'mergeIntoLibrary', 'clearAllActs', 'deleteSelectedAct', ...
         'loadLibrary', 'loadDefaults', 'loadBarnesDefaults', ...
         'appendDefaultsWithChoice'}
    assert(any(strcmp(methodNames, m{1})), 'missing method: %s', m{1});
end
fprintf('PASS: merge/clear/delete/load-defaults methods all present\n');

fprintf('ALL_TESTS_PASS\n');

function sessions = listSessions(video_dir, csv_dir)
%% 
% csv_dir = 'e:\Projects\BOWL\2wave\BehaviorData\0_Timestamps\';
% video_dir = 'e:\Projects\BOWL\2wave\BehaviorData\2_Combined\';

v = dir(fullfile(video_dir, '*.mp4'));
v2 = dir(fullfile(video_dir, '*.avi'));
videos = [v; v2];

csvs = dir(fullfile(csv_dir, '*.csv'));

pattern = '[A-Za-z0-9]{3,5}_[A-Za-z]{1,2}\d{2}_\d{1,2}[DT](_\d{1,2}T)?';
extract_key = @(name) regexp(name, pattern, 'match', 'once');

keys_v = arrayfun(@(x) extract_key(x.name), videos, 'uni', 0);
keys_c = arrayfun(@(x) extract_key(x.name), csvs, 'uni', 0);

sessions = [];
for i = 1:numel(videos)
    key = keys_v{i};
    idx = find(strcmp(keys_c, key));

    if isempty(idx)
        warning("Нет CSV для %s", videos(i).name);
        continue
    end

    s.name = key;
    s.video_file = fullfile(video_dir, videos(i).name);
    s.csv_file = fullfile(csv_dir, csvs(idx).name);

    sessions = [sessions; s];
end
end

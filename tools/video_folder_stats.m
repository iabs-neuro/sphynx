function T = video_folder_stats(folderPath)
% VIDEO_FOLDER_STATS  Collect frame count / duration / fps for all videos in a folder.
% Output table columns:
%   1) Name (file name without extension)
%   2) NumFrames
%   3) Duration_s
%   4) FPS

    if nargin < 1 || strlength(folderPath) == 0
        folderPath = pwd;
    end

    % ---- Check ffprobe availability
    [st, ~] = system('ffprobe -version');
    if st ~= 0
        error(['ffprobe not found in PATH. Install ffmpeg or add ffprobe.exe to PATH.\n' ...
               'Then rerun.']);
    end

    % ---- Extensions to include
    exts = {'.mp4','.avi','.mov','.mkv','.m4v'};
    files = [];
    for i = 1:numel(exts)
        files = [files; dir(fullfile(folderPath, ['*' exts{i}]))]; %#ok<AGROW>
    end
    if isempty(files)
        error('No video files found in: %s', folderPath);
    end

    % ---- Preallocate
    n = numel(files);
    Name       = strings(n,1);
    NumFrames  = nan(n,1);
    Duration_s = nan(n,1);
    FPS        = nan(n,1);

    for k = 1:n
        f = fullfile(files(k).folder, files(k).name);
        [~, baseName, ~] = fileparts(files(k).name);
        Name(k) = baseName;

        % ffprobe JSON output
        cmd = sprintf(['ffprobe -v error -select_streams v:0 ' ...
                       '-show_entries stream=nb_frames,avg_frame_rate,r_frame_rate ' ...
                       '-show_entries format=duration ' ...
                       '-of json "%s"'], f);

        [st, out] = system(cmd);
        if st ~= 0 || isempty(out)
            warning('ffprobe failed for: %s', f);
            continue;
        end

        try
            J = jsondecode(out);
        catch
            warning('Could not parse ffprobe JSON for: %s', f);
            continue;
        end

        % Duration
        if isfield(J, "format") && isfield(J.format, "duration") && ~isempty(J.format.duration)
            Duration_s(k) = str2double(J.format.duration);
        end

        % FPS: prefer avg_frame_rate, fallback to r_frame_rate
        fpsVal = NaN;
        if isfield(J, "streams") && ~isempty(J.streams)
            s = J.streams(1);

            if isfield(s, "avg_frame_rate")
                fpsVal = ratio_to_double(s.avg_frame_rate);
            end
            if (~isfinite(fpsVal) || fpsVal<=0) && isfield(s, "r_frame_rate")
                fpsVal = ratio_to_double(s.r_frame_rate);
            end

            FPS(k) = fpsVal;

            % Frames: nb_frames sometimes missing or "N/A" for some containers/VFR
            if isfield(s, "nb_frames") && ~isempty(s.nb_frames)
                nf = str2double(string(s.nb_frames));
                if isfinite(nf) && nf > 0
                    NumFrames(k) = nf;
                end
            end
        end

        % If nb_frames not available, estimate as duration*fps
        if (~isfinite(NumFrames(k)) || NumFrames(k)<=0) && isfinite(Duration_s(k)) && isfinite(FPS(k)) && FPS(k)>0
            NumFrames(k) = round(Duration_s(k) * FPS(k));
        end
    end

    T = table(Name, NumFrames, Duration_s, FPS);

    % ---- Save рядом с видео
    outXlsx = fullfile(folderPath, 'video_stats.xlsx');
    outCsv  = fullfile(folderPath, 'video_stats.csv');

    try
        writetable(T, outXlsx);
    catch
        warning('Could not write XLSX (maybe Excel engine issue). Writing CSV only.');
    end
    writetable(T, outCsv);

    fprintf('Saved:\n  %s\n  %s\n', outXlsx, outCsv);
end
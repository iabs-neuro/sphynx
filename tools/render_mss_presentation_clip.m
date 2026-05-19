function render_mss_presentation_clip()
% Final deliverables for the MSS_H33_2D_1T presentation slide:
%   1. <stem>_presentation_60s.mp4 - Analyze Session behavior video,
%      first 60 s, presentation styling (baked baseline = approved look).
%   2. <stem>_original_60s.mp4 - the SAME first N frames of the raw
%      source video, no overlay, for synchronous side-by-side playback.
%
% Mirrors AnalyzeSessionTabController.runAnalyze: defaultConfig + DLC +
% preset + custom acts library, headless.

    base   = 'C:\Users\User\YandexDisk\_Projects\MSS';
    video  = fullfile(base, 'BehaviorData', '2_Combined', 'MSS_H33_2D_1T.mp4');
    dlc    = fullfile(base, 'BehaviorData', '3_DLC', ...
        'MSS_H33_2D_1TDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    preset = fullfile(base, 'diploma', 'MSS_H33_2D_1T', 'MSS_H33_2D_1T_Preset.mat');
    lib    = fullfile(base, 'diploma', 'MSS_acts_library.mat');
    ffmpeg = 'C:\ffmpeg\bin\ffmpeg.exe';

    outDir = fullfile(base, 'BehaviorData', 'Analyze_out', 'MSS_H33_2D_1T');
    if ~isfolder(outDir); mkdir(outDir); end

    assert(isfile(video),  'missing video: %s',  video);
    assert(isfile(dlc),    'missing dlc: %s',    dlc);
    assert(isfile(preset), 'missing preset: %s', preset);
    assert(isfile(lib),    'missing acts library: %s', lib);
    assert(isfile(ffmpeg), 'missing ffmpeg: %s', ffmpeg);

    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc        = dlc;
    cfg.paths.preset     = preset;
    cfg.paths.outDir     = outDir;
    cfg.acts.libraryPath = lib;
    cfg.io.saveWorkspace = false;
    cfg.viz.headless     = true;
    cfg.verbose          = 'info';

    fprintf('Running analyzeSession ...\n');
    result = sphynx.pipeline.analyzeSession(cfg);
    fprintf('analyzeSession OK: %d acts, %d frames\n', ...
        numel(result.Acts), result.n_frames);

    fps    = result.Options.FrameRate;
    durSec = 60;
    startF = 1;
    endF   = min(result.n_frames, startF + round(durSec * fps) - 1);
    nFr    = endF - startF + 1;
    fprintf('fps=%.3f  range=[%d %d]  (%d frames, %.1f s)\n', ...
        fps, startF, endF, nFr, nFr / fps);

    % --- 1. Presentation clip (baked baseline = approved look) ----------
    presName = 'MSS_H33_2D_1T_presentation_60s.mp4';
    feat = struct('trajectory', true, 'velocity', true, ...
                  'actsList', true, 'zones', true, 'presentation', true);
    fprintf('--- presentation -> %s\n', presName);
    presPath = sphynx.pipeline.renderActsVideo(result, video, outDir, ...
        'Range', [startF endF], ...
        'Features', feat, ...
        'OutputName', presName, ...
        'ProgressFcn', @(v, m) fprintf('  %3.0f%% %s\n', 100*v, m));
    fprintf('  DONE -> %s\n', presPath);

    % --- 2. Plain original, same first nFr frames -----------------------
    origPath = fullfile(outDir, 'MSS_H33_2D_1T_original_60s.mp4');
    cmd = sprintf(['"%s" -y -i "%s" -frames:v %d ' ...
        '-c:v libx264 -crf 18 -preset veryfast -an "%s"'], ...
        ffmpeg, video, nFr, origPath);
    fprintf('--- original (ffmpeg, %d frames) -> %s\n', nFr, origPath);
    [st, out] = system(cmd);
    if st ~= 0
        error('ffmpeg failed (%d):\n%s', st, out);
    end
    fprintf('  DONE -> %s\n', origPath);

    fprintf('ALL DONE in %s\n', outDir);
end

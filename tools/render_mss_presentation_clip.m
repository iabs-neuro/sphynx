function render_mss_presentation_clip()
% Reproduce the Analyze Session behavior video for MSS_H33_2D_1T in
% presentation mode. Runs analyzeSession once, then renders several
% SHORT (5 s) sample clips at different presentation font scales so the
% user can pick a font size.
%
% Mirrors AnalyzeSessionTabController.runAnalyze: defaultConfig + DLC +
% preset + custom acts library, headless. (The Analyze pipeline does not
% consume *_PreprocessSettings.mat; per-part params come from the preset.)

    base   = 'C:\Users\User\YandexDisk\_Projects\MSS';
    video  = fullfile(base, 'BehaviorData', '2_Combined', 'MSS_H33_2D_1T.mp4');
    dlc    = fullfile(base, 'BehaviorData', '3_DLC', ...
        'MSS_H33_2D_1TDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    preset = fullfile(base, 'diploma', 'MSS_H33_2D_1T', 'MSS_H33_2D_1T_Preset.mat');
    lib    = fullfile(base, 'diploma', 'MSS_acts_library.mat');

    outDir = fullfile(base, 'BehaviorData', 'Analyze_out', 'MSS_H33_2D_1T');
    if ~isfolder(outDir); mkdir(outDir); end

    assert(isfile(video),  'missing video: %s',  video);
    assert(isfile(dlc),    'missing dlc: %s',    dlc);
    assert(isfile(preset), 'missing preset: %s', preset);
    assert(isfile(lib),    'missing acts library: %s', lib);

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
    durSec = 5;
    startF = 1;
    endF   = min(result.n_frames, startF + round(durSec * fps) - 1);
    fprintf('fps=%.3f  range=[%d %d]  (%.1f s)\n', ...
        fps, startF, endF, (endF - startF + 1) / fps);

    % Font-size sweep. presScale 1.0 = tuned baseline (acts font 48,
    % Speed 38, Speed_act/Zone 34). Acts font per variant in the name.
    scales = [0.85 1.00 1.25];
    for s = scales
        actsPt = round(48 * s);
        name = sprintf('MSS_H33_2D_1T_pres_font%02d.mp4', actsPt);
        feat = struct('trajectory', true, 'velocity', true, ...
                      'actsList', true, 'zones', true, ...
                      'presentation', true, 'presScale', s);
        fprintf('--- variant scale=%.2f actsFont=%d -> %s\n', s, actsPt, name);
        outPath = sphynx.pipeline.renderActsVideo(result, video, outDir, ...
            'Range', [startF endF], ...
            'Features', feat, ...
            'OutputName', name, ...
            'ProgressFcn', @(v, m) fprintf('  %3.0f%% %s\n', 100*v, m));
        fprintf('  DONE -> %s\n', outPath);
    end

    fprintf('ALL DONE in %s\n', outDir);
end

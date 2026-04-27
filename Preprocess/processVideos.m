function processVideos(video_dir, csv_dir, varargin)
% processVideos  — главный управляющий модуль.
%
% Параметры (опционально):
%   'TargetFPS'           — итоговый FPS для перекодирования (по умолчанию 30)
%   'FPSTolerance'        — допуск FPS (по умолчанию 1)
%   'FrameMatchTolerance' — допустимое расхождение числа кадров (1–10)
%   'SigmaThreshold'      — множитель σ для определения выбросов (по умолчанию 4)
%   'Codec'               — 'copy' | 'H264' | 'MPEG4' | ...
%   'recode'              — флаг для перекодирования видео с приведением
%   fps к TargetFPS
% !! recode = 1 нужно тестировать

% Пример:
% processVideos('video', 'csv', 'TargetFPS', 50, 'FPSTolerance', 1)
video_dir = 'e:\Projects\3DM\BehaviorData\3wave\2_Combined\';
csv_dir= 'e:\Projects\3DM\BehaviorData\3wave\0_TimeStamps\';
varargin = {'TargetFPS', 30, 'Codec', 'copy', 'FPSTolerance', 1};

%% ================== ПАРСИНГ ВХОДНЫХ ПАРАМЕТРОВ ===========================
p = inputParser;
addParameter(p, 'TargetFPS', 30);
addParameter(p, 'FPSTolerance', 1);
addParameter(p, 'FrameMatchTolerance', 10);
addParameter(p, 'SigmaThreshold', 6);
addParameter(p, 'Codec', 'copy');
addParameter(p, 'Recode', 0);
parse(p, varargin{:});
cfg = p.Results;

%% ================== ПОДГОТОВКА ===========================================
fprintf('=== PROCESS VIDEOS STARTED ===\n');
logFile = fullfile(video_dir, 'processing_log.txt');
logFID = fopen(logFile, 'w');

fprintf(logFID, 'Start time: %s\n', datestr(now));

sessions = listSessions(video_dir, csv_dir);
N = numel(sessions);
fprintf("Найдено %d сессий.\n", N);
fprintf(logFID, "Found %d sessions\n", N);

results = [];

wrongDir = fullfile(video_dir, 'wrong_fps');
if ~exist(wrongDir, 'dir'); mkdir(wrongDir); end

%% ================== ОБРАБОТКА КАЖДОЙ СЕССИИ ==============================
wb = waitbar(0, 'Обработка сессий...');

for i = 1:N
    waitbar(i/N, wb, sprintf("Сессия %d/%d", i, N));
    s = sessions(i);

    fprintf("---- Обработка %s ----\n", s.name);
    fprintf(logFID, "Processing %s\n", s.name);

    % ---------- Видео ----------
    vidMeta = getVideoMetadata(s.video_file);

    % ---------- Timestamp таблица ----------
    tsMeta = getTimestampMetadata(s.csv_file, cfg.SigmaThreshold);

    % ---------- Анализ ----------
    analysis = analyzeSession(vidMeta, tsMeta, cfg.FPSTolerance, cfg.FrameMatchTolerance);

    % ---------- Действия: исправить / перекодировать ----------
    action = 'none';
    output_video = s.video_file;
    output_csv = s.csv_file;

    if analysis.fps_wrong
        real_fps = tsMeta.real_fps;

        if cfg.Recode
            % --- ПЕРЕКОДИРОВАНИЕ --- (выкидывает лишние кадры)
            fprintf("Перекодирование %s к %d fps\n", s.name, cfg.TargetFPS);
            fprintf(logFID, "Recode to %d fps\n", cfg.TargetFPS);

            [output_video, output_csv] = recodeVideoToFPS( ...
                s.video_file, s.csv_file, wrongDir, cfg.TargetFPS, cfg.Codec);

            action = 'recode';

        else
            % --- ИСПРАВЛЕНИЕ МЕТАДАТЫ --- (сохраняет количество кадров)
            fprintf("Исправляем метадату FPS → %.2f\n", real_fps);
            fprintf(logFID, "Fix metadata\n");

            output_video = fixFPSmetadata(s.video_file, wrongDir, real_fps);
            action = 'fix_metadata';
        end
    end

    % ---------- Построение графиков ----------
    plotDir = fullfile(video_dir, 'plots');
    if ~exist(plotDir, 'dir'); mkdir(plotDir); end
    generatePlots(s, vidMeta, tsMeta, analysis, plotDir);

    % ---------- Сбор результата ----------
    results = [results; makeResultRow(s, vidMeta, tsMeta, analysis, action, output_video, output_csv, plotDir)];
end

close(wb);

% ============ СОХРАНЕНИЕ ТАБЛИЦЫ =======================================
summaryFile = fullfile(video_dir, 'results_summary.csv');
writetable(struct2table(results), summaryFile);

fprintf("Готово. Summary сохранён: %s\n", summaryFile);
fprintf(logFID, "Finished\n");
fclose(logFID);
end

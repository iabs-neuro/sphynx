function batch_reencode_videos(inputDir, outputDir)
% batch_reencode_videos  Перекодирует все AVI-видео в указанной папке в .mp4 (H.264)
%                        и сохраняет их в другой папке.
%
% Пример:
%   batch_reencode_videos('d:\Projects\3DM\CalciumData\2wave\2_Combined\2.2_CombinedMC\', 'd:\Projects\3DM\CalciumData\2wave\2_Combined\3fbgvz\');

%
% Требуется установленный ffmpeg и доступный в PATH.
%
% Для каждого input.avi создается outputDir\input_avi.mp4

    if nargin < 1 || ~isfolder(inputDir)
        error('Укажи существующую входную папку, например: batch_reencode_videos(''C:\data'')');
    end
    if nargin < 2
        outputDir = inputDir;  % если не указали — сохраняем в ту же папку
    end
    if ~isfolder(outputDir)
        mkdir(outputDir);
        fprintf('Создана выходная папка: %s\n', outputDir);
    end

    files = dir(fullfile(inputDir, '*.mp4'));
    if isempty(files)
        fprintf('В папке %s нет AVI-файлов.\n', inputDir);
        return
    end

    fprintf('Найдено %d AVI-файлов в %s\n', numel(files), inputDir);
    fprintf('Результаты будут сохранены в %s\n', outputDir);

    for k = 1:numel(files)
        inFile = fullfile(files(k).folder, files(k).name);
        [~, baseName, ~] = fileparts(inFile);
        outFile = fullfile(outputDir, [baseName '.mp4']);

        % ffmpeg команда
        cmd = sprintf('ffmpeg -y -i "%s" -c:v libx264 -preset fast -crf 23 "%s"', inFile, outFile);

        fprintf('\n[%d/%d] Перекодирую:\n  %s\n', k, numel(files), inFile);
        status = system(cmd);

        if status == 0
            fprintf('  ✔ Сохранено: %s\n', outFile);
        else
            fprintf('  ✖ Ошибка при перекодировании %s\n', inFile);
        end
    end

    fprintf('\nГотово. Все перекодированные файлы находятся в %s\n', outputDir);
end

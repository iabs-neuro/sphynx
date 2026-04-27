function trim_video(infile, outfile, x1, x2)
% TRIM_VIDEO   Вырезает видеофрагмент с кадров x1..x2 (1-based, включительно).
% Пример:
%   trim_video('in.mp4','out.mp4', 301, 1200)

    vr = VideoReader(infile);

    % Если x2 не задан/бесконечность — режем до конца
    if nargin < 4 || isinf(x2)
        x2 = floor(vr.FrameRate * vr.Duration); % оценка числа кадров
    end

    if x1 < 1 || x2 < x1
        error('Некорректные границы: x1 >= 1 и x2 >= x1.');
    end

    % Подбираем профиль по расширению outfile (если не указали — наследуем от infile)
    [~,~,extOut] = fileparts(outfile);
    if isempty(extOut)
        [~,~,extIn] = fileparts(infile);
        outfile = [outfile extIn];
        extOut = extIn;
    end

    switch lower(extOut)
        case {'.mp4', '.m4v'}
            vw = VideoWriter(outfile, 'MPEG-4'); % H.264
            vw.Quality = 100;                    % максимум качества кодера
        case '.avi'
            % Наиболее совместимый вариант для AVI
            vw = VideoWriter(outfile, 'Motion JPEG AVI');
        otherwise
            % Пустой профиль — MATLAB выберет дефолтный под контейнер
            vw = VideoWriter(outfile);
    end

    % Сохраняем fps исходного видео
    vw.FrameRate = vr.FrameRate;
    open(vw);

    % Проматываем до кадра x1
    k = 0;
    while hasFrame(vr) && k < (x1 - 1)
        readFrame(vr);
        k = k + 1;
    end

    % Пишем кадры x1..x2 (включительно)
    while hasFrame(vr) && k < x2
        frame = readFrame(vr);
        k = k + 1;
        writeVideo(vw, frame);
    end

    close(vw);
    fprintf('Готово: %s (кадры %d..%d)\n', outfile, x1, min(k, x2));
end

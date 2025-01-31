function combinedFrame = append_graph_to_frame(videoFrame, graphImage, graphHeightRatio)

    % Приведение размеров графика к ширине видео и graphHeightRatio % высоты
    videoHeight = size(videoFrame, 1);
    videoWidth = size(videoFrame, 2);
    
    % Высота графика равна 10% от высоты видео
    graphHeight = round(videoHeight * graphHeightRatio);

    % Изменение размера графика по ширине видео и заданной высоте
    graphImageResized = imresize(graphImage, [graphHeight videoWidth]);

    % Комбинируем видео-кадр и график (добавляем график снизу кадра)
    combinedFrame = [videoFrame; graphImageResized];
end
function T = getTimestampMetadata(csv_file, sigmaK)
raw = readmatrix(csv_file);
timestamps = raw(:);

dt = diff(timestamps) / 1e7; % секунды

mu = mean(dt);
sigma = std(dt);

threshold = mu + sigmaK * sigma;
outliers = dt > threshold;

T.filename = csv_file;
T.numFrames = numel(timestamps);
T.duration_s = round((timestamps(end) - timestamps(1)) / 1e7, 2);
T.duration_min = round(T.duration_s/60,2);
T.real_fps = (T.numFrames-1) / T.duration_s;

T.dt = dt;
T.mean_dt = mu;
T.sigma_dt = sigma;
T.threshold = threshold;
T.num_outliers = sum(outliers);
T.outliers = outliers;
end

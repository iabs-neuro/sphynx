function R = makeResultRow(s, V, T, A, action, out_video, out_csv, plotDir)

R.session = s.name;

R.video_file = s.video_file;
R.csv_file = s.csv_file;

R.video_fps = V.fps;
R.real_fps = T.real_fps;

R.fps_wrong_flag = A.fps_wrong;
R.frame_drop_flag = A.frame_drop_flag;
R.frame_diff = A.frame_diff;

R.video_est_frames = V.numFrames_est;
R.csv_frames = T.numFrames;
R.video_duration = V.duration_s;
R.csv_duration = T.duration_s;

R.num_outliers = T.num_outliers;

R.action = action;
R.output_video = out_video;
R.output_csv = out_csv;

R.plots = plotDir;
end

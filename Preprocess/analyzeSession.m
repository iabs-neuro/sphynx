function A = analyzeSession(V, T, fps_tol, frame_tol)

A.fps_wrong = abs(V.fps - T.real_fps) > fps_tol;
A.frame_diff = abs(V.numFrames_est - T.numFrames);
A.frame_drop_flag = A.frame_diff > frame_tol;
end

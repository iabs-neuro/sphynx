function [Indexes, SyncLineBehav, SyncLineCalcium, TimeLineBehav, TimeLineCalcium, FrameRate] = synchronizer(LineBehav, LineCalcium, CorrectionTrackMode, TimeSession)
% vvp 16.20.24
% synchronization of two timeline in case of no dropped frames, time session
% is accurate defined

% LineBehav = (1:video.NumFrames)'; 
% LineCalcium = neuronActivity;
% CorrectionTrackMode = 'Bonsai';
% TimeSession = 600;

switch CorrectionTrackMode
    case 'Bonsai'
        TimeLineBehav = (0:TimeSession/(length(LineBehav)-1):TimeSession);
        TimeLineCalcium = (0:TimeSession/(length(LineCalcium)-1):TimeSession);
        Indexes = [];
        for fname = 1:length(TimeLineCalcium)
            TempArray = abs(TimeLineBehav - TimeLineCalcium(fname));
            [~, ind] = min(TempArray);
            Indexes = [Indexes ind];
        end
        
        SyncLineCalcium = LineCalcium;
        SyncLineBehav = LineBehav(Indexes);

        FrameRate = length(SyncLineBehav)/TimeSession;
        fprintf('Количество кадров видеотрекинга и кальция %d %d. fps: %2.2f\n',length(SyncLineBehav),length(LineCalcium),FrameRate);
end

end
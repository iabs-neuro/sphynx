# sphynx
SPHYNX - Segmented PHYsical aNalysis of eXploration

Download this videos in folder Demo/Video for demo analysis:
https://disk.yandex.ru/i/8ULS0Vg3Q27tPQ
https://disk.yandex.ru/i/s45V4KR61tt6HA

Documentation is under development, please write to Viktor Plusnin for any questions witkax@mail.ru

## Running tests (sphynx-GUI branch)

From MATLAB Command Window, with the repo root as the current folder:

```matlab
startup                            % once per MATLAB session, adds paths
runAllTests('tag','fast')          % unit + synthetic + smoke (~30 sec)
runAllTests('tag','full')          % adds golden regression (~9 min)
runAllTests('tag','golden')        % golden only
```

To rebuild the golden snapshot (after a known intentional change):

```matlab
run(fullfile(sphynx.util.repoRoot(),'tests','golden','buildSnapshots.m'))
```

Tests run with `SPHYNX_HEADLESS=1` set automatically — no figures or videos
are written by tests.


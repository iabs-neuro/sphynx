# Pass 0 homework

Status: waiting on you. Nothing else proceeds until you send the output of these commands.

## What to run

In MATLAB Command Window:

```matlab
cd 'C:\Users\User\pycharmprojects\sphynx'
startup
runAllTests('tag','fast')
run(fullfile(sphynx.util.repoRoot(),'tests','golden','buildSnapshots.m'))
```

## Expected output

### `runAllTests('tag','fast')`

```
Running 8 tests (tag=fast)
...
=== Summary ===
Total:   8
Passed:  7
Failed:  0
Skipped: 1
```

Breakdown:
- 7 passed: sanityTest (2) + logTest (5)
- 1 skipped: smoke placeholder (intentional, real test arrives in Pass B)

### `buildSnapshots`

```
[INFO] Reading <repo>\Demo\Behavior\NOF_H01_1D\<date>_1\NOF_H01_1D_WorkSpace.mat
[INFO] Wrote <repo>\tests\golden\snapshots\NOF_H01_1D_Acts.mat (1.x KB)
```

After this, the file `tests/golden/snapshots/NOF_H01_1D_Acts.mat` should exist.

## What I do after you send output

1. If anything failed - I fix and send updated homework.
2. If all green - I:
   - commit the snapshot .mat
   - tag `stage-c-pass-0-complete`
   - immediately start Pass A.1 (zones, Bug-1 fix)

## How to send output

Just copy-paste from PowerShell or MATLAB Command Window into the chat. No formatting needed.

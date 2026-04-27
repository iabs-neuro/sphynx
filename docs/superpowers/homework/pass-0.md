# Pass 0 homework

Status: waiting on you (re-run runAllTests after the fix).

## What's done

- buildSnapshots ran successfully — `tests/golden/snapshots/NOF_H01_1D_Acts.mat` exists, committed.
- runAllTests was buggy (TestSuite is abstract); fixed in commit `ae69270`.

## What to run now

```matlab
runAllTests('tag','fast')
```

(no need to re-run startup unless you closed MATLAB.)

## Expected output

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

## What I do after you send output

1. If anything failed - I fix and ask for re-run.
2. If green - I tag `stage-c-pass-0-complete` and immediately start Pass A.1 (zones, Bug-1 fix).

## How to send output

Just copy-paste from PowerShell/MATLAB into the chat.

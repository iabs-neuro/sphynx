# Pass A.2 homework

Status: waiting on you.

## What was added

Pass A.2 — angles (Bug-2 fix):

- `+sphynx/+angles/wrap.m`              + 6 unit tests (wrapTest)
- `+sphynx/+angles/unwrapForSmooth.m`   + 4 unit tests (unwrapForSmoothTest)
- `+sphynx/+angles/headDirection.m`     (covered by synthetic test)
- `+sphynx/+testing/makeRotatingMouseDLC.m`  (fixture: 720 deg rotation)
- `tests/synthetic/headDirectionContinuityTest.m`  + 3 synthetic tests

## What to run

```matlab
runAllTests('tag','fast')
```

## Expected output

```
Running 51 tests (tag=fast)
...
=== Summary ===
Total:   51
Passed:  50
Failed:  0
Skipped: 1
```

Cumulative breakdown of 50 passed:

Pass 0 (7):
- sanityTest:            2
- logTest:               5

Pass A.1 (30):
- circleFitTest:         5
- polygonFitTest:        3
- inMaskSafeTest:        5
- partitionStripsTest:   5
- classifyCircleTest:    5
- classifySquareTest:    5
- zoneVisitTest:         2  (synthetic)

Pass A.2 (13, NEW):
- wrapTest:              6
- unwrapForSmoothTest:   4
- headDirectionContinuityTest: 3  (synthetic)

1 skipped: smoke placeholder (intentional).

## What I do after you send output

1. If anything failed - paste output below this section, I fix and iterate.
2. If green - tag `stage-c-pass-A2-angles-fixed` and start Pass A.3 (velocity & smoothing, Bug-3 + Bug-4).

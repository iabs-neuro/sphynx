# Pass A.1 homework

Status: waiting on you.

## What was added since last homework

Pass A.1 — zones (Bug-1 fix + feature 1.3 partitioning):

- `+sphynx/+util/circleFit.m`        + 5 unit tests
- `+sphynx/+util/polygonFit.m`       + 3 unit tests
- `+sphynx/+util/inMaskSafe.m`       + 5 unit tests
- `+sphynx/+zones/partitionStrips.m` + 5 unit tests
- `+sphynx/+zones/classifyCircle.m`  + 5 unit tests
- `+sphynx/+zones/classifySquare.m`  + 5 unit tests
- `+sphynx/+testing/makeArenaAtFrameEdgeDLC.m`  (fixture)
- `+sphynx/+testing/makeZoneCrossDLC.m`         (fixture)
- `tests/synthetic/zoneVisitTest.m`   + 2 synthetic tests (Bug-1 + zone crossing)

## What to run

```matlab
runAllTests('tag','fast')
```

(no need to re-run startup unless MATLAB session restarted.)

## Expected output

```
Running 38 tests (tag=fast)
...
=== Summary ===
Total:   38
Passed:  37
Failed:  0
Skipped: 1
```

Breakdown of 37 passed:
- sanityTest:        2
- logTest:           5
- circleFitTest:     5
- polygonFitTest:    3
- inMaskSafeTest:    5
- partitionStripsTest: 5
- classifyCircleTest:  5
- classifySquareTest:  5
- zoneVisitTest:     2  (synthetic)

1 skipped: smoke placeholder (intentional).

## What I do after you send output

1. If anything failed - I fix and ask for re-run.
2. If green - tag `stage-c-pass-A1-zones-fixed` and start Pass A.2 (angles, Bug-2).

## How to send output

Just copy-paste the summary block. If something fails, also paste the failing test name and error message so I can target the fix.

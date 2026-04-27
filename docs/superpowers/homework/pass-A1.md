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

runAllTests('tag','fast')
Running 38 tests (tag=fast)
Running circleFitTest
.....
Done circleFitTest
__________

Running classifyCircleTest

================================================================================
Verification failed in classifyCircleTest/testSmallArenaWallAndCenter.
    ---------------------
    Framework Diagnostic:
    ---------------------
    verifyFalse failed.
    --> The value must evaluate to "false".
    
    Actual Value:
      logical
    
       1
    ------------------
    Stack Information:
    ------------------
    In C:\Users\User\PycharmProjects\sphynx\tests\unit\classifyCircleTest.m (testSmallArenaWallAndCenter) at 15
================================================================================
.
================================================================================
Verification failed in classifyCircleTest/testLargeArenaWithMiddleRings.
    ---------------------
    Framework Diagnostic:
    ---------------------
    verifyTrue failed.
    --> The value must evaluate to "true".
    
    Actual Value:
      logical
    
       0
    ------------------
    Stack Information:
    ------------------
    In C:\Users\User\PycharmProjects\sphynx\tests\unit\classifyCircleTest.m (testLargeArenaWithMiddleRings) at 29
================================================================================
....
Done classifyCircleTest
__________

Running classifySquareTest
.....
Done classifySquareTest
__________

Running inMaskSafeTest
.....
Done inMaskSafeTest
__________

Running logTest
.....
Done logTest
__________

Running partitionStripsTest
.....
Done partitionStripsTest
__________

Running polygonFitTest
...
Done polygonFitTest
__________

Running sanityTest
..
Done sanityTest
__________

Running zoneVisitTest
..
Done zoneVisitTest
__________

Running demoPipelineTest

================================================================================
demoPipelineTest/testNOF_H01_1D_runsWithoutError was filtered.
    Test Diagnostic: pass-0 placeholder; real test arrives in Pass B
Details
================================================================================
.
Done demoPipelineTest
__________

Failure Summary:

     Name                                              Failed  Incomplete  Reason(s)
    ===============================================================================================
     classifyCircleTest/testSmallArenaWallAndCenter      X                 Failed by verification.
    -----------------------------------------------------------------------------------------------
     classifyCircleTest/testLargeArenaWithMiddleRings    X                 Failed by verification.
    -----------------------------------------------------------------------------------------------
     demoPipelineTest/testNOF_H01_1D_runsWithoutError              X       Filtered by assumption.

=== Summary ===
Total:   38
Passed:  35
Failed:  2
Skipped: 1
Warning: 2 failed, 1 incomplete 
> In runAllTests (line 71) 

ans = 

  1×38 TestResult array with properties:

    Name
    Passed
    Failed
    Incomplete
    Duration
    Details

Totals:
   35 Passed, 2 Failed (rerun), 1 Incomplete.
   1.1674 seconds testing time.

---

## Iteration 2 — fix for classifyCircle

Both failures were in `classifyCircle` semantics, not random bugs.

What I fixed:
- Algorithm in `+sphynx/+zones/classifyCircle.m` rewritten to the cleaner greedy form: keep adding 20cm middles only while another middle would still leave at least `MinCenterCm` for the center disk.
- `testLargeArenaWithMiddleRings` (R=80): expected `middle3` added (R=80 supports 3 middles + 10cm center).
- `testNoCenterIfTooSmall`: changed R from 25 to 15 so the test actually exercises «no center» (for R=25, center DOES exist with 15cm radius, so the old assertion was wrong).

Re-run:

```matlab
runAllTests('tag','fast')
```

Expected now: **38/0/1** (37 passed, 0 failed, 1 skipped — same as plan).

If still failing — paste output below this line and I'll iterate again.


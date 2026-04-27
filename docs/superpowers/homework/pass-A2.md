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

 runAllTests('tag','fast')
Running 51 tests (tag=fast)
Running circleFitTest
.....
Done circleFitTest
__________

Running classifyCircleTest
.....
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

Running unwrapForSmoothTest

================================================================================
Error occurred in unwrapForSmoothTest/testConstantInputUnchanged and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in unwrapForSmoothTest>testConstantInputUnchanged (line 7)
        out = sphynx.angles.unwrapForSmooth(in, 11);
================================================================================
.
================================================================================
Error occurred in unwrapForSmoothTest/testNoArtifactAcrossDiscontinuity and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in unwrapForSmoothTest>testNoArtifactAcrossDiscontinuity (line 17)
        out = sphynx.angles.unwrapForSmooth(raw, 11);
================================================================================
.
================================================================================
Error occurred in unwrapForSmoothTest/testOutputInRange and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in unwrapForSmoothTest>testOutputInRange (line 25)
        out = sphynx.angles.unwrapForSmooth(in, 11);
================================================================================
.
================================================================================
Error occurred in unwrapForSmoothTest/testRespectsWindowSize and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in unwrapForSmoothTest>testRespectsWindowSize (line 32)
        out11 = sphynx.angles.unwrapForSmooth(in, 11);
================================================================================
.
Done unwrapForSmoothTest
__________

Running wrapTest
......
Done wrapTest
__________

Running headDirectionContinuityTest

================================================================================
Error occurred in headDirectionContinuityTest/testNoLargeJumpsAfterSmoothing and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in sphynx.angles.headDirection (line 22)
            hd = sphynx.angles.unwrapForSmooth(raw, smoothWindow);
    
    Error in headDirectionContinuityTest>testNoLargeJumpsAfterSmoothing (line 8)
        hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
================================================================================
.
================================================================================
Error occurred in headDirectionContinuityTest/testHDinValidRange and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in sphynx.angles.headDirection (line 22)
            hd = sphynx.angles.unwrapForSmooth(raw, smoothWindow);
    
    Error in headDirectionContinuityTest>testHDinValidRange (line 17)
        hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
================================================================================
.
================================================================================
Error occurred in headDirectionContinuityTest/testTotalRotationApproximatelyCorrect and it did not run to completion.
    ---------
    Error ID:
    ---------
    'MATLAB:UndefinedFunction'
    --------------
    Error Details:
    --------------
    Undefined function 'smooth' for input arguments of type 'double'.
    
    Error in sphynx.angles.unwrapForSmooth (line 28)
            smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    
    Error in sphynx.angles.headDirection (line 22)
            hd = sphynx.angles.unwrapForSmooth(raw, smoothWindow);
    
    Error in headDirectionContinuityTest>testTotalRotationApproximatelyCorrect (line 24)
        hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
================================================================================
.
Done headDirectionContinuityTest
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

     Name                                                               Failed  Incomplete  Reason(s)
    ================================================================================================================
     unwrapForSmoothTest/testConstantInputUnchanged                       X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     unwrapForSmoothTest/testNoArtifactAcrossDiscontinuity                X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     unwrapForSmoothTest/testOutputInRange                                X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     unwrapForSmoothTest/testRespectsWindowSize                           X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     headDirectionContinuityTest/testNoLargeJumpsAfterSmoothing           X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     headDirectionContinuityTest/testHDinValidRange                       X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     headDirectionContinuityTest/testTotalRotationApproximatelyCorrect    X         X       Errored.
    ----------------------------------------------------------------------------------------------------------------
     demoPipelineTest/testNOF_H01_1D_runsWithoutError                               X       Filtered by assumption.

=== Summary ===
Total:   51
Passed:  43
Failed:  7
Skipped: 8
Warning: 7 failed, 8 incomplete 
> In runAllTests (line 71) 

ans = 

  1×51 TestResult array with properties:

    Name
    Passed
    Failed
    Incomplete
    Duration
    Details

Totals:
   43 Passed, 7 Failed (rerun), 8 Incomplete.
   0.22133 seconds testing time.

---

## Iteration 2 — fix smooth toolbox dependency

All 7 failures had the same root cause: `Undefined function 'smooth'`. `smooth(...)` is from Curve Fitting Toolbox, which is not available in your MATLAB session. Replaced with `sgolayfilt(...)` from Signal Processing Toolbox (same Savitzky-Golay math, no toolbox issue).

Saved as project memory so future passes won't reintroduce `smooth`.

Re-run (with cache clear — MATLAB caches package functions):

```matlab
clear functions
runAllTests('tag','fast')
```

Expected: **51/0/1** (50 passed, 0 failed, 1 skipped).

If still seeing the old `smooth(...)` error after `clear functions`, try `clear classes` or restart MATLAB.


новое
runAllTests('tag','fast')
Running 51 tests (tag=fast)
Running circleFitTest
.....
Done circleFitTest
__________

Running classifyCircleTest
.....
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

Running unwrapForSmoothTest
....
Done unwrapForSmoothTest
__________

Running wrapTest
......
Done wrapTest
__________

Running headDirectionContinuityTest
..
================================================================================
Verification failed in headDirectionContinuityTest/testTotalRotationApproximatelyCorrect.
    ---------------------
    Framework Diagnostic:
    ---------------------
    verifyEqual failed.
    --> The numeric values are not equal using "isequaln".
    --> The error was not within absolute tolerance.
    --> Failure table:
                 Actual             Expected              Error              RelativeError        AbsoluteTolerance
            ________________    ________________    __________________    ____________________    _________________
        
            12.4616508592395    12.5663706143592    -0.104719755119666    -0.00833333333333381           0.1       
    
    Actual Value:
      12.461650859239507
    Expected Value:
      12.566370614359172
    ------------------
    Stack Information:
    ------------------
    In C:\Users\User\PycharmProjects\sphynx\tests\synthetic\headDirectionContinuityTest.m (testTotalRotationApproximatelyCorrect) at 28
================================================================================
.
Done headDirectionContinuityTest
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

     Name                                                               Failed  Incomplete  Reason(s)
    ================================================================================================================
     headDirectionContinuityTest/testTotalRotationApproximatelyCorrect    X                 Failed by verification.
    ----------------------------------------------------------------------------------------------------------------
     demoPipelineTest/testNOF_H01_1D_runsWithoutError                               X       Filtered by assumption.

=== Summary ===
Total:   51
Passed:  49
Failed:  1
Skipped: 1
Warning: 1 failed, 1 incomplete 
> In runAllTests (line 71) 

ans = 

  1×51 TestResult array with properties:

    Name
    Passed
    Failed
    Incomplete
    Duration
    Details

Totals:
   49 Passed, 1 Failed (rerun), 1 Incomplete.
   0.80372 seconds testing time.
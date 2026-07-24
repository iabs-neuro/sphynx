# Python engine — M4a acts refine + events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port the act-refinement primitives (`refine_act`, `refine_act_array`) and
build the single-act Events layer (`Event`, `events_from_act`, `EventStream`).

**Architecture:** Approach C — mirror MATLAB `+acts/{refineAct,refineActArray}`; the
Events layer is the new domain-model abstraction (spec §3.3) built on refine_act's
runs. Start of milestone M4 (analysis core). Run/episode frame indices are 0-BASED.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10).
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/` with
  run frame indices converted 1-based -> 0-based (MATLAB frameIn/frameOut 1-based).
- TDD: failing test first.

---

### Task 1: acts.refine_act (+ Run)

**Files:** Create `src/sphynx/acts/__init__.py`, `src/sphynx/acts/refine.py`; Test `tests/unit/test_refine_act.py`.
**Interfaces:** `Run` dataclass (frame_in, frame_out, duration: int; 0-based inclusive);
`refine_act(line, min_run_len1, min_run_len0) -> (refined: np.ndarray, runs: list[Run])`.
Port of `refineAct.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_refine_act.py`:
```python
import numpy as np

from sphynx.acts.refine import refine_act, Run


def test_noop_when_runs_long_enough():
    x = np.array([0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0])
    out, runs = refine_act(x, 2, 2)
    assert np.array_equal(out, x.astype(bool))
    assert len(runs) == 2


def test_drops_short_one_run():
    x = np.array([0, 0, 1, 0, 0, 1, 1, 1, 1, 0])
    out, runs = refine_act(x, 2, 0)
    assert np.array_equal(out, np.array([0, 0, 0, 0, 0, 1, 1, 1, 1, 0], bool))
    assert len(runs) == 1


def test_closes_short_gap():
    out, _ = refine_act(np.array([1, 1, 1, 0, 1, 1, 1]), 1, 2)
    assert np.array_equal(out, np.ones(7, bool))


def test_does_not_close_leading_zeros():
    out, _ = refine_act(np.array([0, 1, 1, 1]), 1, 2)
    assert np.array_equal(out, np.array([0, 1, 1, 1], bool))


def test_run_frame_indices_zero_based():
    _, runs = refine_act(np.array([0, 1, 1, 0, 0, 1, 1, 1]), 1, 0)
    assert (runs[0].frame_in, runs[0].frame_out, runs[0].duration) == (1, 2, 2)
    assert (runs[1].frame_in, runs[1].frame_out, runs[1].duration) == (5, 7, 3)


def test_empty_input():
    out, runs = refine_act(np.array([], dtype=bool), 1, 1)
    assert out.size == 0
    assert runs == []
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/acts/__init__.py`:
```python
"""Behavioural acts: refinement, events, built-in acts, stats."""

from sphynx.acts.refine import Run, refine_act, refine_act_array

__all__ = ["Run", "refine_act", "refine_act_array"]
```
`src/sphynx/acts/refine.py`:
```python
"""Min-length / gap-bridge refinement for binary act traces. Ports of
sphynx.acts.refineAct and refineActArray. Run indices are 0-based inclusive."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class Run:
    frame_in: int   # 0-based inclusive
    frame_out: int  # 0-based inclusive
    duration: int


def _find_runs(line: np.ndarray, value: bool):
    """Return (starts, ends) 0-based inclusive line indices of runs == value."""
    marker = line == value
    aug = np.concatenate([[False], marker, [False]])
    trans = np.diff(aug.astype(np.int8))
    starts = np.flatnonzero(trans == 1)      # 0-based line start index
    ends = np.flatnonzero(trans == -1) - 1   # 0-based line end index
    return starts, ends


def refine_act(line, min_run_len1, min_run_len0):
    """Drop short 1-runs, close short 0-runs flanked by 1s, enumerate survivors.
    Returns (refined bool array, list[Run]). Port of refineAct.m."""
    line = np.asarray(line).astype(bool).ravel()
    n = line.size
    if n == 0:
        return line.copy(), []

    refined = line.copy()
    s1, e1 = _find_runs(refined, True)
    for a, b in zip(s1, e1):
        if (b - a + 1) < min_run_len1:
            refined[a : b + 1] = False

    s0, e0 = _find_runs(refined, False)
    for a, b in zip(s0, e0):
        if (b - a + 1) < min_run_len0 and a > 0 and b < n - 1:
            if refined[a - 1] and refined[b + 1]:
                refined[a : b + 1] = True

    s1, e1 = _find_runs(refined, True)
    runs = [Run(int(a), int(b), int(b - a + 1)) for a, b in zip(s1, e1)]
    return refined, runs
```
- [ ] **Step 4: Run — PASS** (6 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/__init__.py src/sphynx/acts/refine.py tests/unit/test_refine_act.py && git commit -m "feat(python): acts.refine_act + Run"`

---

### Task 2: acts.refine_act_array

**Files:** Modify `src/sphynx/acts/refine.py` (append `refine_act_array` + `_rle`); Test `tests/unit/test_refine_act_array.py`.
**Interfaces:** `refine_act_array(bool_arr, min_run_frames=0, max_bridge_frames=0) ->
np.ndarray`. Pass 1 bridge short holes, Pass 2 drop short runs; leading/trailing
zero-runs never bridged. Port of `refineActArray.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_refine_act_array.py`:
```python
import numpy as np

from sphynx.acts.refine import refine_act_array


def _b(lst):
    return np.array(lst, dtype=bool)


def test_zero_params_unchanged():
    x = _b([1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1])
    assert np.array_equal(refine_act_array(x, 0, 0), x)


def test_drops_runs_shorter_than_min():
    x = _b([1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1])
    assert np.array_equal(refine_act_array(x, 3, 0), _b([0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]))


def test_keeps_run_of_exactly_min_length():
    x = _b([0, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 3, 0), x)


def test_bridges_short_gap():
    x = _b([0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 0, 3),
                          _b([0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0]))


def test_leading_zeros_not_bridged():
    x = _b([0, 0, 0, 0, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 0, 100), x)


def test_run_touching_last_frame_kept():
    x = _b([0, 0, 1, 1, 1])
    assert np.array_equal(refine_act_array(x, 3, 0), x)


def test_empty_returns_empty():
    out = refine_act_array(np.array([], dtype=bool), 5, 5)
    assert out.size == 0 and out.dtype == bool


def test_bridge_before_drop_consolidates():
    x = _b([1, 1, 0, 0, 1, 1, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 4, 4), _b([1, 1, 1, 1, 1, 1, 1, 1, 1, 0]))
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** Append to `src/sphynx/acts/refine.py`:
```python
def _rle(b: np.ndarray):
    if b.size == 0:
        return [], []
    d = np.concatenate([[True], np.diff(b) != 0])
    starts = np.flatnonzero(d)
    ends = np.concatenate([starts[1:] - 1, [b.size - 1]])
    runs = list(zip(starts.tolist(), ends.tolist()))
    lengths = (ends - starts + 1).tolist()
    return runs, lengths


def refine_act_array(bool_arr, min_run_frames: int = 0, max_bridge_frames: int = 0) -> np.ndarray:
    """Bridge short holes (pass 1) then drop short runs (pass 2). Leading/trailing
    zero-runs are never bridged. Port of refineActArray.m."""
    b = np.asarray(bool_arr).astype(bool).ravel().copy()
    n = b.size
    if n == 0:
        return b

    if max_bridge_frames > 0:
        runs, lengths = _rle(b)
        for (s, e), ln in zip(runs, lengths):
            is_hole = not b[s]
            if is_hole and s != 0 and e != n - 1 and ln < max_bridge_frames:
                b[s : e + 1] = True

    if min_run_frames > 0:
        runs, lengths = _rle(b)
        for (s, e), ln in zip(runs, lengths):
            if b[s] and ln < min_run_frames:
                b[s : e + 1] = False

    return b
```
- [ ] **Step 4: Run — PASS** (8 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/refine.py tests/unit/test_refine_act_array.py && git commit -m "feat(python): acts.refine_act_array"`

---

### Task 3: acts.events (Event, events_from_act, EventStream)

**Files:** Create `src/sphynx/acts/events.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_events.py`.
**Interfaces:** `Event` dataclass (act: str, start_frame, end_frame: int (0-based),
duration_s: float, label: str | None, index: int | None);
`events_from_act(act_mask, frame_rate, act_name="", label=None, index=None) ->
list[Event]`; `EventStream` dataclass wrapping `events: list[Event]` with methods
`first()`, `first_where(pred)`, `labels_before(event)`, `order_of(label)`,
`unique_labels()`. New domain-model layer (spec §3.3), built on refine_act.

- [ ] **Step 1: Failing test** — `tests/unit/test_events.py`:
```python
import numpy as np

from sphynx.acts.events import Event, EventStream, events_from_act


def test_events_from_act_two_episodes():
    mask = np.zeros(20, bool)
    mask[2:5] = True   # frames 2..4 (3 frames)
    mask[10:12] = True # frames 10..11 (2 frames)
    evs = events_from_act(mask, 10.0, act_name="freezing")
    assert len(evs) == 2
    assert evs[0].act == "freezing"
    assert (evs[0].start_frame, evs[0].end_frame) == (2, 4)
    assert evs[0].duration_s == 3 / 10.0
    assert (evs[1].start_frame, evs[1].end_frame) == (10, 11)


def test_events_from_empty():
    assert events_from_act(np.zeros(10, bool), 30.0) == []


def test_event_stream_queries():
    evs = [
        Event("nose_at_hole", 5, 9, 0.5, label="hole_2", index=2),
        Event("nose_at_hole", 20, 24, 0.5, label="hole_7", index=7),
        Event("nose_at_hole", 40, 44, 0.5, label="hole_target", index=1),
    ]
    s = EventStream(evs)
    assert s.first().label == "hole_2"
    target = s.first_where(lambda e: e.label == "hole_target")
    assert target.start_frame == 40
    assert s.labels_before(target) == ["hole_2", "hole_7"]
    assert s.order_of("hole_7") == 1
    assert s.unique_labels() == ["hole_2", "hole_7", "hole_target"]


def test_event_stream_first_empty_is_none():
    assert EventStream([]).first() is None
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/events.py`:
```python
"""Events layer: ordered, labelled episodes derived from act traces.
Domain-model abstraction (spec section 3.3). Frame indices are 0-based."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

from sphynx.acts.refine import refine_act


@dataclass
class Event:
    act: str
    start_frame: int
    end_frame: int
    duration_s: float
    label: str | None = None
    index: int | None = None


def events_from_act(
    act_mask, frame_rate: float, act_name: str = "", label: str | None = None,
    index: int | None = None,
) -> list[Event]:
    """Derive episodes from a binary act trace (no refinement applied here)."""
    _, runs = refine_act(act_mask, 0, 0)
    return [
        Event(act_name, r.frame_in, r.frame_out, r.duration / frame_rate, label, index)
        for r in runs
    ]


@dataclass
class EventStream:
    """Time-ordered list of Events (single act, or a merged act family)."""

    events: list[Event] = field(default_factory=list)

    def first(self) -> Event | None:
        return self.events[0] if self.events else None

    def first_where(self, pred: Callable[[Event], bool]) -> Event | None:
        return next((e for e in self.events if pred(e)), None)

    def labels_before(self, event: Event) -> list[str | None]:
        return [e.label for e in self.events if e.start_frame < event.start_frame]

    def order_of(self, label: str) -> int | None:
        for i, e in enumerate(self.events):
            if e.label == label:
                return i
        return None

    def unique_labels(self) -> list[str | None]:
        seen: list[str | None] = []
        for e in self.events:
            if e.label not in seen:
                seen.append(e.label)
        return seen
```
Update `src/sphynx/acts/__init__.py` to also export `Event, EventStream, events_from_act`.
- [ ] **Step 4: Run — PASS** (4 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/acts/events.py src/sphynx/acts/__init__.py tests/unit/test_events.py && git commit -m "feat(python): acts.events (Event, events_from_act, EventStream)"`

---

## Done criteria
- `python -m pytest -q` green (M3 180 + these).
- `sphynx.acts.{refine_act, refine_act_array, Run, Event, EventStream, events_from_act}` available.

## Next plan
- **M4b:** `speed_acts` (rest/walk/locomotion) + `act_stats` (per-act numeric stats).
  Then M4c: freezing, rear, apply_act, make_act_context, eval_acts_library.

"""Port of matlab/tests/unit/runBatchTest.m — batch aggregation to tidy/wide."""

import pytest

from sphynx.acts.stats import ActStats
from sphynx.exceptions import SphynxValueError
from sphynx.pipeline import SessionAct, run_batch


def _stats(percent, count):
    return ActStats(
        count=count, percent=percent, duration_s=float("nan"),
        mean_time=float("nan"), median_time=float("nan"), std_time=float("nan"),
        mad_time=float("nan"), first_start_s=float("nan"), first_end_s=float("nan"),
        last_start_s=float("nan"), last_end_s=float("nan"),
        first_duration_s=float("nan"), rest_duration_s=float("nan"),
        distance_cm=float("nan"), mean_distance_cm=float("nan"),
        mean_velocity=float("nan"), max_velocity=float("nan"),
        min_velocity=float("nan"), velocity=float("nan"),
    )


class _Res:
    def __init__(self, acts):
        self.acts = acts


def _two_sessions():
    r1 = _Res([
        SessionAct("rest", stats=_stats(10, 2)),
        SessionAct("walk", stats=_stats(80, 5)),
    ])
    r2 = _Res([
        SessionAct("rest", stats=_stats(30, 4)),
        SessionAct("walk", stats=_stats(60, 7)),
    ])
    specs = [
        {"session_name": "J01_1D", "mouse": "J01", "trial": "1D"},
        {"session_name": "J01_2D", "mouse": "J01", "trial": "2D"},
    ]
    return specs, [r1, r2]


def test_two_mocked_sessions():
    specs, preloaded = _two_sessions()
    out = run_batch(specs, preloaded=preloaded)

    assert len(out.results) == 2
    assert not out.tidy.empty
    assert len(out.tidy) > 0
    assert len(out.wide) == 1  # 1 mouse

    cell = out.tidy[
        (out.tidy["mouse"] == "J01")
        & (out.tidy["act_name"] == "rest")
        & (out.tidy["metric"] == "ActPercent")
        & (out.tidy["trial"] == "1D")
    ]
    assert len(cell) == 1
    assert cell["value"].iloc[0] == 10


def test_wide_pivot_two_mice():
    r1 = _Res([SessionAct("rest", stats=_stats(10, 1))])
    r2 = _Res([SessionAct("rest", stats=_stats(20, 1))])
    specs = [
        {"session_name": "A_1D", "mouse": "A", "trial": "1D"},
        {"session_name": "B_1D", "mouse": "B", "trial": "1D"},
    ]
    out = run_batch(specs, preloaded=[r1, r2])
    assert len(out.wide) == 2  # 2 mice


def test_preloaded_length_mismatch_raises():
    specs, preloaded = _two_sessions()
    with pytest.raises(SphynxValueError):
        run_batch(specs, preloaded=preloaded[:1])

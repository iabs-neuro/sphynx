import numpy as np
import pytest

from sphynx.acts import Act, EventStream, family_event_stream
from sphynx.exceptions import SphynxValueError

FPS = 10.0


def _member(name, zone, index, is_target=False):
    return Act(name=name, type="simple", family="nose_at_hole",
               zone_name=zone, zone_index=index, is_target=is_target)


def _acts():
    return [
        _member("nose_at_hole1", "hole_a", 1),
        _member("nose_at_hole2", "hole_b", 2, is_target=True),
        _member("nose_at_hole3", "hole_c", 3),
    ]


def _results():
    a = np.zeros(20, dtype=bool)
    a[10:12] = True                     # third visit
    b = np.zeros(20, dtype=bool)
    b[5:7] = True                       # second visit (the target)
    c = np.zeros(20, dtype=bool)
    c[1:3] = True                       # first visit
    return {"nose_at_hole1": a, "nose_at_hole2": b, "nose_at_hole3": c}


def test_merged_stream_is_time_ordered():
    st = family_event_stream(_acts(), _results(), FPS)
    assert isinstance(st, EventStream)
    assert [e.start_frame for e in st.events] == [1, 5, 10]


def test_events_carry_zone_provenance():
    st = family_event_stream(_acts(), _results(), FPS)
    assert [e.label for e in st.events] == ["hole_c", "hole_b", "hole_a"]
    assert [e.index for e in st.events] == [3, 2, 1]
    assert [e.is_target for e in st.events] == [False, True, False]


def test_visit_order_is_a_generic_query():
    # This is what replaces the hardcoded order_barnes.
    st = family_event_stream(_acts(), _results(), FPS)
    assert st.unique_labels() == ["hole_c", "hole_b", "hole_a"]
    assert st.order_of("hole_b") == 1


def test_labels_before_the_target_is_a_generic_query():
    # And this is what replaces bespoke primary-error counting.
    st = family_event_stream(_acts(), _results(), FPS)
    target = st.first_where(lambda e: e.is_target)
    assert target is not None
    assert st.labels_before(target) == ["hole_c"]


def test_family_filter_selects_members():
    acts = _acts() + [Act(name="other", type="simple", family="rear_at_wall",
                          zone_name="wall_a", zone_index=1)]
    results = dict(_results())
    results["other"] = np.ones(20, dtype=bool)
    st = family_event_stream(acts, results, FPS, family="nose_at_hole")
    assert all(e.act.startswith("nose_at_hole") for e in st.events)


def test_missing_member_result_raises():
    results = _results()
    del results["nose_at_hole2"]
    with pytest.raises(SphynxValueError):
        family_event_stream(_acts(), results, FPS)


def test_durations_use_the_frame_rate():
    st = family_event_stream(_acts(), _results(), FPS)
    assert st.events[0].duration_s == pytest.approx(0.2)   # 2 frames at 10 fps


def test_empty_family_yields_empty_stream():
    st = family_event_stream([], {}, FPS)
    assert st.events == []


def test_no_events_when_no_member_fires():
    results = {k: np.zeros(20, dtype=bool) for k in _results()}
    st = family_event_stream(_acts(), results, FPS)
    assert st.events == []

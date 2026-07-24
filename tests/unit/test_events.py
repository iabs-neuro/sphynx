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

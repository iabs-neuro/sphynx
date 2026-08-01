import matplotlib
matplotlib.use("Agg")

import numpy as np
import pytest
from matplotlib.figure import Figure

from sphynx.exceptions import SphynxValueError
from sphynx.plot.etogram import draw_etogram


class _Act:
    def __init__(self, name, array):
        self.name = name
        self.array = np.asarray(array, dtype=float)


def _axes():
    return Figure().add_subplot(111)


def _acts():
    a = np.zeros(100)
    a[10:20] = 1
    a[40:45] = 1
    b = np.zeros(100)
    b[60:80] = 1
    return [_Act("rest", a), _Act("walk", b)]


def test_returns_act_names_in_row_order():
    assert draw_etogram(_axes(), _acts(), 10.0) == ["rest", "walk"]


def test_draws_one_collection_per_act():
    axes = _axes()
    draw_etogram(axes, _acts(), 10.0)
    assert len(axes.collections) == 2


def test_x_axis_is_seconds():
    axes = _axes()
    draw_etogram(axes, _acts(), 10.0)
    assert axes.get_xlim()[1] == pytest.approx(10.0)      # 100 frames at 10 fps
    assert "time" in axes.get_xlabel().lower()


def test_act_without_episodes_still_gets_a_row():
    acts = _acts() + [_Act("never", np.zeros(100))]
    axes = _axes()
    assert draw_etogram(axes, acts, 10.0) == ["rest", "walk", "never"]
    assert [t.get_text() for t in axes.get_yticklabels()] == ["rest", "walk", "never"]


def test_empty_act_list_is_labelled_not_blank():
    axes = _axes()
    assert draw_etogram(axes, [], 10.0) == []
    assert axes.texts                     # says there is nothing to show


def test_max_acts_truncates_and_says_so():
    acts = _acts() * 6                    # 12 acts
    axes = _axes()
    rows = draw_etogram(axes, acts, 10.0, max_acts=5)
    assert len(rows) == 5
    assert any("12" in t.get_text() for t in axes.texts)   # states what was dropped


def test_bad_frame_rate_raises():
    with pytest.raises(SphynxValueError):
        draw_etogram(_axes(), _acts(), 0)

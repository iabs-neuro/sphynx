import numpy as np
import pytest

from sphynx.angles import wrap, unwrap_for_smooth, head_direction
from sphynx.exceptions import SphynxValueError
from tests.fixtures.synthetic import make_rotating_mouse_dlc


def test_zero_stays_zero():
    assert float(wrap(0.0)) == 0.0


def test_wraps_positive():
    assert float(wrap(3 * np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(2 * np.pi)) == pytest.approx(0.0, abs=1e-12)


def test_wraps_negative():
    assert float(wrap(-3 * np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(-2 * np.pi)) == pytest.approx(0.0, abs=1e-12)


def test_in_range_unchanged():
    a = np.array([-np.pi + 0.01, -np.pi / 2, 0, np.pi / 2, np.pi - 0.01])
    assert np.allclose(wrap(a), a, atol=1e-12)


def test_vectorized():
    out = wrap(np.array([3 * np.pi, -3 * np.pi, 0, np.pi / 4]))
    assert np.allclose(out, [np.pi, np.pi, 0, np.pi / 4], atol=1e-12)


def test_pi_stays_pi():
    assert float(wrap(np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(1000 * np.pi)) == pytest.approx(0.0, abs=1e-9)


def test_unwrap_for_smooth_short_input_returns_wrapped():
    a = np.array([0.1, 0.2, 0.3])
    out = unwrap_for_smooth(a, 11)
    assert out.size == 3
    assert np.all(out >= -np.pi) and np.all(out <= np.pi)


def test_unwrap_for_smooth_even_window_raises():
    with pytest.raises(SphynxValueError):
        unwrap_for_smooth(np.zeros(50), 4)


def test_unwrap_for_smooth_too_small_window_raises():
    with pytest.raises(SphynxValueError):
        unwrap_for_smooth(np.zeros(50), 1)


def test_head_direction_even_smooth_window_raises():
    f = make_rotating_mouse_dlc(50, 4)
    with pytest.raises(SphynxValueError):
        head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 4)


def test_head_direction_no_large_jumps():
    f = make_rotating_mouse_dlc(720, 4)
    hd = head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 11)
    from sphynx.angles import wrap
    diffs = wrap(np.diff(hd))
    assert np.max(np.abs(diffs)) < 0.5


def test_head_direction_in_range():
    f = make_rotating_mouse_dlc(720, 4)
    hd = head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 11)
    assert np.all(hd >= -np.pi) and np.all(hd <= np.pi)


def test_head_direction_total_rotation():
    f = make_rotating_mouse_dlc(720, 4)
    hd = head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 11)
    unwrapped = np.unwrap(hd)
    actual = unwrapped[-1] - unwrapped[0]
    assert actual == pytest.approx(f["expected_total_rotation_rad"], abs=0.2)

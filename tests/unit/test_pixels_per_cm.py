import numpy as np
import pytest

from sphynx.preset import pixels_per_cm


def test_isotropic_averages():
    pts = np.array([[0, 0], [0, 100], [0, 0], [100, 0]], dtype=float)
    ppc, x_kcorr, pxl_y, pxl_x, diff = pixels_per_cm(pts, [10.0, 10.0])
    assert ppc == pytest.approx(10.0)
    assert x_kcorr == 1.0
    assert diff == pytest.approx(0.0)


def test_anisotropic_uses_y_and_kcorr():
    # vertical pair: 100 px / 10 cm = 10; horizontal pair: 90 px / 10 cm = 9
    pts = np.array([[0, 0], [0, 100], [0, 0], [90, 0]], dtype=float)
    ppc, x_kcorr, pxl_y, pxl_x, diff = pixels_per_cm(pts, [10.0, 10.0])
    assert ppc == pytest.approx(10.0)
    assert x_kcorr == pytest.approx(10.0 / 9.0)
    assert diff > 3

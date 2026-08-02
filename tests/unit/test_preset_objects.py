import numpy as np
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.preset.objects import build_object_zones, inflate_mask

H = W = 120


def _square(cx, cy, half=6):
    mask = np.zeros((H, W), dtype=bool)
    mask[cy - half:cy + half, cx - half:cx + half] = True
    return mask


def _zones(**kw):
    kw.setdefault("pixels_per_cm", 10.0)
    kw.setdefault("zone_width_cm", 2.5)
    return build_object_zones([("object1", _square(30, 30)),
                               ("object2", _square(90, 30))], H, W, **kw)


def _by_name(zones):
    return {z.name: z for z in zones}


# --- the inflation itself --------------------------------------------------

def test_inflation_grows_the_mask():
    mask = _square(60, 60)
    inflated, _ring = inflate_mask(mask, 5)
    assert inflated.sum() > mask.sum()
    assert (inflated & mask).sum() == mask.sum()      # contains the original


def test_the_ring_excludes_the_object():
    mask = _square(60, 60)
    inflated, ring = inflate_mask(mask, 5)
    assert not (ring & mask).any()
    assert (ring | mask).sum() == inflated.sum()      # ring + object = inflated


def test_a_wider_band_gives_a_bigger_ring():
    mask = _square(60, 60)
    _i1, narrow = inflate_mask(mask, 3)
    _i2, wide = inflate_mask(mask, 8)
    assert wide.sum() > narrow.sum()


def test_zero_width_leaves_an_empty_ring():
    mask = _square(60, 60)
    inflated, ring = inflate_mask(mask, 0)
    assert not ring.any()
    assert inflated.sum() == mask.sum()


def test_anisotropy_changes_the_shape():
    # With x_kcorr != 1 the band is inflated in isotropic space, so the ring is
    # not the same as the isotropic one.
    mask = _square(60, 60)
    _i, plain = inflate_mask(mask, 6, x_kcorr=1.0)
    _i2, stretched = inflate_mask(mask, 6, x_kcorr=1.6)
    assert plain.shape == stretched.shape
    assert not np.array_equal(plain, stretched)


def test_the_ring_is_the_requested_width_in_cm_on_both_axes():
    # The point of the normalization: the band must be the SAME number of
    # centimetres on both axes, which on an anisotropic pixel is a different
    # number of pixels on each. pxl_y = 20 px/cm and x_kcorr = pxl_y/pxl_x = 2,
    # so pxl_x = 10 px/cm and a 2.5 cm band is 50 px along y, 25 px along x.
    # `width_pixels` is in y-pixels, so it is 2.5 * pxl_y.
    size, half = 200, 10
    pixels_per_cm_y, x_kcorr, width_cm = 20.0, 2.0, 2.5
    pixels_per_cm_x = pixels_per_cm_y / x_kcorr
    mask = np.zeros((size, size), dtype=bool)
    mask[100 - half:100 + half, 100 - half:100 + half] = True

    inflated, _ring = inflate_mask(mask, width_cm * pixels_per_cm_y,
                                   x_kcorr=x_kcorr)
    rows, cols = np.nonzero(inflated)
    # how far the band grew on each side, in pixels
    grown_y = (rows.max() - rows.min() + 1 - 2 * half) / 2.0
    grown_x = (cols.max() - cols.min() + 1 - 2 * half) / 2.0

    # half a pixel of slack for the nearest-neighbour resample back to pixels
    assert grown_y / pixels_per_cm_y == pytest.approx(width_cm, abs=0.025)
    assert grown_x / pixels_per_cm_x == pytest.approx(width_cm, abs=0.05)
    # and the two axes really do disagree in PIXELS, which is the whole point
    assert grown_x == pytest.approx(grown_y / x_kcorr, abs=0.5)


def test_an_empty_mask_inflates_to_nothing():
    # MATLAB bwdist on an all-false mask returns Inf everywhere, so nothing is
    # within the band. distance_transform_edt returns finite distances measured
    # from just outside the (0,0) corner instead, which used to hand back a
    # whole corner block (or the whole frame) as the ring.
    mask = np.zeros((H, W), dtype=bool)
    inflated, ring = inflate_mask(mask, 25)
    assert not inflated.any()
    assert not ring.any()


def test_an_empty_mask_inflates_to_nothing_when_anisotropic():
    mask = np.zeros((H, W), dtype=bool)
    inflated, ring = inflate_mask(mask, 25, x_kcorr=1.6)
    assert inflated.shape == mask.shape
    assert not inflated.any()
    assert not ring.any()


# --- the zone set ----------------------------------------------------------

def test_three_zones_per_object():
    zones = _by_name(_zones())
    for name in ("object1_real", "object1_realout", "object1_out",
                 "object2_real", "object2_realout", "object2_out"):
        assert name in zones


def test_realout_is_the_union_of_real_and_out():
    zones = _by_name(_zones())
    real = zones["object1_real"].maskfilled
    ring = zones["object1_out"].maskfilled
    realout = zones["object1_realout"].maskfilled
    assert np.array_equal(realout, real | ring)
    assert not (real & ring).any()


def test_combined_zones_appear_for_two_objects():
    zones = _by_name(_zones())
    for name in ("objectall_real", "objectall_realout", "objectall_out"):
        assert name in zones
    combined = zones["objectall_real"].maskfilled
    assert combined.sum() == (zones["object1_real"].maskfilled.sum()
                              + zones["object2_real"].maskfilled.sum())


def test_a_single_object_gets_no_combined_zones():
    zones = _by_name(build_object_zones([("object1", _square(30, 30))], H, W,
                                        pixels_per_cm=10.0))
    assert "objectall_real" not in zones


def test_zones_carry_their_class_and_index():
    zones = _by_name(_zones())
    assert zones["object1_real"].zone_class == "object"
    assert zones["object1_out"].zone_class == "object_ring"
    assert zones["object1_realout"].zone_class == "object_area"
    assert zones["object2_real"].index == 2


def test_holes_are_supported_for_barnes():
    zones = _by_name(build_object_zones([("hole1", _square(30, 30))], H, W,
                                        pixels_per_cm=10.0, kind="hole"))
    assert zones["hole1_real"].zone_class == "hole"
    assert zones["hole1_out"].zone_class == "hole_ring"


def test_the_target_flag_reaches_all_three_zones():
    zones = _by_name(build_object_zones(
        [("target", _square(30, 30))], H, W, pixels_per_cm=10.0, kind="hole",
        targets={"target"}))
    for suffix in ("_real", "_out", "_realout"):
        assert zones["target" + suffix].roles.is_target is True


def test_no_calibration_with_a_ring_width_raises():
    with pytest.raises(SphynxValueError):
        build_object_zones([("object1", _square(30, 30))], H, W,
                           pixels_per_cm=None, zone_width_cm=2.5)


def test_zero_width_needs_no_calibration():
    zones = _by_name(build_object_zones([("object1", _square(30, 30))], H, W,
                                        pixels_per_cm=None, zone_width_cm=0))
    assert "object1_real" in zones
    assert "object1_out" not in zones


def test_an_empty_object_list_gives_no_zones():
    assert build_object_zones([], H, W, pixels_per_cm=10.0) == []


# --- an object drawn off the frame is user error, not a zone ---------------

def test_an_empty_object_mask_raises_and_names_the_object():
    # A shape dragged off the frame clips to an empty mask. Emitting zones for
    # it would publish time spent in a phantom object.
    empty = np.zeros((H, W), dtype=bool)
    with pytest.raises(SphynxValueError) as excinfo:
        build_object_zones([("object1", _square(30, 30)), ("offscreen", empty)],
                           H, W, pixels_per_cm=10.0)
    assert "offscreen" in str(excinfo.value)


def test_an_empty_object_mask_raises_even_with_no_ring():
    empty = np.zeros((H, W), dtype=bool)
    with pytest.raises(SphynxValueError) as excinfo:
        build_object_zones([("offscreen", empty)], H, W, pixels_per_cm=None,
                           zone_width_cm=0)
    assert "offscreen" in str(excinfo.value)

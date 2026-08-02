"""Automatic object detection (S4h). Port of autoDetectObjects.m.

These are PROPOSALS the experimenter sees on the canvas and edits, so the
tests pin behaviour that must hold (what is found, what is refused, what the
filters exclude) rather than exact pixel counts, which depend on a local
threshold that is deliberately not bit-identical to MATLAB's adaptthresh.
"""

import numpy as np
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.preset.detect import ALGORITHMS, MODES, detect_objects, local_threshold

PPC = 4.0                       # 4 px per cm throughout


def _scene(size=200, objects=((70, 70, 14), (130, 70, 14))):
    """A bright arena disc with dark round objects on it."""
    frame = np.full((size, size), 200, dtype=np.uint8)
    ys, xs = np.mgrid[0:size, 0:size]
    centre = (size - 1) / 2.0
    arena = ((xs - centre) ** 2 + (ys - centre) ** 2) <= (size * 0.45) ** 2
    frame[~arena] = 40
    for cx, cy, radius in objects:
        frame[((xs - cx) ** 2 + (ys - cy) ** 2) <= radius**2] = 60
    return frame, arena


def _detect(**kwargs):
    frame, arena = kwargs.pop("scene", _scene())
    params = dict(pixels_per_cm=PPC, min_area_cm2=5.0, max_area_cm2=200.0,
                  sensitivity=0.75)
    params.update(kwargs)
    return detect_objects(frame, arena, **params)


# --- finding things --------------------------------------------------------
def test_two_dark_objects_on_a_bright_floor_are_found():
    found = _detect()
    assert len(found) == 2, [d.area_px for d in found]


def test_each_detection_carries_an_outline_and_a_filled_mask():
    for detection in _detect():
        assert len(detection.x) == len(detection.y) >= 3
        assert detection.mask.shape == (200, 200)
        assert detection.mask.any()
        assert detection.area_px == int(detection.mask.sum())


def test_a_detection_sits_where_the_object_was_drawn():
    centres = sorted((float(np.nonzero(d.mask)[1].mean()),
                      float(np.nonzero(d.mask)[0].mean())) for d in _detect())
    assert centres[0][0] == pytest.approx(70, abs=4)
    assert centres[1][0] == pytest.approx(130, abs=4)


def test_an_empty_arena_finds_nothing_without_raising():
    frame, _ = _scene()
    assert detect_objects(frame, np.zeros_like(frame, dtype=bool),
                          pixels_per_cm=PPC) == []


def test_a_floor_with_nothing_on_it_finds_nothing():
    frame, arena = _scene(objects=())
    assert _detect(scene=(frame, arena)) == []


# --- the filters -----------------------------------------------------------
def test_an_object_below_the_minimum_area_is_dropped():
    # A radius-14 disc is ~615 px = ~38 cm^2 at 4 px/cm.
    assert _detect(min_area_cm2=60.0) == []


def test_an_object_above_the_maximum_area_is_dropped():
    assert _detect(max_area_cm2=10.0) == []


def test_nothing_may_cover_more_than_half_the_arena():
    # One huge blob: even with a generous max_area_cm2 the arena-fraction cap
    # rejects it, because a blob that size is the floor, not an object.
    frame, arena = _scene(objects=((100, 100, 85),))
    assert _detect(scene=(frame, arena), max_area_cm2=100_000.0) == []


def test_something_outside_the_arena_is_ignored():
    frame, arena = _scene(objects=((70, 70, 14),))
    frame[8:28, 8:28] = 60          # a dark patch beyond the arena disc
    found = _detect(scene=(frame, arena))
    assert len(found) == 1
    assert float(np.nonzero(found[0].mask)[1].mean()) == pytest.approx(70, abs=5)


def test_a_detection_never_touches_the_arena_boundary_ring():
    # The arena is eroded by ~1 cm first, so a darkened rim is not returned.
    size = 200
    frame, arena = _scene(size=size, objects=((70, 70, 14),))
    ys, xs = np.mgrid[0:size, 0:size]
    centre = (size - 1) / 2.0
    distance = np.sqrt((xs - centre) ** 2 + (ys - centre) ** 2)
    frame[(distance > size * 0.40) & (distance <= size * 0.45)] = 60
    assert len(_detect(scene=(frame, arena))) == 1


# --- the shape modes -------------------------------------------------------
@pytest.mark.parametrize("mode", MODES)
def test_every_mode_returns_something_shaped(mode):
    if mode == "all-circles":
        pytest.skip("covered by its own test; hough has a separate path")
    found = _detect(mode=mode)
    assert found, mode
    assert {d.geometry for d in found} <= {"Polygon", "Ellipse", "Circle"}


def test_circle_mode_names_its_detections_circles():
    found = _detect(mode="all-circles")
    assert found and all(d.geometry == "Circle" for d in found)


def test_ellipse_mode_fits_the_elongation_it_was_given():
    # A 2:1 bar must come back as an ellipse about twice as long as it is wide.
    size = 200
    frame, arena = _scene(size=size, objects=())
    frame[92:108, 60:124] = 60          # 16 px tall, 64 px wide
    found = _detect(scene=(frame, arena), mode="all-ellipses", min_area_cm2=20.0)
    assert len(found) == 1
    xs, ys = found[0].x, found[0].y
    assert (xs.max() - xs.min()) / (ys.max() - ys.min()) == pytest.approx(4, rel=0.4)


def test_polygon_mode_simplifies_the_outline():
    free = _detect(mode="free-form")
    simplified = _detect(mode="all-polygons")
    assert len(simplified[0].x) < len(free[0].x)


# --- refusals --------------------------------------------------------------
def test_an_unknown_mode_names_the_known_ones():
    with pytest.raises(SphynxValueError, match="free-form"):
        _detect(mode="guess")


def test_an_unknown_algorithm_names_the_known_ones():
    with pytest.raises(SphynxValueError, match="threshold"):
        _detect(algorithm="magic")


def test_detection_without_a_calibration_is_refused():
    # The area filters are in square centimetres; without px/cm they mean
    # nothing, and silently treating them as pixels would filter wrongly.
    frame, arena = _scene()
    with pytest.raises(SphynxValueError, match="pixels_per_cm"):
        detect_objects(frame, arena, pixels_per_cm=0)


def test_a_backwards_area_range_is_refused():
    with pytest.raises(SphynxValueError, match="area range"):
        _detect(min_area_cm2=50.0, max_area_cm2=10.0)


def test_a_frame_of_another_size_than_the_arena_is_refused():
    frame, arena = _scene()
    with pytest.raises(SphynxValueError, match="arena mask"):
        detect_objects(frame[:100], arena, pixels_per_cm=PPC)


def test_a_sensitivity_outside_zero_to_one_is_refused():
    with pytest.raises(SphynxValueError, match="sensitivity"):
        local_threshold(np.zeros((10, 10), dtype=np.uint8), sensitivity=1.5)


# --- the threshold itself --------------------------------------------------
def test_a_higher_sensitivity_admits_more():
    frame, arena = _scene()
    low = local_threshold(frame, 0.3)
    high = local_threshold(frame, 0.9)
    assert (high >= low).all()
    assert (high > low).any()


def test_the_neighbourhood_size_changes_the_threshold_map():
    frame, _ = _scene()
    assert not np.allclose(local_threshold(frame, 0.75, neighborhood_px=0),
                           local_threshold(frame, 0.75, neighborhood_px=9))


def test_a_colour_frame_is_accepted():
    frame, arena = _scene()
    colour = np.repeat(frame[:, :, None], 3, axis=2)
    assert len(_detect(scene=(colour, arena))) == 2


def test_the_algorithms_are_the_two_matlab_offers():
    assert ALGORITHMS == ("threshold", "hough")
    assert MODES == ("free-form", "all-circles", "all-polygons", "all-ellipses")


# --- the hough algorithm ---------------------------------------------------

def test_hough_finds_the_round_objects():
    found = _detect(mode="all-circles", algorithm="hough",
                    radius_range_cm=(2.0, 6.0))
    assert found, "hough found nothing where two discs were drawn"
    assert all(d.geometry == "Circle" for d in found)
    centres = sorted(float(np.nonzero(d.mask)[1].mean()) for d in found)
    assert any(abs(c - 70) < 8 for c in centres)


def test_hough_respects_the_area_filters():
    assert _detect(mode="all-circles", algorithm="hough",
                   radius_range_cm=(2.0, 6.0),
                   min_area_cm2=0.1, max_area_cm2=1.0) == []


def test_hough_refuses_a_radius_range_that_does_not_increase():
    with pytest.raises(SphynxValueError, match="radius range"):
        _detect(mode="all-circles", algorithm="hough",
                radius_range_cm=(6.0, 2.0))


def test_hough_only_applies_to_the_circle_mode():
    # MATLAB routes hough only for 'all-circles'; any other mode falls back to
    # the threshold path rather than silently ignoring the choice.
    found = _detect(mode="free-form", algorithm="hough")
    assert found and all(d.geometry == "Polygon" for d in found)

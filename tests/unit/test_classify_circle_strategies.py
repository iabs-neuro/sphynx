"""The two ring strategies the port was missing (S4g).

Ports of matlab/+sphynx/+preset/buildZonesCircleWall.m and
buildZonesCircleCenter.m -- the app's 'circle' (its DEFAULT) and
'circle-with-center' strategies. Until now Python had only 'circle-rings'
(classifyCircle), so a round arena silently got a different set of zones from
the one MATLAB builds.
"""

import numpy as np
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.zones import classify_circle_center, classify_circle_wall


def _disc(size=101, radius=45):
    ys, xs = np.mgrid[0:size, 0:size]
    centre = (size - 1) / 2.0
    return ((xs - centre) ** 2 + (ys - centre) ** 2) <= radius**2


def _named(zones):
    return {z.name: np.asarray(z.maskfilled) for z in zones}


# --- 'circle': wall ring + centre ------------------------------------------
def test_the_wall_strategy_makes_exactly_two_zones():
    zones = classify_circle_wall(_disc(), pixels_per_cm=2.0, wall_width_cm=5.0)
    assert [z.name for z in zones] == ["wall", "center"]


def test_the_two_zones_partition_the_arena_without_overlap():
    arena = _disc()
    named = _named(classify_circle_wall(arena, pixels_per_cm=2.0,
                                        wall_width_cm=5.0))
    assert not (named["wall"] & named["center"]).any()
    assert ((named["wall"] | named["center"]) == arena).all()


def test_the_wall_band_is_as_wide_as_it_was_asked_to_be():
    # 3 cm at 4 px/cm is 12 px: the centre disc shrinks by that much.
    arena = _disc(size=141, radius=60)
    named = _named(classify_circle_wall(arena, pixels_per_cm=4.0,
                                        wall_width_cm=3.0))
    centre_radius = np.sqrt(named["center"].sum() / np.pi)
    assert centre_radius == pytest.approx(60 - 12, abs=1.5)


def test_a_zero_wall_makes_the_whole_arena_the_centre():
    arena = _disc()
    zones = classify_circle_wall(arena, pixels_per_cm=2.0, wall_width_cm=0.0)
    assert [z.name for z in zones] == ["center"]
    assert (np.asarray(zones[0].maskfilled) == arena).all()


def test_the_wall_strategy_works_on_a_square_arena_too():
    # buildZonesCircleWall.m measures with bwdist, so it is shape-agnostic --
    # this is what finally gives a polygon arena derived zones.
    arena = np.zeros((80, 80), dtype=bool)
    arena[10:70, 10:70] = True
    named = _named(classify_circle_wall(arena, pixels_per_cm=2.0,
                                        wall_width_cm=2.0))
    assert named["wall"].any() and named["center"].any()
    assert not (named["wall"] & named["center"]).any()


def test_an_arena_touching_the_frame_edge_still_gets_a_wall_there():
    # DELIBERATE DIVERGENCE from buildZonesCircleWall.m, which does not pad:
    # unpadded, the edge pixels have no outside pixel to measure to, so the
    # side lying on the frame border silently gets no wall band. classifyCircle
    # pads in both languages; this one now does too.
    arena = np.zeros((60, 60), dtype=bool)
    arena[0:40, 0:40] = True          # flush against the top-left border
    named = _named(classify_circle_wall(arena, pixels_per_cm=2.0,
                                        wall_width_cm=2.0))
    assert named["wall"][0, :40].all(), "the top row lies on the arena edge"
    assert named["wall"][:40, 0].all(), "the left column lies on the arena edge"


def test_the_wall_strategy_needs_a_calibration():
    with pytest.raises(SphynxValueError, match="pixels_per_cm"):
        classify_circle_wall(_disc(), pixels_per_cm=0, wall_width_cm=5.0)


def test_a_negative_wall_is_refused():
    with pytest.raises(SphynxValueError, match="wall_width_cm"):
        classify_circle_wall(_disc(), pixels_per_cm=2.0, wall_width_cm=-1.0)


def test_an_empty_arena_yields_no_zones():
    assert classify_circle_wall(np.zeros((20, 20), dtype=bool),
                                pixels_per_cm=2.0, wall_width_cm=2.0) == []


# --- 'circle-with-center': concentric disc of a stated diameter -------------
def test_a_centre_disc_of_the_stated_diameter_is_built():
    # 20 cm across at 2 px/cm is a disc of radius 20 px.
    arena = _disc(size=141, radius=60)
    named = _named(classify_circle_center(arena, pixels_per_cm=2.0,
                                          center_diameter_cm=20.0))
    radius = np.sqrt(named["center"].sum() / np.pi)
    assert radius == pytest.approx(20, abs=1.0)


def test_without_a_wall_the_rest_of_the_arena_is_called_wall():
    # buildZonesCircleCenter.m's back-compatible two-zone shape: the outer
    # region carries the name 'wall' even though it is the whole remainder.
    arena = _disc()
    zones = classify_circle_center(arena, pixels_per_cm=2.0,
                                   center_diameter_cm=20.0)
    assert [z.name for z in zones] == ["wall", "center"]
    named = _named(zones)
    assert ((named["wall"] | named["center"]) == arena).all()
    assert not (named["wall"] & named["center"]).any()


def test_with_a_wall_the_arena_splits_three_ways():
    arena = _disc(size=141, radius=60)
    zones = classify_circle_center(arena, pixels_per_cm=2.0,
                                   center_diameter_cm=20.0, wall_width_cm=5.0)
    assert [z.name for z in zones] == ["wall", "middle", "center"]
    named = _named(zones)
    union = named["wall"] | named["middle"] | named["center"]
    assert (union == arena).all()
    assert named["wall"].sum() + named["middle"].sum() + named["center"].sum() \
        == arena.sum(), "the three zones must not overlap"


def test_the_centre_disc_sits_on_the_arena_centroid():
    arena = np.zeros((120, 120), dtype=bool)
    arena[20:100, 30:110] = True                  # centroid at (69.5, 59.5)
    named = _named(classify_circle_center(arena, pixels_per_cm=2.0,
                                          center_diameter_cm=10.0))
    ys, xs = np.nonzero(named["center"])
    assert xs.mean() == pytest.approx(69.5, abs=1.0)
    assert ys.mean() == pytest.approx(59.5, abs=1.0)


def test_a_centre_disc_larger_than_the_arena_leaves_no_outer_zone():
    arena = _disc(size=61, radius=20)
    zones = classify_circle_center(arena, pixels_per_cm=2.0,
                                   center_diameter_cm=100.0)
    assert [z.name for z in zones] == ["center"]
    assert (np.asarray(zones[0].maskfilled) == arena).all()


def test_a_non_positive_centre_diameter_is_refused():
    with pytest.raises(SphynxValueError, match="center_diameter_cm"):
        classify_circle_center(_disc(), pixels_per_cm=2.0,
                               center_diameter_cm=0.0)


def test_the_centre_strategy_needs_a_calibration():
    with pytest.raises(SphynxValueError, match="pixels_per_cm"):
        classify_circle_center(_disc(), pixels_per_cm=None,
                               center_diameter_cm=20.0)


def test_an_empty_arena_yields_no_zones_here_either():
    assert classify_circle_center(np.zeros((20, 20), dtype=bool),
                                  pixels_per_cm=2.0,
                                  center_diameter_cm=5.0) == []

import numpy as np
import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import ActLibrary
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline.paradigm_bridge import apply_paradigm
from sphynx.bodyparts.identify import Point
from sphynx.config import Config
from sphynx.pipeline.analyze import SessionAct, SessionResult
from sphynx.zones import Zone, ZoneRoles, ZoneSelector

N = 60
FPS = 10.0


class _Options:
    FrameRate = FPS
    pxl2sm = 10.0
    Width = 100
    Height = 100


class _Trace:
    def __init__(self, name, x, y, v):
        self.name = name
        self.x_smooth = x
        self.y_smooth = y
        self.velocity = v


def _hole(name, cx, cy, is_target=False):
    mask = np.zeros((100, 100), dtype=bool)
    mask[cy - 3:cy + 3, cx - 3:cx + 3] = True
    return Zone(name, "area", mask, zone_class="hole",
                roles=ZoneRoles(is_target=is_target), angle=0.0)


def _zones():
    zs = [_hole("hole_a", 20, 20, is_target=True), _hole("hole_b", 80, 20)]
    for i, z in enumerate(zs, start=1):
        z.index = i
    return zs


def _result(zones):
    x = np.full(N, 90.0)
    y = np.full(N, 90.0)
    x[10:20] = 20.0
    y[10:20] = 20.0
    traces = [_Trace("nose", x, y, np.zeros(N)),
              _Trace("bodycenter", x, y, np.zeros(N))]
    return SessionResult(
        body_parts_names=["nose", "bodycenter"], body_parts_traces=traces,
        point=Point(nose=0, center=1),
        acts=[SessionAct("rest", np.ones(N), "builtin")],
        options=_Options(), zones=zones, arena_and_objects=None,
        n_frames=N, config=Config.default(),
    )


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


def _library_family(name="nose_at_hole", zone_class="hole"):
    return ActLibrary(families=[ActFamily(
        name=name, selector=ZoneSelector(zone_class=zone_class),
        template=Act(name=name, type="simple", body_part="nose",
                     required_parts=["nose"], min_duration_sec=0.0,
                     max_gap_sec=0.0))])


def test_library_acts_are_added():
    result = _result(_zones())
    library = ActLibrary(acts=[Act(name="my_act", type="simple",
                                   body_part="bodycenter", zones=["hole_a"],
                                   min_duration_sec=0.0, max_gap_sec=0.0)])
    apply_paradigm(result, "OF", library=library)
    assert "my_act" in [a.name for a in result.acts]


def test_library_family_expands():
    result = _result(_zones())
    apply_paradigm(result, "OF", library=_library_family("sniff", "hole"))
    names = [a.name for a in result.acts]
    assert "sniff1" in names and "sniff2" in names


def test_same_name_library_act_overrides_the_paradigm_act():
    result = _result(_zones())
    apply_paradigm(result, "Barnes", library=_library_family("nose_at_hole"))
    # exactly one act per member name survives
    names = [a.name for a in result.acts]
    assert names.count("nose_at_hole1") == 1


def test_the_override_is_reported_not_silent():
    result = _result(_zones())
    apply_paradigm(result, "Barnes", library=_library_family("nose_at_hole"))
    issues = [i for i in result.validation.issues if i.code == "act_overridden"]
    assert issues
    assert issues[0].level == "info"
    assert "nose_at_hole1" in " ".join(i.message for i in issues)


def test_no_library_leaves_the_paradigm_untouched():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    assert not [i for i in result.validation.issues if i.code == "act_overridden"]


def test_unbuildable_library_family_is_reported():
    result = _result(_zones())
    apply_paradigm(result, "OF", library=_library_family("ghost", "no_such_class"))
    assert "family_failed" in [i.code for i in result.validation.issues]


def test_library_act_appears_in_the_event_streams_of_its_family():
    result = _result(_zones())
    apply_paradigm(result, "OF", library=_library_family("sniff", "hole"))
    assert "sniff" in result.event_streams

from sphynx.bodyparts import resolve_part


def test_exact_match_wins():
    assert resolve_part(["nose", "tailbase", "bodycenter"], "bodycenter") == 2


def test_exact_case_insensitive():
    assert resolve_part(["Nose", "TailBase", "BodyCenter"], "bodycenter") == 2


def test_superanimal_to_legacy_bodycenter():
    assert resolve_part(["nose", "tail_base", "mouse_center", "left_midside"], "bodycenter") == 2


def test_superanimal_to_legacy_tailbase():
    assert resolve_part(["nose", "mouse_center", "tail_base"], "tailbase") == 2


def test_superanimal_to_legacy_hindlimbs():
    parts = ["nose", "mouse_center", "left_hip", "right_hip"]
    assert resolve_part(parts, "lefthindlimb") == 2
    assert resolve_part(parts, "righthindlimb") == 3


def test_superanimal_to_legacy_headcenter():
    assert resolve_part(["nose", "head_midpoint", "mouse_center"], "headcenter") == 1


def test_reverse_direction_alias():
    assert resolve_part(["nose", "tailbase", "bodycenter"], "mouse_center") == 2


def test_returns_none_for_unknown():
    assert resolve_part(["nose", "tailbase"], "wholly_unknown_part") is None


def test_empty_inputs():
    assert resolve_part([], "bodycenter") is None
    assert resolve_part(["nose"], "") is None


def test_prefers_exact_over_synonym():
    assert resolve_part(["mouse_center", "bodycenter"], "bodycenter") == 1

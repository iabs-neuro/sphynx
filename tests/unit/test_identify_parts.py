from sphynx.bodyparts import identify_parts, Point


def test_finds_common_parts():
    p = identify_parts(["nose", "tailbase", "bodycenter", "leftear"])
    assert p.nose == 0
    assert p.tailbase == 1
    assert p.center == 2
    assert p.left_ear == 3


def test_case_insensitive():
    p = identify_parts(["Nose", "TAILBASE", "BodyCenter"])
    assert p.nose == 0 and p.tailbase == 1 and p.center == 2


def test_center_synonym():
    assert identify_parts(["mass center"]).center == 0


def test_tailbase_synonym():
    assert identify_parts(["tail base"]).tailbase == 0


def test_returns_none_for_missing():
    p = identify_parts(["nose"])
    assert p.tailbase is None and p.center is None


def test_superanimal_topviewmouse_schema():
    names = ["nose", "left_ear", "right_ear", "head_midpoint",
             "left_shoulder", "right_shoulder", "left_midside", "right_midside",
             "left_hip", "right_hip", "mouse_center", "tail_base"]
    p = identify_parts(names)
    assert p.nose == 0
    assert p.left_ear == 1
    assert p.right_ear == 2
    assert p.head_center == 3
    assert p.left_fore_limb == 4
    assert p.right_fore_limb == 5
    assert p.left_body_center == 6
    assert p.right_body_center == 7
    assert p.left_hind_limb == 8
    assert p.right_hind_limb == 9
    assert p.center == 10
    assert p.tailbase == 11


def test_center_prefers_direct_over_midside():
    p = identify_parts(["left_midside", "right_midside", "mouse_center"])
    assert p.center == 2
    assert p.left_body_center == 0
    assert p.right_body_center == 1

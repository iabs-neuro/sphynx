from sphynx.paradigms import Paradigm, open_field


def test_open_field_bundle():
    of = open_field()
    assert isinstance(of, Paradigm)
    assert of.name == "OF"
    for act in ("rest", "walk", "locomotion", "freezing", "rear"):
        assert act in of.builtin_acts
    assert "distance" in of.metrics


def test_paradigm_is_declarative_data():
    of = open_field()
    assert isinstance(of.builtin_acts, list)
    assert isinstance(of.metrics, list)

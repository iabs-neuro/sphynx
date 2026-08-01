from sphynx.project import PresetRule, Project, ProjectSession
from sphynx.project.presets import (
    assign_presets, resolve_preset, runnable_sessions,
)


def _session(name, **metadata):
    return ProjectSession(name=name, dlc_path=f"{name}.csv", metadata=metadata)


def test_no_rules_means_unassigned():
    got = resolve_preset(_session("s", day="1D"), [])
    assert got.preset_path == ""
    assert got.source == "unassigned"


def test_empty_match_applies_to_every_session():
    got = resolve_preset(_session("s", day="1D"), [PresetRule("all.mat")])
    assert got.preset_path == "all.mat"
    assert got.source == "rule: all sessions"


def test_rule_matches_on_metadata():
    rules = [PresetRule("all.mat"), PresetRule("day3.mat", {"day": "3D"})]
    assert resolve_preset(_session("s", day="3D"), rules).preset_path == "day3.mat"
    assert resolve_preset(_session("s", day="1D"), rules).preset_path == "all.mat"


def test_the_last_matching_rule_wins():
    rules = [PresetRule("first.mat", {"day": "1D"}),
             PresetRule("second.mat", {"day": "1D"})]
    assert resolve_preset(_session("s", day="1D"), rules).preset_path == "second.mat"


def test_several_fields_are_anded():
    rules = [PresetRule("both.mat", {"day": "1D", "group": "control"})]
    assert resolve_preset(_session("a", day="1D", group="control"),
                          rules).preset_path == "both.mat"
    assert resolve_preset(_session("b", day="1D", group="test"),
                          rules).source == "unassigned"


def test_the_source_names_the_rule():
    rules = [PresetRule("day3.mat", {"day": "3D"})]
    assert resolve_preset(_session("s", day="3D"), rules).source == "rule: day=3D"


def test_manual_path_overrides_every_rule():
    session = _session("s", day="3D")
    session.preset_path = "mine.mat"
    got = resolve_preset(session, [PresetRule("day3.mat", {"day": "3D"})])
    assert got.preset_path == "mine.mat"
    assert got.source == "manual"


def test_assign_presets_covers_every_session():
    project = Project(sessions=[_session("a", day="1D"), _session("b", day="3D")],
                      preset_rules=[PresetRule("all.mat")])
    assigned = assign_presets(project)
    assert set(assigned) == {"a", "b"}
    assert assigned["b"].preset_path == "all.mat"


def test_sessions_without_a_preset_are_blocked_not_run():
    project = Project(sessions=[_session("a"), _session("b")],
                      preset_rules=[PresetRule("all.mat", {"day": "1D"})])
    ready, blocked = runnable_sessions(project)
    assert [s.name for s, _ in ready] == []
    assert [s.name for s, _ in blocked] == ["a", "b"]


def test_ready_sessions_carry_their_assignment():
    project = Project(sessions=[_session("a", day="1D")],
                      preset_rules=[PresetRule("all.mat")])
    ready, blocked = runnable_sessions(project)
    assert blocked == []
    session, assignment = ready[0]
    assert session.name == "a"
    assert assignment.preset_path == "all.mat"


def test_a_session_without_a_dlc_path_is_blocked():
    session = ProjectSession(name="a", metadata={"day": "1D"})
    project = Project(sessions=[session], preset_rules=[PresetRule("all.mat")])
    ready, blocked = runnable_sessions(project)
    assert ready == []
    assert blocked[0][1] == "no DLC file"

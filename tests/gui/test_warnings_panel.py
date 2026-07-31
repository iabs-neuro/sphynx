from sphynx.metrics.registry import MetricResults
from sphynx.paradigms.validate import ValidationIssue, ValidationReport
from sphynx_gui.warnings_panel import WarningsPanel


class _Result:
    def __init__(self, validation=None, degraded=None, metrics=None):
        self.validation = validation
        self.degraded = degraded or {}
        self.metrics = metrics


def test_empty_result_says_nothing_is_wrong(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result())
    assert panel.rows == []
    assert "No warnings" in panel.list_widget.item(0).text()


def test_validation_errors_and_warnings_are_listed(qtbot):
    report = ValidationReport(paradigm="EOF", issues=[
        ValidationIssue("needs_object", "error", "needs at least one object"),
        ValidationIssue("soft", "warning", "something to check"),
    ])
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(validation=report))
    sources = [row[0] for row in panel.rows]
    levels = [row[1] for row in panel.rows]
    assert sources == ["validation", "validation"]
    assert levels == ["error", "warning"]
    assert "at least one object" in panel.rows[0][2]


def test_degraded_acts_are_listed(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(degraded={"nose_at_hole1": ['body part "nose" not found']}))
    assert panel.rows[0][0] == "act"
    assert "nose_at_hole1" in panel.rows[0][2]
    assert "nose" in panel.rows[0][2]


def test_metric_errors_are_listed(qtbot):
    metrics = MetricResults(values={"ok": 1.0},
                            errors={"primary_errors": "missing geometry: target_zone"})
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(metrics=metrics))
    assert panel.rows[0][0] == "metric"
    assert "primary_errors" in panel.rows[0][2]


def test_all_three_sources_combine(qtbot):
    report = ValidationReport(paradigm="Barnes", issues=[
        ValidationIssue("needs_one_target", "error", "exactly one target")])
    metrics = MetricResults(errors={"target_ordinal": "no target member"})
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(validation=report, degraded={"a": ["gone"]},
                              metrics=metrics))
    assert [row[0] for row in panel.rows] == ["validation", "act", "metric"]
    assert panel.list_widget.count() == 3


def test_clear_resets_the_panel(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(degraded={"a": ["gone"]}))
    panel.clear()
    assert panel.rows == []


def test_showing_a_new_result_replaces_the_old_rows(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(degraded={"a": ["gone"]}))
    panel.show_result(_Result())
    assert panel.rows == []

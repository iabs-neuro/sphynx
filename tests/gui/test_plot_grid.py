import numpy as np

from sphynx_gui.plot_grid import PlotGrid


class _Trace:
    def __init__(self, name, n=100):
        self.name = name
        self.x_smooth = np.linspace(10.0, 90.0, n)
        self.y_smooth = np.linspace(10.0, 90.0, n)
        self.velocity = np.linspace(0.0, 5.0, n)


class _Options:
    pxl2sm = 10.0
    FrameRate = 30.0
    Width = 100
    Height = 100


class _Result:
    def __init__(self):
        self.body_parts_traces = [_Trace("bodycenter")]
        self.options = _Options()


def test_four_named_canvases(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    assert set(grid.canvases) == {
        "trajectory", "heatmap", "speed_histogram", "speed_vs_time", "etogram"}


def test_show_result_draws_every_panel(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Result())
    for canvas in grid.canvases.values():
        assert canvas.figure.axes            # something was plotted


def test_clear_empties_the_figures(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Result())
    grid.clear()
    for canvas in grid.canvases.values():
        assert canvas.figure.axes == []


def test_toggle_maximise_hides_the_others(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.toggle_maximise("heatmap")
    assert grid.maximised == "heatmap"
    assert grid.canvases["trajectory"].isHidden()
    assert not grid.canvases["heatmap"].isHidden()


def test_toggle_maximise_twice_restores_the_grid(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.toggle_maximise("heatmap")
    grid.toggle_maximise("heatmap")
    assert grid.maximised is None
    assert not grid.canvases["trajectory"].isHidden()


def test_missing_trace_does_not_crash(qtbot):
    class _Empty:
        body_parts_traces = []
        options = _Options()

    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Empty())               # must not raise
    assert grid.canvases


def test_etogram_is_the_fifth_panel(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    assert "etogram" in grid.canvases


def test_etogram_is_drawn_from_the_acts(qtbot):
    import numpy as np

    from sphynx.pipeline.analyze import SessionAct

    class _R(_Result):
        def __init__(self):
            super().__init__()
            mask = np.zeros(100)
            mask[10:30] = 1
            self.acts = [SessionAct("rest", mask, "builtin")]

    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_R())
    assert grid.canvases["etogram"].figure.axes


def test_etogram_survives_a_result_without_acts(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Result())          # no `acts` attribute at all
    assert grid.canvases["etogram"].figure.axes

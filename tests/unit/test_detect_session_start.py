import types

import numpy as np

from sphynx.preprocess.session import detect_session_start_frame


def _dlc(x, y):
    return types.SimpleNamespace(X=x, Y=y)


def test_detects_start_after_absent_prefix():
    n, parts = 100, 2
    x = np.full((parts, n), np.nan)
    y = np.full((parts, n), np.nan)
    x[:, 30:] = 50.0
    y[:, 30:] = 50.0
    start, info = detect_session_start_frame(_dlc(x, y), window_frames=10)
    assert start == 31  # first populated frame (0-based 30) -> 1-based 31
    assert info["message"] == ""
    assert info["first_populated_frame"] == 31


def test_present_from_frame_one():
    x = np.full((2, 50), 10.0)
    y = np.full((2, 50), 10.0)
    start, info = detect_session_start_frame(_dlc(x, y))
    assert start == 1


def test_never_populated_returns_one_with_message():
    x = np.full((2, 40), np.nan)
    y = np.full((2, 40), np.nan)
    start, info = detect_session_start_frame(_dlc(x, y))
    assert start == 1
    assert info["message"] != ""


def test_no_frames_returns_one():
    start, info = detect_session_start_frame(_dlc(np.zeros((2, 0)), np.zeros((2, 0))))
    assert start == 1
    assert info["message"] != ""

from pathlib import Path

import cv2
import numpy as np
import pytest

import sphynx.io.video as video_module
from sphynx.exceptions import SphynxIOError
from sphynx.io.video import read_frame, video_info

_ROOT = Path(__file__).resolve().parents[2]
_VIDEO = _ROOT / "Demo/Video/NOF_H01_1D.mp4"

needs_video = pytest.mark.skipif(not _VIDEO.is_file(),
                                 reason="Demo video not present")


def test_missing_file_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        video_info(tmp_path / "nope.mp4")


def test_a_file_that_is_not_a_video_raises(tmp_path):
    fake = tmp_path / "not_a_video.mp4"
    fake.write_text("hello", encoding="utf-8")
    with pytest.raises(SphynxIOError):
        video_info(fake)


@needs_video
def test_info_reports_the_shape():
    info = video_info(_VIDEO)
    assert info.n_frames > 0
    assert info.frame_rate > 0
    assert info.width > 0 and info.height > 0


@needs_video
def test_first_frame_is_an_rgb_image():
    frame = read_frame(_VIDEO, 0)
    assert frame.ndim == 3
    assert frame.shape[2] == 3
    assert frame.dtype == np.uint8


@needs_video
def test_frame_matches_the_reported_size():
    info = video_info(_VIDEO)
    frame = read_frame(_VIDEO, 0)
    assert frame.shape[:2] == (info.height, info.width)


@needs_video
def test_a_later_frame_differs_from_the_first():
    first = read_frame(_VIDEO, 0)
    later = read_frame(_VIDEO, min(50, video_info(_VIDEO).n_frames - 1))
    assert not np.array_equal(first, later)


@needs_video
def test_an_index_past_the_end_raises():
    info = video_info(_VIDEO)
    with pytest.raises(SphynxIOError):
        read_frame(_VIDEO, info.n_frames + 10)


@needs_video
def test_a_negative_index_raises():
    with pytest.raises(SphynxIOError):
        read_frame(_VIDEO, -1)


# --- S4d review F4: the seek result is verified ---------------------------

class _FakeCapture:
    """A reader whose position after read() is whatever we tell it to be.

    OpenCV reports CAP_PROP_POS_FRAMES as the index of the NEXT frame, so an
    honest reader asked for frame N reports N + 1 once the read is done.
    """

    def __init__(self, position_after_read, n_frames=1000):
        self._position = float(position_after_read)
        self._n_frames = float(n_frames)

    def isOpened(self):
        return True

    def get(self, prop):
        if prop == cv2.CAP_PROP_FRAME_COUNT:
            return self._n_frames
        if prop == cv2.CAP_PROP_POS_FRAMES:
            return self._position
        return 0.0

    def set(self, prop, value):
        return True

    def read(self):
        return True, np.zeros((4, 4, 3), dtype=np.uint8)

    def release(self):
        pass


def _fake_file(tmp_path):
    path = tmp_path / "clip.mp4"
    path.write_bytes(b"not really a video")
    return path


def test_a_reader_that_returns_another_frame_raises(tmp_path, monkeypatch):
    # asked for 100, actually handed back frame 60 (a keyframe nearby)
    monkeypatch.setattr(video_module.cv2, "VideoCapture",
                        lambda _p: _FakeCapture(61.0))
    with pytest.raises(SphynxIOError) as excinfo:
        read_frame(_fake_file(tmp_path), 100)
    message = str(excinfo.value)
    assert "100" in message and "60" in message


def test_an_honest_reader_is_accepted(tmp_path, monkeypatch):
    monkeypatch.setattr(video_module.cv2, "VideoCapture",
                        lambda _p: _FakeCapture(101.0))
    frame = read_frame(_fake_file(tmp_path), 100)
    assert frame.shape == (4, 4, 3)


@needs_video
def test_a_mid_file_frame_of_the_demo_video_seeks_exactly():
    # If this ever fails, the demo codec cannot seek exactly and the tolerance
    # in read_frame has to be revisited -- not deleted.
    info = video_info(_VIDEO)
    frame = read_frame(_VIDEO, info.n_frames // 2)
    assert frame.shape[:2] == (info.height, info.width)

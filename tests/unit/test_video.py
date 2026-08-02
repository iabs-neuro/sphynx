from pathlib import Path

import numpy as np
import pytest

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

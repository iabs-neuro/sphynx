"""Read frames from a video (S4d).

The ONLY place OpenCV is imported. A frame that cannot be read raises rather
than returning a blank image: marking zones onto a black rectangle would look
like it worked.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from sphynx.exceptions import SphynxIOError


@dataclass
class VideoInfo:
    path: str
    n_frames: int
    frame_rate: float
    width: int
    height: int


def _open(path):
    source = Path(path)
    if not source.is_file():
        raise SphynxIOError(f"video not found: {source}")
    capture = cv2.VideoCapture(str(source))
    if not capture.isOpened():
        capture.release()
        raise SphynxIOError(f"cannot open video: {source}")
    return capture


def video_info(path) -> VideoInfo:
    capture = _open(path)
    try:
        n_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        frame_rate = float(capture.get(cv2.CAP_PROP_FPS))
        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    finally:
        capture.release()
    if n_frames <= 0 or width <= 0 or height <= 0:
        raise SphynxIOError(
            f"video reports no frames or no size: {path}; it may be corrupt "
            "or in a codec OpenCV cannot read")
    return VideoInfo(str(path), n_frames, frame_rate, width, height)


def read_frame(path, index: int = 0) -> np.ndarray:
    """One frame as an HxWx3 uint8 RGB array."""
    if index < 0:
        raise SphynxIOError(f"frame index must be >= 0; got {index}")
    capture = _open(path)
    try:
        total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        if total > 0 and index >= total:
            raise SphynxIOError(
                f"frame {index} is past the end of {path} ({total} frames)")
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(index))
        ok, frame = capture.read()
    finally:
        capture.release()
    if not ok or frame is None:
        raise SphynxIOError(f"cannot read frame {index} of {path}")
    return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

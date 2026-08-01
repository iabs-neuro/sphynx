"""Find sessions in a folder and read what their names state (S4c).

A name the pattern does not match is MARKED, never guessed at: the row keeps
empty metadata and the caller fills it in. Rescanning adds new files and leaves
sessions already in the project alone, so hand-edited metadata survives.
"""

from __future__ import annotations

import re
from pathlib import Path

from sphynx.exceptions import SphynxIOError
from sphynx.project.model import DEFAULT_PATTERN, ProjectSession


# DeepLabCut writes "<video>DLC_<network>_<project><date>shuffle<n>_<iters>.csv"
# (sometimes with _filtered or _el appended). Everything from the DLC marker on
# describes the TRACKING, not the session, so the session name is the part
# before it. This reads DeepLabCut's own convention rather than guessing.
_SCORER = re.compile(
    r"(DLC|DeepCut)_(resnet|mobnet|dlcrnet|efficientnet|effnet|hrnet)",
    re.IGNORECASE)
# If a network we do not know about slips through, the greedy day group would
# swallow the whole scorer string and quietly produce one export column per
# session. Spotting the leftover marker is what keeps that visible.
_SCORER_LEFTOVER = re.compile(r"(DLC|DeepCut)_", re.IGNORECASE)


def session_name_from_file(stem: str) -> str:
    """The video name a DeepLabCut csv was produced from."""
    match = _SCORER.search(str(stem))
    return str(stem)[: match.start()] if match else str(stem)


def parse_session_name(name, pattern) -> dict:
    """Named groups the pattern finds in `name`, or {} when it does not match."""
    try:
        match = re.match(pattern, str(name))
    except re.error as e:
        raise SphynxIOError(f"invalid session-name pattern: {e}") from e
    parsed = {k: v for k, v in (match.groupdict().items() if match else [])
              if v is not None}
    if any(_SCORER_LEFTOVER.search(str(v)) for v in parsed.values()):
        # A tracking suffix ended up inside a metadata field, so the name was
        # not really understood. Marking it unparsed beats exporting columns
        # named after a network.
        return {}
    return parsed


def session_is_parsed(session) -> bool:
    return bool(session.metadata)


def scan_folder(root, pattern: str = DEFAULT_PATTERN, existing=None) -> list:
    """Sessions for every csv under `root`, merged with the ones already known."""
    folder = Path(root)
    if not folder.is_dir():
        raise SphynxIOError(f"folder not found: {folder}")
    try:
        re.compile(pattern)
    except re.error as e:
        raise SphynxIOError(f"invalid session-name pattern: {e}") from e

    known = {s.name: s for s in (existing or [])}
    order = [s.name for s in (existing or [])]

    seen_paths = {s.dlc_path for s in (existing or []) if s.dlc_path}
    for path in sorted(folder.rglob("*.csv")):
        if str(path) in seen_paths:
            continue          # already in the project, possibly hand-edited
        name = session_name_from_file(path.stem)
        if name in known:
            # Two folders can hold a file of the same name. Dropping the second
            # would lose a session without saying so, and overwriting the first
            # would lose its edits, so the name is qualified by its folder.
            base = session_name_from_file(path.stem)
            name = f"{path.parent.name}/{base}"
            suffix = 2
            while name in known:
                name = f"{path.parent.name}/{base} ({suffix})"
                suffix += 1
        known[name] = ProjectSession(
            name=name, dlc_path=str(path),
            metadata=parse_session_name(session_name_from_file(path.stem),
                                        pattern))
        order.append(name)

    return [known[name] for name in order]

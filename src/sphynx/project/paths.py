"""Where a project keeps its files (S4f).

A project is a folder with a fixed layout. Paths under that folder are stored
relative to it, so the whole thing can be copied to another machine and still
open; anything else is stored absolute, which is exactly what makes it visibly
external. The stored string is the only signal -- a separate "is external"
flag could drift away from the path it claims to describe.

Real symbolic links are not created. On Windows `os.symlink` on a file needs
administrator rights or Developer Mode, hard links do not cross volumes, and
an Explorer .lnk is a shell format Python will not dereference. A "link" here
means the project records where the file already lives.
"""

from __future__ import annotations

import filecmp
import os
import shutil
from pathlib import Path

from sphynx.exceptions import SphynxIOError, SphynxValueError

LAYOUT = ("raw_videos", "tracking", "presets", "behavior", "temp")


def _root(root) -> Path:
    return Path(root).expanduser().resolve()


def store_path(path, root) -> str:
    """Relative to `root` when the path is under it, absolute otherwise."""
    if not path:
        return ""
    target = Path(path).expanduser()
    # resolve() so that a path reached through a different spelling of the
    # same folder still lands inside; strict=False because the file need not
    # exist yet.
    target = target.resolve()
    try:
        return str(target.relative_to(_root(root)))
    except ValueError:
        # Not under the root. relative_to is used rather than a string prefix
        # test so that a sibling folder whose name merely starts with the
        # root's name is not mistaken for something inside it.
        return str(target)


def resolve_path(stored, root) -> str:
    """The absolute path a stored one refers to."""
    if not stored:
        return ""
    path = Path(stored)
    if path.is_absolute():
        return str(path)
    return str(_root(root) / path)


def is_external(stored) -> bool:
    """True when the stored path points outside the project folder."""
    return bool(stored) and os.path.isabs(str(stored))


def create_layout(root) -> dict:
    """Make the project's subfolders; returns {name: "created"|"existed"}.

    Every folder is made up front rather than on first write: the user is
    told to drop files into them by hand, which needs them to be there."""
    base = Path(root).expanduser()
    states: dict = {}
    try:
        base.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise SphynxIOError(f"cannot create the project folder {base}: {e}") from e
    for name in LAYOUT:
        folder = base / name
        if folder.is_dir():
            states[name] = "existed"
            continue
        if folder.exists():
            raise SphynxIOError(
                f"{folder} exists but is not a folder, so the project's "
                f"{name!r} folder cannot be created there")
        try:
            folder.mkdir()
        except OSError as e:
            raise SphynxIOError(f"cannot create {folder}: {e}") from e
        states[name] = "created"
    return states


def import_file(source, root, subdir: str, copy: bool) -> str:
    """Bring a file into the project, by copying it or by referring to it.

    `copy=False` moves nothing and returns the path as stored -- absolute for
    a file outside the project, which is what marks the row external."""
    if subdir not in LAYOUT:
        raise SphynxValueError(
            f"unknown project folder {subdir!r}; expected one of {LAYOUT}")
    origin = Path(source).expanduser()
    if not origin.is_file():
        raise SphynxIOError(f"file not found: {origin}")
    if not copy:
        return store_path(origin, root)

    destination = _root(root) / subdir / origin.name
    if destination.resolve() == origin.resolve():
        return store_path(destination, root)
    if destination.exists():
        # Same name, same bytes: the file is already here, so this is a
        # repeated import rather than a collision.
        if filecmp.cmp(origin, destination, shallow=False):
            return store_path(destination, root)
        raise SphynxIOError(
            f"{destination} already exists and differs from {origin}; "
            "rename one of them, or add this file as a link instead of a copy")
    try:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin, destination)
    except OSError as e:
        raise SphynxIOError(f"cannot copy {origin} to {destination}: {e}") from e
    return store_path(destination, root)

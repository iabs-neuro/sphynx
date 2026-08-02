"""Project model (S4c).

A project references its data rather than copying it: DLC files and presets stay
where they are and the project stores paths. A path that no longer resolves is a
visible state of the row, not a silent skip.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from sphynx.exceptions import SphynxValueError

# The named groups become metadata keys, so they are the names rules are
# written against: exp, mouse, day.
DEFAULT_PATTERN = r"^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<day>.+)$"


@dataclass
class ProjectSession:
    name: str = ""
    dlc_path: str = ""
    preset_path: str = ""          # set by hand; overrides every rule
    metadata: dict = field(default_factory=dict)
    video_path: str = ""           # the clip the tracking came from, if known


@dataclass
class PresetRule:
    """A preset plus the metadata it applies to. An empty match means all
    sessions; several fields are ANDed."""

    preset_path: str = ""
    match: dict = field(default_factory=dict)


@dataclass
class Project:
    name: str = ""
    sessions: list = field(default_factory=list)        # ProjectSession
    preset_rules: list = field(default_factory=list)    # PresetRule
    paradigm: str = "OF"
    library_path: str = ""
    out_dir: str = ""
    name_pattern: str = DEFAULT_PATTERN
    # Which acts, act statistics and named metrics the export keeps; empty
    # lists (or an absent key) mean everything.
    output_selection: dict = field(default_factory=dict)

    # The project folder. Written for reference only: on load the root is
    # taken from where project.json actually sits, so a project that was
    # moved or copied still opens.
    root: str = ""
    # Each folder defaults to <root>/<name>; a non-empty value overrides it,
    # which is how an existing tree with other names is adopted.
    raw_videos_dir: str = ""
    tracking_dir: str = ""
    presets_dir: str = ""
    behavior_dir: str = ""
    temp_dir: str = ""
    preprocess_path: str = ""


# Folder name -> the field that may override it.
_FOLDER_FIELDS = {
    "raw_videos": "raw_videos_dir",
    "tracking": "tracking_dir",
    "presets": "presets_dir",
    "behavior": "behavior_dir",
    "temp": "temp_dir",
}


def folder(project, which: str) -> str:
    """The absolute path of one project folder, honouring an override.

    Empty when the project has no root: without a project the tabs behave as
    they did before, so "no folder" is a state, not a failure."""
    if which not in _FOLDER_FIELDS:
        raise SphynxValueError(
            f"unknown project folder {which!r}; expected one of "
            f"{tuple(_FOLDER_FIELDS)}")
    override = str(getattr(project, _FOLDER_FIELDS[which], "") or "")
    if override:
        return str(Path(override).expanduser())
    root = str(getattr(project, "root", "") or "")
    if not root:
        return ""
    return str(Path(root).expanduser() / which)

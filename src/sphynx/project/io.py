"""Save/load a project as JSON (S4c; folder layout added in S4f)."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path

from sphynx.exceptions import SphynxValueError
from sphynx.io.jsonio import check_keys, from_fields, read_json, write_json
from sphynx.project.model import DEFAULT_PATTERN, PresetRule, Project, ProjectSession

SCHEMA_VERSION = 2

# Version 1 knew nothing of a project folder: it was one file anywhere,
# holding absolute paths to everything.
_V1_TOP_LEVEL = {"schema_version", "name", "sessions", "preset_rules",
                 "paradigm", "library_path", "out_dir", "name_pattern",
                 "output_selection"}

_TOP_LEVEL = _V1_TOP_LEVEL | {
    "root", "raw_videos_dir", "tracking_dir", "presets_dir", "behavior_dir",
    "temp_dir", "preprocess_path"}


@dataclass
class LoadedProject:
    """A project plus how it arrived, so an upgrade can be made visible."""

    project: Project
    upgraded_from: int | None = None


def project_to_dict(project: Project) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "name": project.name,
        "sessions": [asdict(s) for s in project.sessions],
        "preset_rules": [asdict(r) for r in project.preset_rules],
        "paradigm": project.paradigm,
        "library_path": project.library_path,
        "out_dir": project.out_dir,
        "name_pattern": project.name_pattern,
        "output_selection": dict(project.output_selection),
        "root": project.root,
        "raw_videos_dir": project.raw_videos_dir,
        "tracking_dir": project.tracking_dir,
        "presets_dir": project.presets_dir,
        "behavior_dir": project.behavior_dir,
        "temp_dir": project.temp_dir,
        "preprocess_path": project.preprocess_path,
    }


def _version_of(data: dict) -> int:
    if "schema_version" not in data:
        raise SphynxValueError("project has no schema_version")
    version = data["schema_version"]
    if version not in (1, SCHEMA_VERSION):
        raise SphynxValueError(
            f"unsupported project schema version {version}; this build reads "
            f"version {SCHEMA_VERSION} and upgrades version 1")
    return int(version)


def project_from_dict(data: dict) -> Project:
    """Read either schema version; a version 1 file is upgraded in memory.

    Nothing is written back here. Rewriting a file the user only asked to
    open would be exactly the silent action the project forbids -- the caller
    marks the project unsaved and lets the user save it."""
    version = _version_of(data)
    check_keys(data, _V1_TOP_LEVEL if version == 1 else _TOP_LEVEL, "project")
    return Project(
        name=data.get("name", ""),
        sessions=[from_fields(ProjectSession, s, "project session")
                  for s in data.get("sessions", [])],
        preset_rules=[from_fields(PresetRule, r, "preset rule")
                      for r in data.get("preset_rules", [])],
        paradigm=data.get("paradigm", "OF"),
        library_path=data.get("library_path", ""),
        out_dir=data.get("out_dir", ""),
        name_pattern=data.get("name_pattern", DEFAULT_PATTERN),
        output_selection=dict(data.get("output_selection", {})),
        root=data.get("root", ""),
        raw_videos_dir=data.get("raw_videos_dir", ""),
        tracking_dir=data.get("tracking_dir", ""),
        presets_dir=data.get("presets_dir", ""),
        behavior_dir=data.get("behavior_dir", ""),
        temp_dir=data.get("temp_dir", ""),
        preprocess_path=data.get("preprocess_path", ""),
    )


def save_project(project: Project, path) -> str:
    return write_json(project_to_dict(project), path)


def load_project_detailed(path) -> LoadedProject:
    """Read a project file and say whether it had to be upgraded.

    The root comes from where the file actually sits, not from the stored
    `root` field: a project that was moved or copied carries a stale field,
    and honouring it would resolve every relative path against a folder that
    is no longer there."""
    data = read_json(path)
    version = _version_of(data)
    project = project_from_dict(data)
    project.root = str(Path(path).expanduser().resolve().parent)
    return LoadedProject(project=project,
                         upgraded_from=1 if version == 1 else None)


def load_project(path) -> Project:
    return load_project_detailed(path).project

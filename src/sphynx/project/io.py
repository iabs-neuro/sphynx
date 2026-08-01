"""Save/load a project as JSON (S4c)."""

from __future__ import annotations

from dataclasses import asdict

from sphynx.exceptions import SphynxValueError
from sphynx.io.jsonio import check_keys, from_fields, read_json, write_json
from sphynx.project.model import DEFAULT_PATTERN, PresetRule, Project, ProjectSession

SCHEMA_VERSION = 1

_TOP_LEVEL = {"schema_version", "name", "sessions", "preset_rules", "paradigm",
              "library_path", "out_dir", "name_pattern", "output_selection"}


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
    }


def project_from_dict(data: dict) -> Project:
    check_keys(data, _TOP_LEVEL, "project")
    if "schema_version" not in data:
        raise SphynxValueError("project has no schema_version")
    if data["schema_version"] != SCHEMA_VERSION:
        raise SphynxValueError(
            f"unsupported project schema version {data['schema_version']}; "
            f"this build reads version {SCHEMA_VERSION}")
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
    )


def save_project(project: Project, path) -> str:
    return write_json(project_to_dict(project), path)


def load_project(path) -> Project:
    return project_from_dict(read_json(path))

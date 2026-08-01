"""Turn a project into batch specs and run it (S4c)."""

from __future__ import annotations

from sphynx.pipeline.batch import BatchResult, run_batch
from sphynx.project.presets import runnable_sessions


def project_specs(project):
    """(specs, blocked). Blocked sessions never reach the engine."""
    ready, blocked = runnable_sessions(project)
    specs = []
    for session, assignment in ready:
        metadata = session.metadata or {}
        specs.append({
            "session_name": session.name,
            "dlc_path": session.dlc_path,
            "preset_path": assignment.preset_path,
            "mouse": metadata.get("mouse", ""),
            "group": metadata.get("group", ""),
            "line": metadata.get("line", ""),
            "trial": metadata.get("trial", metadata.get("session", "")),
        })
    return specs, blocked


def run_project(project, config=None, on_progress=None,
                should_stop=None) -> BatchResult:
    """Run every ready session. A failing session is recorded, not fatal."""
    specs, _blocked = project_specs(project)
    if should_stop is not None:
        wanted = []
        for spec in specs:
            if should_stop():
                break
            wanted.append(spec)
        specs = wanted
    return run_batch(
        specs, config=config, out_dir=project.out_dir or "",
        paradigm=project.paradigm or None, on_progress=on_progress,
        continue_on_error=True)

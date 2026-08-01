"""Turn a project into batch specs and run it (S4c)."""

from __future__ import annotations

from sphynx.acts.library_io import load_library
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
            "trial": metadata.get("trial", metadata.get("day", "")),
        })
    return specs, blocked


def run_project(project, config=None, on_progress=None,
                should_stop=None) -> BatchResult:
    """Run every ready session. A failing session is recorded, not fatal.

    `should_stop` is handed to the batch so it is polled between sessions: a
    Cancel button that only trimmed the queue before the run started would stop
    nothing once the run was under way."""
    specs, _blocked = project_specs(project)
    library = None
    if getattr(project, "library_path", ""):
        # The project states which acts it was analysed with; ignoring it would
        # make a batch compute a different act set from the Analyze tab.
        library = load_library(project.library_path)
    return run_batch(
        specs, config=config, out_dir=project.out_dir or "",
        paradigm=project.paradigm or None, library=library,
        on_progress=on_progress, should_stop=should_stop,
        continue_on_error=True)

"""Turn a project into batch specs and run it (S4c)."""

from __future__ import annotations

from sphynx.acts.library_io import load_library
from sphynx.pipeline.batch import BatchResult, run_batch
from sphynx.project.model import folder
from sphynx.project.paths import resolve_path
from sphynx.project.presets import runnable_sessions


def project_specs(project):
    """(specs, blocked). Blocked sessions never reach the engine.

    Paths stored relative to the project folder are resolved here, once, so
    the engine only ever sees absolute paths and cannot depend on what the
    working directory happens to be."""
    ready, blocked = runnable_sessions(project)
    root = getattr(project, "root", "")
    specs = []
    for session, assignment in ready:
        metadata = session.metadata or {}
        specs.append({
            "session_name": session.name,
            "dlc_path": resolve_path(session.dlc_path, root),
            "preset_path": resolve_path(assignment.preset_path, root),
            "mouse": metadata.get("mouse", ""),
            "group": metadata.get("group", ""),
            "line": metadata.get("line", ""),
            "trial": metadata.get("trial", metadata.get("day", "")),
        })
    return specs, blocked


def batch_out_dir(project) -> str:
    """Where a batch's per-session output belongs: behavior/.

    A batch is the real run. A single run from the Analyze tab is setup and
    goes to temp/, so the two never mix and it stays clear afterwards which
    numbers were final. `out_dir` remains an explicit override for projects
    that keep their results somewhere else."""
    root = getattr(project, "root", "")
    if getattr(project, "out_dir", ""):
        return resolve_path(project.out_dir, root)
    return folder(project, "behavior")


def run_project(project, config=None, on_progress=None,
                should_stop=None) -> BatchResult:
    """Run every ready session. A failing session is recorded, not fatal.

    `should_stop` is handed to the batch so it is polled between sessions: a
    Cancel button that only trimmed the queue before the run started would stop
    nothing once the run was under way."""
    specs, _blocked = project_specs(project)
    root = getattr(project, "root", "")
    library = None
    if getattr(project, "library_path", ""):
        # The project states which acts it was analysed with; ignoring it would
        # make a batch compute a different act set from the Analyze tab.
        library = load_library(resolve_path(project.library_path, root))
    return run_batch(
        specs, config=config, out_dir=batch_out_dir(project),
        paradigm=project.paradigm or None, library=library,
        on_progress=on_progress, should_stop=should_stop,
        continue_on_error=True)

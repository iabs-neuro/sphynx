"""Assign a preset to each session by declarative rules (S4c).

One spatial layout often covers a whole experiment, but the design can depend on
the day or the group, so a preset is chosen by matching metadata rather than
typed per row. Every assignment carries WHERE it came from: an assignment nobody
can see is the silent substitution section 10 forbids.
"""

from __future__ import annotations

from dataclasses import dataclass

UNASSIGNED = "unassigned"
MANUAL = "manual"


@dataclass
class PresetAssignment:
    preset_path: str = ""
    source: str = UNASSIGNED


def _describe(rule) -> str:
    if not rule.match:
        return "rule: all sessions"
    return "rule: " + ", ".join(f"{k}={v}" for k, v in sorted(rule.match.items()))


def _matches(session, rule) -> bool:
    return all(str(session.metadata.get(key, "")) == str(value)
               for key, value in rule.match.items())


def resolve_preset(session, rules) -> PresetAssignment:
    """A hand-typed path wins; otherwise the LAST matching rule does, so a
    general rule can be written first and refined by the ones below it."""
    if session.preset_path:
        return PresetAssignment(session.preset_path, MANUAL)
    chosen = None
    for rule in rules or []:
        if _matches(session, rule):
            chosen = rule
    if chosen is None:
        return PresetAssignment("", UNASSIGNED)
    return PresetAssignment(chosen.preset_path, _describe(chosen))


def assign_presets(project) -> dict:
    return {s.name: resolve_preset(s, project.preset_rules)
            for s in project.sessions}


def runnable_sessions(project):
    """Split the project into (ready, blocked).

    Blocked sessions are NOT run with some stand-in preset -- they are returned
    with the reason so the table can show it."""
    ready, blocked = [], []
    for session in project.sessions:
        assignment = resolve_preset(session, project.preset_rules)
        if not session.dlc_path:
            blocked.append((session, "no DLC file"))
        elif not assignment.preset_path:
            blocked.append((session, "no preset assigned"))
        else:
            ready.append((session, assignment))
    return ready, blocked

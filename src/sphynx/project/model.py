"""Project model (S4c).

A project references its data rather than copying it: DLC files and presets stay
where they are and the project stores paths. A path that no longer resolves is a
visible state of the row, not a silent skip.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# The named groups become metadata keys, so they are the names rules are
# written against: exp, mouse, day.
DEFAULT_PATTERN = r"^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<day>.+)$"


@dataclass
class ProjectSession:
    name: str = ""
    dlc_path: str = ""
    preset_path: str = ""          # set by hand; overrides every rule
    metadata: dict = field(default_factory=dict)


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

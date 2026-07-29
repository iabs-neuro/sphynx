"""Experiment paradigms: declarative bundles with inheritance (S2 layers 6-7).

A paradigm declares composites, act families, metric references, config
defaults and validation rules. `resolve_paradigm` flattens a child against its
ancestors; `validate_paradigm` reports whether a preset satisfies it.
"""

from sphynx.paradigms.builtins import (
    BUILTIN_FACTORIES,
    barnes_maze,
    enriched_open_field,
    novel_object_recognition,
    open_field,
    register_builtin_paradigms,
    ty_maze,
)
from sphynx.paradigms.io import (
    load_paradigm,
    paradigm_from_dict,
    paradigm_to_dict,
    save_paradigm,
)
from sphynx.paradigms.model import CompositeSpec, MetricRef, Paradigm
from sphynx.paradigms.registry import (
    PARADIGMS,
    get_paradigm,
    register_paradigm,
    resolve_paradigm,
)
from sphynx.paradigms.validate import (
    ValidationIssue,
    ValidationReport,
    ValidationRule,
    validate_paradigm,
)

__all__ = [
    "Paradigm", "MetricRef", "CompositeSpec",
    "PARADIGMS", "register_paradigm", "get_paradigm", "resolve_paradigm",
    "ValidationRule", "ValidationIssue", "ValidationReport", "validate_paradigm",
    "open_field", "enriched_open_field", "novel_object_recognition",
    "barnes_maze", "ty_maze", "register_builtin_paradigms", "BUILTIN_FACTORIES",
    "paradigm_to_dict", "paradigm_from_dict", "save_paradigm", "load_paradigm",
]

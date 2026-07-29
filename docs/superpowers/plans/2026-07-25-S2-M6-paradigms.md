# S2 M6 — Paradigm hierarchy + validation-as-data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Paradigms as declarative bundles with inheritance (OF -> EOF -> NOR, plus Barnes
and a T/Y scaffold), validation rules that the engine RETURNS as data, and JSON save/load
for user-defined paradigms.

**Architecture:** Slice 6 of S2 (spec layers 6 and 7). A paradigm is DATA -- roles,
composites, act families, metric references, config defaults and validation rules -- not a
set of `if` branches. Inheritance merges parent into child by name, child wins.
`validate_paradigm` returns a `ValidationReport`; the engine never decides on the user's
behalf and never answers silently when the setup contradicts the paradigm.

**Tech Stack:** Python 3.11+; pytest. JSON via the stdlib.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- No silent fallbacks (§10): an unknown paradigm name, an unknown validation rule kind, a
  parent cycle, or a duplicate registration RAISE. A setup that violates a rule produces a
  reported issue -- never a silently wrong metric.
- ASCII only. TDD: failing test first.
- This REPLACES the minimal S1 `paradigms/of.py` bundle; `tests/unit/test_paradigm_of.py`
  is updated to the new shape as part of Task 3.
- Reuse existing types: `ZoneSelector` (M2), `ActFamily` (M4), `Act` (M3a). Do not
  re-declare parallel structures.

---

### Task 1: paradigm model + registry + inheritance

**Files:** Create `src/sphynx/paradigms/model.py`, `src/sphynx/paradigms/registry.py`; Test `tests/unit/test_paradigm_model.py`.
**Interfaces:**
- `MetricRef(name, params: dict)`; `CompositeSpec(name, selector: ZoneSelector)`.
- `Paradigm(name, parent=None, composites=[], families=[], acts=[], metrics=[], config_defaults={}, validation=[], doc="")`.
- `PARADIGMS: dict`; `register_paradigm(p, replace=False)`; `get_paradigm(name) -> Paradigm`.
- `resolve_paradigm(name_or_paradigm, registry=None) -> Paradigm` — parent chain merged, child wins, returns a new flattened `Paradigm` with `parent=None`.

- [ ] **Step 1: Failing test** — `tests/unit/test_paradigm_model.py`:
```python
import pytest

from sphynx.acts import Act, ActFamily
from sphynx.exceptions import SphynxValueError
from sphynx.paradigms.model import CompositeSpec, MetricRef, Paradigm
from sphynx.paradigms.registry import (
    PARADIGMS, get_paradigm, register_paradigm, resolve_paradigm,
)
from sphynx.zones import ZoneSelector


@pytest.fixture(autouse=True)
def _isolate():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


def _fam(name, zone_class):
    return ActFamily(name=name, selector=ZoneSelector(zone_class=zone_class),
                     template=Act(name="t", type="simple", body_part="nose"))


def test_register_and_get():
    p = Paradigm(name="Base")
    register_paradigm(p)
    assert get_paradigm("Base") is p


def test_unknown_paradigm_raises():
    with pytest.raises(SphynxValueError):
        get_paradigm("Nope")


def test_duplicate_registration_raises():
    register_paradigm(Paradigm(name="Dup"))
    with pytest.raises(SphynxValueError):
        register_paradigm(Paradigm(name="Dup"))


def test_duplicate_allowed_when_explicit():
    register_paradigm(Paradigm(name="Dup", doc="first"))
    register_paradigm(Paradigm(name="Dup", doc="second"), replace=True)
    assert get_paradigm("Dup").doc == "second"


def test_child_inherits_parent_content():
    register_paradigm(Paradigm(
        name="Base", metrics=[MetricRef("distance")],
        config_defaults={"velocity_rest": 1.0}, families=[_fam("f1", "object")]))
    register_paradigm(Paradigm(name="Child", parent="Base",
                               metrics=[MetricRef("ratio_index")]))
    r = resolve_paradigm("Child")
    assert r.name == "Child"
    assert r.parent is None                       # flattened
    assert [m.name for m in r.metrics] == ["distance", "ratio_index"]
    assert r.config_defaults == {"velocity_rest": 1.0}
    assert [f.name for f in r.families] == ["f1"]


def test_child_overrides_same_named_entries():
    register_paradigm(Paradigm(
        name="Base", metrics=[MetricRef("m", {"family": "parent_fam"})],
        config_defaults={"velocity_rest": 1.0, "keep": 2.0}))
    register_paradigm(Paradigm(
        name="Child", parent="Base",
        metrics=[MetricRef("m", {"family": "child_fam"})],
        config_defaults={"velocity_rest": 9.0}))
    r = resolve_paradigm("Child")
    assert len(r.metrics) == 1
    assert r.metrics[0].params == {"family": "child_fam"}
    assert r.config_defaults == {"velocity_rest": 9.0, "keep": 2.0}


def test_three_level_chain():
    register_paradigm(Paradigm(name="A", metrics=[MetricRef("a")]))
    register_paradigm(Paradigm(name="B", parent="A", metrics=[MetricRef("b")]))
    register_paradigm(Paradigm(name="C", parent="B", metrics=[MetricRef("c")]))
    r = resolve_paradigm("C")
    assert [m.name for m in r.metrics] == ["a", "b", "c"]


def test_composites_merge_by_name():
    register_paradigm(Paradigm(name="A", composites=[
        CompositeSpec("all_holes", ZoneSelector(zone_class="hole"))]))
    register_paradigm(Paradigm(name="B", parent="A", composites=[
        CompositeSpec("all_holes", ZoneSelector(zone_class="hole", is_target=False)),
        CompositeSpec("objects", ZoneSelector(zone_class="object"))]))
    r = resolve_paradigm("B")
    assert [c.name for c in r.composites] == ["all_holes", "objects"]
    assert r.composites[0].selector.is_target is False    # child won


def test_unknown_parent_raises():
    register_paradigm(Paradigm(name="Orphan", parent="Ghost"))
    with pytest.raises(SphynxValueError):
        resolve_paradigm("Orphan")


def test_parent_cycle_raises():
    register_paradigm(Paradigm(name="X", parent="Y"))
    register_paradigm(Paradigm(name="Y", parent="X"))
    with pytest.raises(SphynxValueError):
        resolve_paradigm("X")


def test_resolve_accepts_a_paradigm_object():
    register_paradigm(Paradigm(name="Base", metrics=[MetricRef("distance")]))
    r = resolve_paradigm(Paradigm(name="Ad hoc", parent="Base"))
    assert [m.name for m in r.metrics] == ["distance"]


def test_resolving_does_not_mutate_the_registered_paradigms():
    register_paradigm(Paradigm(name="Base", metrics=[MetricRef("a")]))
    register_paradigm(Paradigm(name="Child", parent="Base",
                               metrics=[MetricRef("b")]))
    resolve_paradigm("Child")
    assert [m.name for m in get_paradigm("Base").metrics] == ["a"]
    assert [m.name for m in get_paradigm("Child").metrics] == ["b"]
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3a: Implement the model.** `src/sphynx/paradigms/model.py`:
```python
"""Paradigm data model (S2 layer 6).

A paradigm is DATA: which zone roles it expects, which composites to build,
which act families and acts to evaluate, which named metrics to compute, its
config defaults, and the rules that decide whether a given preset satisfies it.
Behaviour lives in the engine; the paradigm only declares.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.zones import ZoneSelector


@dataclass
class MetricRef:
    """A named metric plus the parameters this paradigm calls it with."""

    name: str = ""
    params: dict = field(default_factory=dict)


@dataclass
class CompositeSpec:
    """A composite zone the paradigm wants built from the geometry."""

    name: str = ""
    selector: ZoneSelector = field(default_factory=ZoneSelector)


@dataclass
class Paradigm:
    name: str = ""
    parent: str | None = None
    composites: list = field(default_factory=list)      # CompositeSpec
    families: list = field(default_factory=list)        # ActFamily
    acts: list = field(default_factory=list)            # Act
    metrics: list = field(default_factory=list)         # MetricRef
    config_defaults: dict = field(default_factory=dict)
    validation: list = field(default_factory=list)      # ValidationRule
    doc: str = ""
```
- [ ] **Step 3b: Implement the registry.** `src/sphynx/paradigms/registry.py`:
```python
"""Paradigm registry + inheritance resolution (S2 layer 6)."""

from __future__ import annotations

import copy

from sphynx.exceptions import SphynxValueError
from sphynx.paradigms.model import Paradigm

PARADIGMS: dict = {}


def register_paradigm(paradigm: Paradigm, replace: bool = False) -> Paradigm:
    if not paradigm.name:
        raise SphynxValueError("paradigm needs a name")
    if paradigm.name in PARADIGMS and not replace:
        raise SphynxValueError(
            f'paradigm "{paradigm.name}" is already registered; pass '
            "replace=True to override it deliberately")
    PARADIGMS[paradigm.name] = paradigm
    return paradigm


def get_paradigm(name) -> Paradigm:
    p = PARADIGMS.get(name)
    if p is None:
        raise SphynxValueError(
            f'unknown paradigm "{name}"; known: {sorted(PARADIGMS)}')
    return p


def _merge_by_name(base, child, key=lambda item: item.name):
    """Child entries override same-named parent entries; order is parent-first,
    then any genuinely new child entries."""
    out = [copy.deepcopy(item) for item in base]
    index = {key(item): i for i, item in enumerate(out)}
    for item in child:
        k = key(item)
        if k in index:
            out[index[k]] = copy.deepcopy(item)
        else:
            index[k] = len(out)
            out.append(copy.deepcopy(item))
    return out


def _chain(paradigm: Paradigm) -> list:
    """Ancestors root-first, ending with `paradigm` itself."""
    chain = [paradigm]
    seen = {paradigm.name}
    current = paradigm
    while current.parent is not None:
        parent = PARADIGMS.get(current.parent)
        if parent is None:
            raise SphynxValueError(
                f'paradigm "{current.name}" has unknown parent '
                f'"{current.parent}"')
        if parent.name in seen:
            raise SphynxValueError(
                f'paradigm parent cycle at "{parent.name}" '
                f"(chain: {[p.name for p in chain]})")
        seen.add(parent.name)
        chain.append(parent)
        current = parent
    chain.reverse()
    return chain


def resolve_paradigm(name_or_paradigm, registry=None) -> Paradigm:
    """Flatten a paradigm against its ancestors. Returns a NEW Paradigm; the
    registered ones are never mutated."""
    paradigm = (name_or_paradigm if isinstance(name_or_paradigm, Paradigm)
                else get_paradigm(name_or_paradigm))
    chain = _chain(paradigm)

    merged = Paradigm(name=paradigm.name, doc=paradigm.doc)
    for link in chain:
        merged.composites = _merge_by_name(merged.composites, link.composites)
        merged.families = _merge_by_name(merged.families, link.families)
        merged.acts = _merge_by_name(merged.acts, link.acts)
        merged.metrics = _merge_by_name(merged.metrics, link.metrics)
        merged.validation = _merge_by_name(
            merged.validation, link.validation, key=lambda r: r.code)
        merged.config_defaults = {**merged.config_defaults,
                                  **copy.deepcopy(link.config_defaults)}
    return merged
```
- [ ] **Step 4: Run — PASS** (12 passed), then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/paradigms/model.py src/sphynx/paradigms/registry.py tests/unit/test_paradigm_model.py && git commit -m "feat(python): S2 M6 -- paradigm model + registry + inheritance"`

---

### Task 2: validation as data

**Files:** Create `src/sphynx/paradigms/validate.py`; Test `tests/unit/test_paradigm_validation.py`.
**Interfaces:**
- `ValidationRule(code, kind, zone_class="", min=None, max=None, level="error", message="")`
  with `kind` in `zone_count | target_count | calibration`.
- `ValidationIssue(code, level, message, where="")`.
- `ValidationReport(paradigm="", issues=[])` with `.ok`, `.errors`, `.warnings`.
- `validate_paradigm(paradigm, zones, options=None) -> ValidationReport`.

- [ ] **Step 1: Failing test** — `tests/unit/test_paradigm_validation.py`:
```python
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.paradigms.model import Paradigm
from sphynx.paradigms.validate import (
    ValidationReport, ValidationRule, validate_paradigm,
)
from sphynx.zones import Zone, ZoneRoles

import numpy as np


def _m():
    a = np.zeros((6, 6), dtype=bool)
    a[1:3, 1:3] = True
    return a


def _zones(n_objects=0, n_targets=0, n_holes=0):
    zs = [Zone("arena", "area", _m(), zone_class="arena")]
    for i in range(n_objects):
        zs.append(Zone(f"obj{i}", "area", _m(), zone_class="object"))
    for i in range(n_holes):
        zs.append(Zone(f"hole{i}", "area", _m(), zone_class="hole"))
    for i in range(n_targets):
        zs.append(Zone(f"target{i}", "area", _m(), zone_class="hole",
                       roles=ZoneRoles(is_target=True)))
    return zs


class _Options:
    def __init__(self, pxl2sm=22.2):
        self.pxl2sm = pxl2sm


def _paradigm(*rules):
    return Paradigm(name="Test", validation=list(rules))


OBJECT_MIN1 = ValidationRule(code="needs_object", kind="zone_count",
                             zone_class="object", min=1,
                             message="this paradigm needs at least one object")
OBJECT_EXACT2 = ValidationRule(code="needs_two_objects", kind="zone_count",
                               zone_class="object", min=2, max=2)
ONE_TARGET = ValidationRule(code="needs_one_target", kind="target_count",
                            min=1, max=1)
CALIBRATED = ValidationRule(code="needs_calibration", kind="calibration")


def test_clean_setup_is_ok():
    report = validate_paradigm(_paradigm(OBJECT_MIN1), _zones(n_objects=1),
                               _Options())
    assert isinstance(report, ValidationReport)
    assert report.ok is True
    assert report.issues == []


def test_missing_object_is_reported_not_raised():
    report = validate_paradigm(_paradigm(OBJECT_MIN1), _zones(n_objects=0))
    assert report.ok is False
    assert [i.code for i in report.errors] == ["needs_object"]
    assert "at least one object" in report.errors[0].message


def test_exact_count_rule_flags_too_many():
    report = validate_paradigm(_paradigm(OBJECT_EXACT2), _zones(n_objects=3))
    assert report.ok is False
    assert report.errors[0].code == "needs_two_objects"


def test_exact_count_rule_accepts_the_right_number():
    assert validate_paradigm(_paradigm(OBJECT_EXACT2), _zones(n_objects=2)).ok


def test_target_rule_requires_exactly_one():
    assert validate_paradigm(_paradigm(ONE_TARGET), _zones(n_targets=1)).ok
    assert not validate_paradigm(_paradigm(ONE_TARGET), _zones(n_targets=0)).ok
    assert not validate_paradigm(_paradigm(ONE_TARGET), _zones(n_targets=2)).ok


def test_calibration_rule():
    assert validate_paradigm(_paradigm(CALIBRATED), _zones(), _Options()).ok
    assert not validate_paradigm(_paradigm(CALIBRATED), _zones(), None).ok
    assert not validate_paradigm(_paradigm(CALIBRATED), _zones(),
                                 _Options(pxl2sm=0)).ok


def test_warning_level_does_not_fail_the_report():
    rule = ValidationRule(code="soft", kind="zone_count", zone_class="object",
                          min=1, level="warning")
    report = validate_paradigm(_paradigm(rule), _zones(n_objects=0))
    assert report.ok is True
    assert [i.code for i in report.warnings] == ["soft"]


def test_several_rules_all_reported():
    report = validate_paradigm(_paradigm(OBJECT_MIN1, ONE_TARGET, CALIBRATED),
                               _zones(), None)
    assert len(report.errors) == 3


def test_report_names_the_paradigm():
    report = validate_paradigm(_paradigm(OBJECT_MIN1), _zones())
    assert report.paradigm == "Test"


def test_unknown_rule_kind_raises():
    bad = ValidationRule(code="weird", kind="teleportation")
    with pytest.raises(SphynxValueError):
        validate_paradigm(_paradigm(bad), _zones())


def test_default_message_is_informative_when_none_given():
    rule = ValidationRule(code="c", kind="zone_count", zone_class="object", min=2)
    report = validate_paradigm(_paradigm(rule), _zones(n_objects=1))
    msg = report.errors[0].message
    assert "object" in msg and "2" in msg and "1" in msg


def test_paradigm_without_rules_is_ok():
    assert validate_paradigm(Paradigm(name="Free"), _zones()).ok
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/paradigms/validate.py`:
```python
"""Validation as data (S2 layer 7).

Rules are declared by the paradigm and checked here. The engine RETURNS a
report; it never decides for the user and never answers silently when the
preset contradicts the paradigm. The GUI renders the report (S4).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.exceptions import SphynxValueError

_KINDS = ("zone_count", "target_count", "calibration")


@dataclass
class ValidationRule:
    code: str = ""
    kind: str = ""
    zone_class: str = ""
    min: int | None = None
    max: int | None = None
    level: str = "error"          # error | warning
    message: str = ""


@dataclass
class ValidationIssue:
    code: str = ""
    level: str = "error"
    message: str = ""
    where: str = ""


@dataclass
class ValidationReport:
    paradigm: str = ""
    issues: list = field(default_factory=list)

    @property
    def errors(self) -> list:
        return [i for i in self.issues if i.level == "error"]

    @property
    def warnings(self) -> list:
        return [i for i in self.issues if i.level == "warning"]

    @property
    def ok(self) -> bool:
        return not self.errors


def _count_in_range(n, rule) -> bool:
    if rule.min is not None and n < rule.min:
        return False
    if rule.max is not None and n > rule.max:
        return False
    return True


def _expected(rule) -> str:
    if rule.min is not None and rule.max is not None:
        return (f"exactly {rule.min}" if rule.min == rule.max
                else f"between {rule.min} and {rule.max}")
    if rule.min is not None:
        return f"at least {rule.min}"
    if rule.max is not None:
        return f"at most {rule.max}"
    return "any number"


def _issue(rule, message, where="") -> ValidationIssue:
    return ValidationIssue(code=rule.code, level=rule.level,
                           message=rule.message or message, where=where)


def validate_paradigm(paradigm, zones, options=None) -> ValidationReport:
    """Check a preset against a paradigm's declared rules."""
    report = ValidationReport(paradigm=paradigm.name)
    zones = list(zones or [])

    for rule in paradigm.validation:
        if rule.kind not in _KINDS:
            raise SphynxValueError(
                f'validation rule "{rule.code}": unknown kind "{rule.kind}"; '
                f"known: {list(_KINDS)}")

        if rule.kind == "zone_count":
            n = sum(1 for z in zones if z.zone_class == rule.zone_class)
            if not _count_in_range(n, rule):
                report.issues.append(_issue(
                    rule,
                    f'needs {_expected(rule)} zone(s) of class '
                    f'"{rule.zone_class}"; the preset has {n}',
                    where=rule.zone_class))

        elif rule.kind == "target_count":
            n = sum(1 for z in zones
                    if getattr(getattr(z, "roles", None), "is_target", False))
            if not _count_in_range(n, rule):
                report.issues.append(_issue(
                    rule,
                    f"needs {_expected(rule)} zone(s) marked as the target; "
                    f"the preset has {n}",
                    where="roles.is_target"))

        elif rule.kind == "calibration":
            pxl = getattr(options, "pxl2sm", None) if options is not None else None
            valid = isinstance(pxl, (int, float)) and not isinstance(pxl, bool) \
                and pxl > 0
            if not valid:
                report.issues.append(_issue(
                    rule,
                    "pixels-per-cm is not set, so distances and speeds would "
                    f"be meaningless (got {pxl!r})",
                    where="Options.pxl2sm"))

    return report
```
- [ ] **Step 4: Run — PASS** (12 passed), then full suite.
- [ ] **Step 5: Commit** `git add src/sphynx/paradigms/validate.py tests/unit/test_paradigm_validation.py && git commit -m "feat(python): S2 M6 -- validation as data (ValidationReport)"`

---

### Task 3: built-in paradigms + JSON save/load

**Files:** Create `src/sphynx/paradigms/builtins.py`, `src/sphynx/paradigms/io.py`; Delete `src/sphynx/paradigms/of.py`; Modify `src/sphynx/paradigms/__init__.py`; Update `tests/unit/test_paradigm_of.py`; Test `tests/unit/test_paradigm_builtins.py`, `tests/unit/test_paradigm_io.py`.
**Interfaces:** `open_field()`, `enriched_open_field()`, `novel_object_recognition()`,
`barnes_maze()`, `ty_maze()` (scaffold; choice metrics deferred), `register_builtin_paradigms()`;
`paradigm_to_dict(p) -> dict`, `paradigm_from_dict(d) -> Paradigm`, `save_paradigm(p, path)`,
`load_paradigm(path) -> Paradigm`.

> **NOTE for the controller:** this task wires M1..M5 together (selectors, families,
> metric refs, validation) and removes the S1 stub. Build it in the main loop.

- [ ] **Step 1: Failing tests** — `tests/unit/test_paradigm_builtins.py` covering: OF has
  calibration validation and speed config defaults; EOF inherits OF and requires >=1 object;
  NOR inherits EOF and requires exactly 2; Barnes requires exactly one target and declares
  the `nose_at_hole` family plus visit_order/latency_to_target/primary_errors metric refs
  with the family parameter; the T/Y scaffold registers and documents its deferred choice
  metrics; every built-in resolves without error; a validation run against a matching and a
  mismatching preset behaves as declared. And `tests/unit/test_paradigm_io.py` covering
  round-trip of a user paradigm through dict and through a JSON file (selector, family
  template, metric params, validation rules and config defaults all survive), plus a clear
  error for a malformed file.
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** the built-ins and the JSON codec; update
  `src/sphynx/paradigms/__init__.py` to export the new API; update
  `tests/unit/test_paradigm_of.py` to the new `Paradigm` shape (it asserted the S1 stub's
  `builtin_acts`/`metrics` string lists).
- [ ] **Step 4: Run — PASS**, then full suite.
- [ ] **Step 5: Commit** `git add -A src/sphynx/paradigms tests/unit/test_paradigm_builtins.py tests/unit/test_paradigm_io.py tests/unit/test_paradigm_of.py && git commit -m "feat(python): S2 M6 -- built-in paradigm hierarchy + JSON save/load"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (M5 431 + M6 new).
- OF -> EOF -> NOR inherit; Barnes and the T/Y scaffold register; a user paradigm
  round-trips through JSON; `validate_paradigm` reports EOF-without-object,
  NOR-not-two, Barnes-without-target and missing calibration as data.

## Next plan
- **M7:** Barnes metrics over the family EventStream and geometry (latency, errors, path
  length, angular distance, ordinal index, search strategy, time near target). Then the
  M6+M7 boundary review (opus).

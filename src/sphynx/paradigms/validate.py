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
    # `zones` may be the numpy object array scipy hands back from a preset .mat,
    # whose truthiness is ambiguous -- test for None explicitly.
    zones = [] if zones is None else list(zones)

    for rule in paradigm.validation:
        if rule.kind not in _KINDS:
            raise SphynxValueError(
                f'validation rule "{rule.code}": unknown kind "{rule.kind}"; '
                f"known: {list(_KINDS)}")
        if rule.kind in ("zone_count", "target_count") \
                and rule.min is None and rule.max is None:
            # A count rule with no bounds can never fire; that is an authoring
            # bug, and reporting "ok" would hide it.
            raise SphynxValueError(
                f'validation rule "{rule.code}": a {rule.kind} rule needs a '
                "min and/or a max")

        if rule.kind == "zone_count":
            n = sum(1 for z in zones
                    if getattr(z, "zone_class", None) == rule.zone_class)
            if not _count_in_range(n, rule):
                report.issues.append(_issue(
                    rule,
                    f'needs {_expected(rule)} zone(s) of class '
                    f'"{rule.zone_class}"; the preset has {n}',
                    where=rule.zone_class))

        elif rule.kind == "target_count":
            # One target OBJECT is several zones (footprint, ring, area), so a
            # rule that means "one target hole" must scope itself to the class
            # that carries the footprint, exactly as zone_count does. A rule
            # that declares no class keeps counting every target zone.
            n = sum(1 for z in zones
                    if getattr(getattr(z, "roles", None), "is_target", False)
                    and (not rule.zone_class
                         or getattr(z, "zone_class", None) == rule.zone_class))
            if not _count_in_range(n, rule):
                of_class = (f' of class "{rule.zone_class}"'
                            if rule.zone_class else "")
                report.issues.append(_issue(
                    rule,
                    f"needs {_expected(rule)} zone(s){of_class} marked as the "
                    f"target; the preset has {n}",
                    where=rule.zone_class or "roles.is_target"))

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

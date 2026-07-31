"""Built-in paradigm hierarchy (S2 layer 6).

Each paradigm is a declarative bundle: which composites to build from the
geometry, which act families to expand, which named metrics to compute, its
config defaults, and the rules a preset must satisfy. Behaviour lives in the
engine -- there is no `if paradigm == "Barnes"` anywhere.

    OF ---> EOF ---> NOR
     |
     +----> Barnes
     +----> TYMaze (scaffold: choice/decision metrics are deferred)
"""

from __future__ import annotations

from sphynx.acts import Act, ActFamily
from sphynx.paradigms.model import CompositeSpec, MetricRef, Paradigm
from sphynx.paradigms.registry import register_paradigm
from sphynx.paradigms.validate import ValidationRule
from sphynx.zones import ZoneSelector

# --- shared rules ---------------------------------------------------------

CALIBRATION_RULE = ValidationRule(
    code="needs_calibration", kind="calibration",
    message="pixels-per-cm is not set, so distances and speeds would be "
            "meaningless")


def _nose_template(name: str) -> Act:
    """A simple nose-in-zone act; the family rebinds `zones` per member."""
    return Act(name=name, type="simple", body_part="nose",
               required_parts=["nose"], min_duration_sec=0.25, max_gap_sec=0.25)


# --- OF -------------------------------------------------------------------

def open_field() -> Paradigm:
    """Empty arena of any shape, no objects. Speed acts, freezing and rears
    come from the built-in act path; only calibration is mandatory."""
    return Paradigm(
        name="OF",
        config_defaults={
            "velocity_rest": 1.0,
            "velocity_locomotion": 5.0,
            "min_run_seconds": 0.25,
        },
        metrics=[
            MetricRef("path_length"),
            MetricRef("mean_speed"),
        ],
        validation=[CALIBRATION_RULE],
        doc="Open Field: empty arena, no objects.",
    )


# --- EOF ------------------------------------------------------------------

def enriched_open_field() -> Paradigm:
    """Enriched Open Field: OF plus at least one object.

    Declares two object families: nose exploration and the animal being inside
    the object footprint.

    Two EOF items from the design are deliberately NOT declared here, rather
    than declared wrongly:

    * ring exploration ("nose in the ring EXCLUDING time inside the object")
      needs ring zones, which the preset builder derives from each object
      (MATLAB buildObjectZones.m). Once a preset carries `object_ring` zones a
      family over that class plus an Exclude expression expresses it -- but a
      family template may not be a complex act (see acts.families), so this
      waits for the composite-act binding pass.
    * a discrimination index is `ratio_index` over the TWO object acts the
      experimenter chose as novel and familiar. Which two is a per-session
      decision, so a paradigm cannot fix it; the GUI supplies the pair. Adding
      MetricRef("ratio_index", {...}) with guessed act names here would be a
      plausible wrong answer.
    """
    return Paradigm(
        name="EOF", parent="OF",
        composites=[CompositeSpec("all_objects", ZoneSelector(zone_class="object"))],
        families=[
            ActFamily(
                name="nose_at_object",
                selector=ZoneSelector(zone_class="object"),
                template=_nose_template("nose_at_object"),
            ),
            ActFamily(
                name="inside_object",
                selector=ZoneSelector(zone_class="object"),
                template=Act(name="inside_object", type="simple",
                             body_part="bodycenter", required_parts=["bodycenter"],
                             min_duration_sec=0.25, max_gap_sec=0.25),
            ),
        ],
        validation=[ValidationRule(
            code="needs_object", kind="zone_count", zone_class="object", min=1,
            message="an enriched open field needs at least one object")],
        doc="Enriched Open Field: arena with one or more objects.",
    )


# --- NOR ------------------------------------------------------------------

def novel_object_recognition() -> Paradigm:
    """Novel Object Recognition: EOF with exactly two objects."""
    return Paradigm(
        name="NOR", parent="EOF",
        validation=[ValidationRule(
            code="needs_object", kind="zone_count", zone_class="object",
            min=2, max=2,
            message="novel object recognition needs exactly two objects")],
        doc="Novel Object Recognition: exactly two objects (novel/familiar).",
    )


# --- Barnes ---------------------------------------------------------------

def barnes_maze() -> Paradigm:
    """Barnes maze: a ring of holes, exactly one marked as the target. The
    family expands over the holes that actually exist, and the order/error
    metrics are generic queries over its merged event stream."""
    family = "nose_at_hole"
    entry = "inside_hole"
    return Paradigm(
        name="Barnes", parent="OF",
        composites=[
            CompositeSpec("all_holes", ZoneSelector(zone_class="hole")),
            CompositeSpec("neutral_holes",
                          ZoneSelector(zone_class="hole", is_target=False)),
        ],
        families=[
            ActFamily(
                name=family,
                selector=ZoneSelector(zone_class="hole"),
                template=_nose_template(family),
            ),
            # The entry family: the animal itself inside the hole, which is what
            # total latency is measured against (a nose check is not an entry).
            ActFamily(
                name=entry,
                selector=ZoneSelector(zone_class="hole"),
                template=Act(name=entry, type="simple", body_part="bodycenter",
                             required_parts=["bodycenter"],
                             min_duration_sec=0.25, max_gap_sec=0.25),
            ),
        ],
        metrics=[
            # generic (M5)
            MetricRef("visit_order", {"family": family}),
            MetricRef("latency_to_target", {"family": family},
                      as_="primary_latency"),
            MetricRef("primary_errors", {"family": family}),
            MetricRef("time_to_completion", {"family": family}),
            # Barnes-specific (M7)
            MetricRef("total_latency", {"family": entry}),
            MetricRef("total_errors", {"family": family}),
            MetricRef("target_checks", {"family": family}),
            MetricRef("non_target_checks", {"family": family}),
            MetricRef("time_near_target", {"family": family}),
            MetricRef("target_ordinal", {"family": family}),
            MetricRef("angular_distance_first", {"family": family}),
            MetricRef("mean_angular_distance", {"family": family}),
            MetricRef("path_length", {}),
            MetricRef("path_length_to_target", {"family": family}),
            MetricRef("search_strategy", {"family": family}),
        ],
        validation=[
            ValidationRule(
                code="needs_holes", kind="zone_count", zone_class="hole", min=2,
                message="a Barnes maze needs its holes marked as zones"),
            ValidationRule(
                code="needs_one_target", kind="target_count", min=1, max=1,
                message="exactly one hole must be marked as the target"),
        ],
        doc="Barnes maze: hole ring with one target hole.",
    )


# --- T/Y maze (scaffold) --------------------------------------------------

def ty_maze() -> Paradigm:
    """T/Y maze SCAFFOLD. The geometry and arm family are declared so a session
    can already be analysed for occupancy and speed, but the choice/decision
    metrics (alternation, first-arm choice, decision latency) are deliberately
    DEFERRED -- they were left open in the S2 brainstorm and get their own
    design pass."""
    return Paradigm(
        name="TYMaze", parent="OF",
        composites=[CompositeSpec("all_arms", ZoneSelector(zone_class="arm"))],
        families=[ActFamily(
            name="in_arm",
            selector=ZoneSelector(zone_class="arm"),
            template=Act(name="in_arm", type="simple", body_part="bodycenter",
                         required_parts=["bodycenter"],
                         min_duration_sec=0.25, max_gap_sec=0.25),
        )],
        validation=[ValidationRule(
            code="needs_arms", kind="zone_count", zone_class="arm", min=2,
            message="a T/Y maze needs its arms marked as zones")],
        doc="T/Y maze (scaffold; choice metrics deferred to their own design).",
    )


BUILTIN_FACTORIES = (
    open_field, enriched_open_field, novel_object_recognition,
    barnes_maze, ty_maze,
)


def register_builtin_paradigms(replace: bool = False) -> dict:
    """Register every built-in paradigm. Returns {name: Paradigm}."""
    out = {}
    for factory in BUILTIN_FACTORIES:
        paradigm = factory()
        register_paradigm(paradigm, replace=replace)
        out[paradigm.name] = paradigm
    return out

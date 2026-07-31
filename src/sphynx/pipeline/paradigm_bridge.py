"""Compute a paradigm's composites, act families and named metrics onto a
session result (S2 -> S4 bridge).

The engine stays honest here: a composite or family that cannot be built lands
in the validation report as an issue, and a metric that cannot be computed lands
in MetricResults.errors. Nothing is quietly skipped, and the caller (GUI or CLI)
renders the report.
"""

from __future__ import annotations

import numpy as np

from sphynx.acts.apply import eval_acts_library
from sphynx.acts.families import expand_family, family_event_stream
from sphynx.acts.schema import ActContext
from sphynx.acts.stats import act_stats
from sphynx.exceptions import SphynxError
from sphynx.logging_setup import get_logger
from sphynx.metrics.registry import MetricContext, compute_metric_refs
from sphynx.paradigms.registry import lineage, resolve_paradigm
from sphynx.paradigms.validate import ValidationIssue, validate_paradigm
from sphynx.zones.select import make_composite

_log = get_logger()


def _issue(report, code, message, where=""):
    report.issues.append(
        ValidationIssue(code=code, level="error", message=message, where=where))


def _opt(options, name, default):
    value = getattr(options, name, None) if options is not None else None
    return default if value is None else value


def _build_composites(resolved, zones, report):
    for spec in resolved.composites:
        try:
            zones.append(make_composite(spec.name, zones, spec.selector))
        except SphynxError as e:
            _issue(report, "composite_failed",
                   f'composite "{spec.name}" could not be built: {e}',
                   where=spec.name)


def _expand_families(resolved, zones, report):
    concrete = []
    for family in resolved.families:
        try:
            concrete.extend(expand_family(family, zones))
        except SphynxError as e:
            _issue(report, "family_failed",
                   f'act family "{family.name}" could not be expanded: {e}',
                   where=family.name)
    return concrete


def _act_context(result, zones, frame_rate):
    traces = result.body_parts_traces
    bpx = np.array([t.x_smooth for t in traces], dtype=float)
    bpy = np.array([t.y_smooth for t in traces], dtype=float)
    bpv = np.array(
        [t.velocity if t.velocity is not None else np.zeros(result.n_frames)
         for t in traces], dtype=float)
    x_kcorr = float(_opt(result.options, "x_kcorr", 1.0) or 1.0)
    return ActContext(
        X=bpx, Y=bpy, velocity_cm_s=bpv,
        body_parts=list(result.body_parts_names), zones=zones,
        frame_rate=frame_rate,
        pixels_per_cm=float(_opt(result.options, "pxl2sm", 1.0)),
        x_kcorr=x_kcorr if x_kcorr > 0 else 1.0,
    )


def _trajectory_cm(result, pixels_per_cm):
    """Centre trace in CENTIMETRES -- traces are stored in pixels."""
    index = result.point.center
    if index is None or index >= len(result.body_parts_traces):
        return None
    trace = result.body_parts_traces[index]
    if not pixels_per_cm > 0:
        return None
    return (np.asarray(trace.x_smooth, dtype=float) / pixels_per_cm,
            np.asarray(trace.y_smooth, dtype=float) / pixels_per_cm)


def apply_paradigm(result, paradigm, registry=None) -> None:
    """Run a paradigm over an already-analysed session, in place."""
    from sphynx.pipeline.analyze import SessionAct

    resolved = resolve_paradigm(paradigm, registry)
    result.paradigm = resolved.name
    result.paradigm_defaults = dict(resolved.config_defaults)

    zones = [] if result.zones is None else list(result.zones)
    report = validate_paradigm(resolved, zones, result.options)
    result.validation = report

    frame_rate = float(_opt(result.options, "FrameRate", 30.0))

    _build_composites(resolved, zones, report)
    concrete = _expand_families(resolved, zones, report)

    masks = {}
    if concrete:
        ctx = _act_context(result, zones, frame_rate)
        masks = eval_acts_library(concrete, ctx)
        result.degraded = dict(ctx.degraded)

        centre = result.point.center
        velocity = None
        if centre is not None and centre < len(result.body_parts_traces):
            velocity = result.body_parts_traces[centre].velocity
        for act in concrete:
            mask = masks.get(act.name)
            if mask is None:
                continue
            result.acts.append(SessionAct(
                name=act.name, array=np.asarray(mask, dtype=float),
                category="family",
                stats=act_stats(mask, frame_rate, velocity=velocity)))

        for family in resolved.families:
            members = [a for a in concrete if a.family == family.name]
            if members:
                result.event_streams[family.name] = family_event_stream(
                    members, masks, frame_rate, family=family.name)

    if resolved.metrics:
        pixels_per_cm = float(_opt(result.options, "pxl2sm", 0.0))
        metric_ctx = MetricContext(
            acts={a.name: a.array for a in result.acts},
            stats={a.name: a.stats for a in result.acts if a.stats is not None},
            events=dict(result.event_streams), act_defs=concrete, zones=zones,
            degraded=dict(result.degraded),
            trajectory_cm=_trajectory_cm(result, pixels_per_cm),
            frame_rate=frame_rate,
        )
        try:
            para_lineage = lineage(paradigm, registry)
        except SphynxError:
            para_lineage = (resolved.name,)
        result.metrics = compute_metric_refs(
            resolved.metrics, metric_ctx, paradigm=para_lineage)

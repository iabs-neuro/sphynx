"""Evaluate one act on a session's data. Port of sphynx.acts.applyAct +
evalActsLibrary."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import median_filter

from sphynx.acts.expr import eval_expr, from_flat
from sphynx.acts.part_resolution import resolve_act_parts
from sphynx.acts.rear_threshold import auto_rear_threshold_cm
from sphynx.acts.refine import refine_act_array
from sphynx.acts.schema import Act, ActContext
from sphynx.bodyparts import resolve_part
from sphynx.exceptions import SphynxValueError
from sphynx.geom import hypot_kcorr
from sphynx.logging_setup import get_logger
from sphynx.util.smoothing import smooth_derived

_log = get_logger()


def _mark(ctx, act, reason):
    """Record (and log) why an act could not be evaluated as declared.

    An act that silently returns all-false is indistinguishable from an act
    that genuinely never fired -- the R31#4 defect class. Every degradation
    goes on the record instead (section 10)."""
    reasons = ctx.degraded.setdefault(act.name, [])
    if reason in reasons:
        return          # an act referenced twice degrades once
    reasons.append(reason)
    _log.warning('Act "%s" degraded: %s', act.name, reason)


def _resolve_act_part(act, ctx, name):
    """Resolve one body part through the act's declared fallback chain,
    recording any substitution or miss on the context. Returns an index or None."""
    res = resolve_act_parts([name], ctx.body_parts, fallback=act.fallback)
    if name in res.missing:
        _mark(ctx, act, f'body part "{name}" not found and no fallback resolved')
        return None
    if name in res.substitutions:
        _mark(ctx, act,
              f'body part "{name}" substituted by "{res.substitutions[name]}"')
    return res.indices.get(name)


def _find_zone(zones, name):
    for i, z in enumerate(zones):
        if z.name == name:
            return i
    return None


def _points_in_mask(xs, ys, mask):
    h, w = mask.shape
    xi = np.round(xs)
    yi = np.round(ys)
    valid = np.isfinite(xi) & np.isfinite(yi) & (xi >= 1) & (xi <= w) & (yi >= 1) & (yi <= h)
    out = np.zeros(xs.shape[0] if xs.ndim else np.size(xs), dtype=bool)
    if valid.any():
        vy = yi[valid].astype(int) - 1
        vx = xi[valid].astype(int) - 1
        out[valid] = mask[vy, vx]
    return out


def _check_required_parts(act, ctx) -> bool:
    """Resolve the act's declared required_parts up front. Returns False when a
    requirement cannot be met, so the caller yields an honestly-empty act."""
    if not act.required_parts:
        return True
    res = resolve_act_parts(act.required_parts, ctx.body_parts, fallback=act.fallback)
    for nm, sub in res.substitutions.items():
        _mark(ctx, act, f'required part "{nm}" substituted by "{sub}"')
    for nm in res.missing:
        _mark(ctx, act, f'required part "{nm}" not found and no fallback resolved')
    return res.ok


def apply_act(act: Act, ctx: ActContext) -> np.ndarray:
    n_frames = ctx.X.shape[1]
    if not _check_required_parts(act, ctx):
        return np.zeros(n_frames, dtype=bool)
    t = act.type.lower()
    if t == "simple":
        b = _apply_simple(act, ctx, n_frames)
    elif t == "complex":
        b = _apply_complex(act, ctx, n_frames)
    elif t == "special":
        b = _apply_special(act, ctx, n_frames)
    else:
        _mark(ctx, act, f'unknown act type "{act.type}"')
        b = np.zeros(n_frames, dtype=bool)

    win = int(round(act.median_window_sec * ctx.frame_rate))
    if win >= 3:
        if win % 2 == 0:
            win += 1
        b = median_filter(b.astype(np.uint8), size=win, mode="nearest") > 0

    dur_sec = max(0.0, act.min_duration_sec)
    gap_sec = max(0.0, act.max_gap_sec)
    min_run = round(dur_sec * ctx.frame_rate)
    max_bridge = round(gap_sec * ctx.frame_rate)
    if min_run > 0 or max_bridge > 0:
        b = refine_act_array(b, min_run, max_bridge)
    return b


def _apply_simple(act, ctx, n):
    part = _resolve_act_part(act, ctx, act.body_part)
    if part is None:
        return np.zeros(n, dtype=bool)
    v = ctx.velocity_cm_s[part, :]
    speed_ok = (v >= act.speed_min) & (v <= act.speed_max)
    return speed_ok & _in_any_zone(act, ctx, part, n)


def _in_any_zone(act, ctx, part, n):
    if not act.zones:
        return np.ones(n, dtype=bool)
    masks = np.zeros((len(act.zones), n), dtype=bool)
    for k, zname in enumerate(act.zones):
        zi = _find_zone(ctx.zones, zname)
        if zi is None:
            _mark(ctx, act, f'zone "{zname}" not found in the preset')
            continue
        zm = ctx.zones[zi].maskfilled
        zm = zm if zm.dtype == bool else (zm > 0)
        masks[k, :] = _points_in_mask(ctx.X[part, :], ctx.Y[part, :], zm)
    op = act.zone_op.upper()
    if op == "AND":
        return masks.all(axis=0)
    if op == "EXCLUDE":
        return masks[0, :] & ~masks[1:, :].any(axis=0)
    return masks.any(axis=0)


def _resolve_ref(ctx, owner, name):
    """Resolve one act reference to a per-frame mask, or None if unknown.

    Precomputed results win; otherwise the referenced act is evaluated
    recursively and memoised, so a shared sub-act costs one evaluation. A
    reference cycle raises rather than recursing forever. A degraded referent
    also degrades the act that references it -- otherwise a composed act comes
    back empty with a clean record of its own."""
    if name in ctx.results_by_name:
        mask = ctx.results_by_name[name]
    else:
        ref = next((a for a in ctx.all_acts if a.name == name), None)
        if ref is None:
            return None
        if name in ctx.evaluating:
            raise SphynxValueError(
                f'act reference cycle detected at "{name}" '
                f"(in flight: {sorted(ctx.evaluating)})")
        ctx.evaluating.add(name)
        try:
            mask = apply_act(ref, ctx)
        finally:
            ctx.evaluating.discard(name)
        ctx.results_by_name[name] = mask

    if name != owner.name and ctx.degraded.get(name):
        _mark(ctx, owner, f'referenced act "{name}" is degraded')
    return mask


def _apply_complex(act, ctx, n):
    # One evaluation path: an explicit tree wins, a flat act is migrated.
    expr = act.expr
    if expr is None:
        if not act.components:
            _mark(ctx, act, "complex act declares no components")
            return np.zeros(n, dtype=bool)
        expr = from_flat(act)
        if expr is None:
            _mark(ctx, act, f'unknown complex operation "{act.operation}"')
            return np.zeros(n, dtype=bool)
    return eval_expr(
        expr, n,
        lambda nm: _resolve_ref(ctx, act, nm),
        ctx.frame_rate,
        lambda reason: _mark(ctx, act, reason),
    )


def _apply_special(act, ctx, n):
    kind = act.special_kind.lower()
    if kind == "freezing":
        return _apply_freezing(act, ctx, n)
    if kind == "rears":
        return _apply_rears(act, ctx, n)
    if kind == "allinzone":
        return _apply_all_in_zone(act, ctx, n)
    _mark(ctx, act, f'unknown special kind "{act.special_kind}"')
    return np.zeros(n, dtype=bool)


def _apply_all_in_zone(act, ctx, n):
    if not act.zones or not act.body_parts:
        _mark(ctx, act, "allinzone act declares no zone or no body parts")
        return np.zeros(n, dtype=bool)
    zi = _find_zone(ctx.zones, act.zones[0])
    if zi is None:
        _mark(ctx, act, f'zone "{act.zones[0]}" not found in the preset')
        return np.zeros(n, dtype=bool)
    zm = ctx.zones[zi].maskfilled
    zm = zm if zm.dtype == bool else (zm > 0)
    rows = []
    for name in act.body_parts:
        part = _resolve_act_part(act, ctx, name)
        if part is None:
            continue
        rows.append(_points_in_mask(ctx.X[part, :], ctx.Y[part, :], zm))
    if not rows:
        _mark(ctx, act, "no declared body part could be resolved")
        return np.zeros(n, dtype=bool)
    return np.vstack(rows).all(axis=0)


def _apply_freezing(act, ctx, n):
    # speed_max carries the rest threshold. Left at its +inf default every frame
    # would qualify as freezing -- an all-true act, so refuse instead.
    thr = act.speed_max
    if not np.isfinite(thr):
        _mark(ctx, act, "freezing act declares no finite speed threshold (speed_max)")
        return np.zeros(n, dtype=bool)

    mode = (act.freezing_mode or "").strip().lower()
    if mode and mode not in ("allbodyparts", "noseandcenter", "headandcenter"):
        _mark(ctx, act, f'unknown freezing mode "{act.freezing_mode}"')
        return np.zeros(n, dtype=bool)

    # Modes mirror sphynx.acts.builtins.freezing so a library act and the
    # built-in path agree (S2 layer 4d).
    if mode == "allbodyparts":
        bpv = np.asarray(ctx.velocity_cm_s, dtype=float)
        parts = bpv.shape[0]
        if parts == 0:
            _mark(ctx, act, "no body parts available for AllBodyParts freezing")
            return np.zeros(n, dtype=bool)
        return np.nansum(bpv, axis=0) < thr * parts

    if mode in ("noseandcenter", "headandcenter"):
        lead = "nose" if mode == "noseandcenter" else "headcenter"
        lead_idx = _resolve_act_part(act, ctx, lead)
        center_idx = _resolve_act_part(act, ctx, "bodycenter")
        if lead_idx is None or center_idx is None:
            _mark(ctx, act, f'freezing mode "{act.freezing_mode}" needs {lead} + body center')
            return np.zeros(n, dtype=bool)
        lead_thr = thr * 2 if mode == "noseandcenter" else thr
        return (ctx.velocity_cm_s[lead_idx, :] < lead_thr) & (
            ctx.velocity_cm_s[center_idx, :] < thr)

    # No mode declared: conjunction over the act's own declared parts.
    parts = act.body_parts or ["headcenter", "bodycenter"]
    rows = []
    for name in parts:
        idx = _resolve_act_part(act, ctx, name)
        if idx is None:
            continue
        rows.append(ctx.velocity_cm_s[idx, :] < thr)
    if not rows:
        _mark(ctx, act, "no declared body part could be resolved for freezing")
        return np.zeros(n, dtype=bool)
    return np.vstack(rows).all(axis=0)


def _apply_rears(act, ctx, n):
    mode = (act.rear_mode or "").strip().lower()
    if mode not in ("", "tailbasepaws", "allbodyparts"):
        # Never let an unrecognised mode drift into another branch: a typo used
        # to land in AllBodyParts and could return an all-true act unmarked.
        _mark(ctx, act, f'unknown rear mode "{act.rear_mode}"')
        return np.zeros(n, dtype=bool)
    if mode in ("", "tailbasepaws"):
        t = _resolve_act_part(act, ctx, "tailbase")
        left = _resolve_act_part(act, ctx, "lefthindlimb")
        right = _resolve_act_part(act, ctx, "righthindlimb")
        if t is None or left is None or right is None:
            _mark(ctx, act, "TailbasePaws rear needs tailbase + both hind limbs")
            return np.zeros(n, dtype=bool)
        xk = ctx.x_kcorr
        d_l = hypot_kcorr(ctx.X[t, :] - ctx.X[left, :], ctx.Y[t, :] - ctx.Y[left, :], xk)
        d_r = hypot_kcorr(ctx.X[t, :] - ctx.X[right, :], ctx.Y[t, :] - ctx.Y[right, :], xk)
        sum_px = d_l + d_r
        if ctx.frame_rate > 0:
            win = max(3, 2 * int(np.ceil(ctx.frame_rate / 4)) + 1)
            sum_px = smooth_derived(sum_px, win)
        sum_cm = np.asarray(sum_px) / ctx.pixels_per_cm
        if act.rear_auto_threshold:
            thr_cm = auto_rear_threshold_cm(sum_cm)
            if not np.isfinite(thr_cm):
                _mark(ctx, act,
                      "auto rear threshold did not converge; using declared threshold_cm")
                thr_cm = act.threshold_cm
        else:
            thr_cm = act.threshold_cm
        if not np.isfinite(thr_cm):
            # `x < NaN` is False everywhere: an all-false act that looks real.
            _mark(ctx, act, "rear act has no finite threshold_cm")
            return np.zeros(n, dtype=bool)
        return sum_cm < thr_cm
    idx = _resolve_act_part(act, ctx, "bodycenter")
    if idx is None:
        _mark(ctx, act, "AllBodyParts rear needs a resolvable body center")
        return np.zeros(n, dtype=bool)
    if not np.isfinite(act.threshold_pxl):
        _mark(ctx, act, "rear act has no finite threshold_pxl")
        return np.zeros(n, dtype=bool)
    return ctx.Y[idx, :] < act.threshold_pxl


def eval_acts_library(acts, ctx: ActContext) -> dict:
    """Evaluate every act; simple/special first so complex acts can reference them."""
    results: dict = {}
    if not acts:
        return results
    for a in acts:
        if a.type.lower() != "complex":
            ctx.all_acts = acts
            ctx.results_by_name = results
            results[a.name] = apply_act(a, ctx)
    for a in acts:
        if a.type.lower() == "complex":
            ctx.all_acts = acts
            ctx.results_by_name = results
            results[a.name] = apply_act(a, ctx)
    return results

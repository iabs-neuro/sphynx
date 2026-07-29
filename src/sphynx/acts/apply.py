"""Evaluate one act on a session's data. Port of sphynx.acts.applyAct +
evalActsLibrary."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import median_filter

from sphynx.acts.rear_threshold import auto_rear_threshold_cm
from sphynx.acts.refine import refine_act_array
from sphynx.acts.schema import Act, ActContext
from sphynx.bodyparts import resolve_part
from sphynx.geom import hypot_kcorr
from sphynx.util.smoothing import smooth_derived


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


def apply_act(act: Act, ctx: ActContext) -> np.ndarray:
    n_frames = ctx.X.shape[1]
    t = act.type.lower()
    if t == "simple":
        b = _apply_simple(act, ctx, n_frames)
    elif t == "complex":
        b = _apply_complex(act, ctx, n_frames)
    elif t == "special":
        b = _apply_special(act, ctx, n_frames)
    else:
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
    part = resolve_part(ctx.body_parts, act.body_part)
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


def _apply_complex(act, ctx, n):
    comps = act.components
    if not comps:
        return np.zeros(n, dtype=bool)
    cmasks = np.zeros((len(comps), n), dtype=bool)
    for k, name in enumerate(comps):
        if name in ctx.results_by_name:
            cmasks[k, :] = ctx.results_by_name[name]
        else:
            j = next((i for i, a in enumerate(ctx.all_acts) if a.name == name), None)
            if j is not None:
                cmasks[k, :] = apply_act(ctx.all_acts[j], ctx)
    op = act.operation.lower()
    if op == "intersect":
        return cmasks.all(axis=0)
    if op == "union":
        return cmasks.any(axis=0)
    if op == "exclude":
        return cmasks[0, :] & ~cmasks[1:, :].any(axis=0)
    if op == "sequence":
        if cmasks.shape[0] < 2:
            return cmasks[0] if cmasks.shape[0] else np.zeros(n, dtype=bool)
        delay = max(1, round(act.seq_delay_sec * ctx.frame_rate))
        a = cmasks[0, :]
        window = np.zeros(n, dtype=bool)
        for k in range(n):
            if a[k]:
                window[k + 1 : min(n, k + delay + 1)] = True
        b = window & cmasks[1, :]
        for j in range(2, cmasks.shape[0]):
            b = b & cmasks[j, :]
        return b
    return np.zeros(n, dtype=bool)


def _apply_special(act, ctx, n):
    kind = act.special_kind.lower()
    if kind == "freezing":
        return _apply_freezing(act, ctx, n)
    if kind == "rears":
        return _apply_rears(act, ctx, n)
    if kind == "allinzone":
        return _apply_all_in_zone(act, ctx, n)
    return np.zeros(n, dtype=bool)


def _apply_all_in_zone(act, ctx, n):
    if not act.zones or not act.body_parts:
        return np.zeros(n, dtype=bool)
    zi = _find_zone(ctx.zones, act.zones[0])
    if zi is None:
        return np.zeros(n, dtype=bool)
    zm = ctx.zones[zi].maskfilled
    zm = zm if zm.dtype == bool else (zm > 0)
    rows = []
    for name in act.body_parts:
        part = resolve_part(ctx.body_parts, name)
        if part is None:
            continue
        rows.append(_points_in_mask(ctx.X[part, :], ctx.Y[part, :], zm))
    if not rows:
        return np.zeros(n, dtype=bool)
    return np.vstack(rows).all(axis=0)


def _apply_freezing(act, ctx, n):
    parts = act.body_parts or ["headcenter", "bodycenter"]
    rows = []
    for name in parts:
        idx = resolve_part(ctx.body_parts, name)
        if idx is None:
            continue
        rows.append(ctx.velocity_cm_s[idx, :] < act.speed_max)
    if not rows:
        return np.zeros(n, dtype=bool)
    return np.vstack(rows).all(axis=0)


def _apply_rears(act, ctx, n):
    mode = act.rear_mode
    if mode.lower() == "tailbasepaws" or mode == "":
        t = resolve_part(ctx.body_parts, "tailbase")
        left = resolve_part(ctx.body_parts, "lefthindlimb")
        right = resolve_part(ctx.body_parts, "righthindlimb")
        if t is None or left is None or right is None:
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
                thr_cm = act.threshold_cm
        else:
            thr_cm = act.threshold_cm
        return sum_cm < thr_cm
    idx = resolve_part(ctx.body_parts, "bodycenter")
    if idx is None:
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

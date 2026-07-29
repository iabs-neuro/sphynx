"""Act expression trees (S2 layer 4b).

A complex act is a tree, not a flat list: Or / And / Exclude / Sequence nodes
over Leaf references to other acts. The evaluator here is PURE -- it never
imports the act machinery. Callers pass two closures: `resolve_ref(name)`
returning a per-frame mask (or None when the name cannot be resolved) and
`on_error(reason)` recording a degradation. That keeps this module out of a
circular import with apply.py and makes trees testable on their own.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from sphynx.exceptions import SphynxValueError


@dataclass
class Leaf:
    """Reference to another act by name."""

    act_ref: str = ""


@dataclass
class Or:
    children: list = field(default_factory=list)


@dataclass
class And:
    children: list = field(default_factory=list)


@dataclass
class Exclude:
    """base minus subtract. Several subtractions compose as Exclude(b, Or([...]))."""

    base: object = None
    subtract: object = None


@dataclass
class Sequence:
    """Steps that must fire in order, each within delays_sec[i] of the previous."""

    steps: list = field(default_factory=list)
    delays_sec: list = field(default_factory=list)


def _followed_by(prev, nxt, win_frames):
    """Frames where `nxt` fires within `win_frames` after a `prev` frame."""
    n = prev.size
    window = np.zeros(n, dtype=bool)
    for k in np.flatnonzero(prev):
        window[k + 1 : min(n, k + win_frames + 1)] = True
    return window & nxt


def _eval_sequence(expr, n_frames, resolve_ref, frame_rate, on_error):
    steps = list(expr.steps or [])
    if len(steps) < 2:
        on_error("SEQUENCE needs at least two steps")
        return np.zeros(n_frames, dtype=bool)

    delays = list(expr.delays_sec or [])
    if len(delays) == 1 and len(steps) > 2:
        delays = delays * (len(steps) - 1)      # one delay applies to every hop
    if len(delays) != len(steps) - 1:
        raise SphynxValueError(
            f"SEQUENCE needs {len(steps) - 1} delays for {len(steps)} steps; "
            f"got {len(delays)}")

    active = eval_expr(steps[0], n_frames, resolve_ref, frame_rate, on_error)
    for i in range(1, len(steps)):
        nxt = eval_expr(steps[i], n_frames, resolve_ref, frame_rate, on_error)
        win = max(1, int(round(delays[i - 1] * frame_rate)))
        active = _followed_by(active, nxt, win)
    return active


def eval_expr(expr, n_frames, resolve_ref, frame_rate, on_error) -> np.ndarray:
    """Walk an expression tree to a per-frame boolean mask."""
    zeros = np.zeros(n_frames, dtype=bool)

    if expr is None:
        on_error("empty expression")
        return zeros

    if isinstance(expr, Leaf):
        mask = resolve_ref(expr.act_ref)
        if mask is None:
            on_error(f'act reference "{expr.act_ref}" could not be resolved')
            return zeros
        return np.asarray(mask, dtype=bool).ravel()

    if isinstance(expr, Or):
        if not expr.children:
            on_error("OR node has no children")
            return zeros
        out = zeros.copy()
        for ch in expr.children:
            out |= eval_expr(ch, n_frames, resolve_ref, frame_rate, on_error)
        return out

    if isinstance(expr, And):
        if not expr.children:
            on_error("AND node has no children")
            return zeros
        out = np.ones(n_frames, dtype=bool)
        for ch in expr.children:
            out &= eval_expr(ch, n_frames, resolve_ref, frame_rate, on_error)
        return out

    if isinstance(expr, Exclude):
        if expr.base is None:
            on_error("EXCLUDE node has no base")
            return zeros
        base = eval_expr(expr.base, n_frames, resolve_ref, frame_rate, on_error)
        if expr.subtract is None:
            return base
        sub = eval_expr(expr.subtract, n_frames, resolve_ref, frame_rate, on_error)
        return base & ~sub

    if isinstance(expr, Sequence):
        return _eval_sequence(expr, n_frames, resolve_ref, frame_rate, on_error)

    on_error(f"unknown expression node type {type(expr).__name__}")
    return zeros


def from_flat(act):
    """Migrate the flat components/operation model onto a tree.

    Returns None only when the operation is unknown (or there is nothing to
    migrate), so the caller can report that specific condition."""
    comps = list(act.components or [])
    if not comps:
        return None
    leaves = [Leaf(c) for c in comps]
    op = (act.operation or "").lower()

    if op == "union":
        return Or(leaves)
    if op == "intersect":
        return And(leaves)
    if len(leaves) == 1 and op in ("exclude", "sequence"):
        return leaves[0]            # nothing to subtract from / chain to
    if op == "exclude":
        sub = leaves[1] if len(leaves) == 2 else Or(leaves[1:])
        return Exclude(leaves[0], sub)
    if op == "sequence":
        return Sequence(leaves, [act.seq_delay_sec] * (len(leaves) - 1))
    return None

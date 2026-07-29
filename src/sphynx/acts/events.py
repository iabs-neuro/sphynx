"""Events layer: ordered, labelled episodes derived from act traces.
Domain-model abstraction (spec section 3.3). Frame indices are 0-based."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

from sphynx.acts.refine import refine_act


@dataclass
class Event:
    act: str
    start_frame: int
    end_frame: int
    duration_s: float
    label: str | None = None
    index: int | None = None
    is_target: bool = False


def events_from_act(
    act_mask, frame_rate: float, act_name: str = "", label: str | None = None,
    index: int | None = None, is_target: bool = False,
) -> list[Event]:
    """Derive episodes from a binary act trace (no refinement applied here)."""
    _, runs = refine_act(act_mask, 0, 0)
    return [
        Event(act_name, r.frame_in, r.frame_out, r.duration / frame_rate, label,
              index, is_target)
        for r in runs
    ]


@dataclass
class EventStream:
    """Time-ordered list of Events (single act, or a merged act family)."""

    events: list[Event] = field(default_factory=list)

    def first(self) -> Event | None:
        return self.events[0] if self.events else None

    def first_where(self, pred: Callable[[Event], bool]) -> Event | None:
        return next((e for e in self.events if pred(e)), None)

    def labels_before(self, event: Event) -> list[str | None]:
        return [e.label for e in self.events if e.start_frame < event.start_frame]

    def order_of(self, label: str) -> int | None:
        for i, e in enumerate(self.events):
            if e.label == label:
                return i
        return None

    def unique_labels(self) -> list[str | None]:
        seen: list[str | None] = []
        for e in self.events:
            if e.label not in seen:
                seen.append(e.label)
        return seen

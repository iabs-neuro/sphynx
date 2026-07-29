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
        """Every episode label strictly before `event`, repeats included."""
        return [e.label for e in self.events if e.start_frame < event.start_frame]

    def distinct_labels_before(self, event: Event) -> list[str | None]:
        """Labels first visited before `event`, in visit order, each once.

        This -- not `labels_before` -- is what an error count wants: re-checking
        the same hole twice is one error, not two."""
        seen: list[str | None] = []
        for e in self.events:
            if e.start_frame >= event.start_frame:
                break
            if e.label not in seen:
                seen.append(e.label)
        return seen

    def order_of(self, label: str) -> int | None:
        """0-based VISIT ordinal of `label`: how many other labels were visited
        before it. Episode position would count revisits of an earlier label as
        extra places and inflate every ordinal after the first repeat."""
        seen: list[str | None] = []
        for e in self.events:
            if e.label not in seen:
                seen.append(e.label)
            if e.label == label:
                return len(seen) - 1
        return None

    def unique_labels(self) -> list[str | None]:
        seen: list[str | None] = []
        for e in self.events:
            if e.label not in seen:
                seen.append(e.label)
        return seen

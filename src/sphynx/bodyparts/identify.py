"""Identify canonical body parts by alias. Port of
sphynx.bodyparts.identifyParts."""

from __future__ import annotations

from dataclasses import dataclass, fields


@dataclass
class Point:
    """Canonical body-part -> 0-based index (or None). Mirrors the MATLAB
    identifyParts struct."""

    miniscope_ucla: int | None = None
    nose: int | None = None
    left_ear: int | None = None
    right_ear: int | None = None
    head_center: int | None = None
    left_fore_limb: int | None = None
    right_fore_limb: int | None = None
    left_body_center: int | None = None
    right_body_center: int | None = None
    left_hind_limb: int | None = None
    right_hind_limb: int | None = None
    tailbase: int | None = None
    center: int | None = None


# canonical field -> accepted synonyms (lowercased). Single source of truth
# consulted by resolve_part, compute_center, relative_coords, acts.
_SYNONYMS: dict[str, tuple[str, ...]] = {
    "miniscope_ucla": ("miniscopeucla",),
    "nose": ("nose", "snout"),
    "left_ear": ("leftear", "left_ear", "left ear", "left_ear_tip"),
    "right_ear": ("rightear", "right_ear", "right ear", "right_ear_tip"),
    "head_center": ("headcenter", "head_midpoint", "head midpoint",
                    "head_center", "head center", "neck"),
    "left_fore_limb": ("leftforelimb", "left_forelimb", "left forelimb",
                       "left_shoulder", "left shoulder"),
    "right_fore_limb": ("righforelimb", "rightforelimb", "right_forelimb",
                        "right forelimb", "right_shoulder", "right shoulder"),
    "left_body_center": ("leftbody", "left_body", "left body",
                         "left_midside", "left midside"),
    "right_body_center": ("rightbody", "right_body", "right body",
                          "right_midside", "right midside"),
    "left_hind_limb": ("lefthindlimb", "left_hindlimb", "left hindlimb",
                       "left_hip", "left hip"),
    "right_hind_limb": ("righthindlimb", "right_hindlimb", "right hindlimb",
                        "right_hip", "right hip"),
    "tailbase": ("tailbase", "tail base", "tail_base", "tail1"),
    "center": ("mass centre", "mass center", "bodycenter", "body_center",
               "body center", "center", "mouse_center", "mouse center"),
}


def identify_parts(names) -> Point:
    """Map a list of DLC body-part labels onto canonical Point fields (first
    match wins, case-insensitive). Port of sphynx.bodyparts.identifyParts."""
    lowered = [str(n).strip().lower() for n in names]
    point = Point()
    for canon, syns in _SYNONYMS.items():
        for i, label in enumerate(lowered):
            if label in syns:
                setattr(point, canon, i)
                break
    return point

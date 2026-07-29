"""Default body-part fallback chains (S2 layer 4a).

A chain lists positional proxies to try when the requested part is absent from
the DLC schema. Chains are deliberately conservative: only substitutions that
stay scientifically defensible as a position estimate. Geometry-critical parts
(hind limbs, ears) carry NO default chain -- proxying them would silently
corrupt rear detection and head-angle math (the R31#4 defect class). An act may
always declare its own chain, which overrides these defaults.
"""

from __future__ import annotations

DEFAULT_FALLBACKS: dict[str, list[str]] = {
    "nose": ["head_center"],
    "head_center": ["nose", "center"],
    "center": ["tailbase", "head_center"],
    "tailbase": ["center"],
}

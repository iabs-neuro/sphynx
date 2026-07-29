"""Body-part fallback chains (S2 layer 4a).

A chain lists positional proxies to try when the requested part is absent from
the DLC schema. Two rules govern this module:

1. **Chains are declared per act, never implicit.** `resolve_act_parts` does not
   substitute anything unless the act itself declares a chain (or a paradigm
   supplies one). A part that is simply missing produces a warning and a
   degraded act -- not a plausible stand-in. This is the approved S2 model and
   the fix for the R31#4 defect class.

2. **Any substitution shifts the measurement.** `nose -> head_center` offsets an
   exploration-radius criterion by roughly the criterion itself; `center ->
   head_center` is a poor velocity proxy for speed binning and freezing. There
   is therefore no scientifically neutral default chain, and this registry ships
   empty. It remains the extension point where a paradigm (S2 M6) or the GUI can
   register *suggested* chains for an author to accept deliberately.

Geometry-critical parts (hind limbs, ears) must never carry a suggestion at all:
proxying them corrupts rear detection and head-angle math outright.
"""

from __future__ import annotations

# Suggested chains, keyed by canonical part name. Empty by design -- see rule 2.
# resolve_act_parts consults this only when explicitly asked (use_defaults=True).
DEFAULT_FALLBACKS: dict[str, list[str]] = {}

# Parts that must never be proxied, whatever a suggestion registry holds.
GEOMETRY_CRITICAL: frozenset = frozenset({
    "left_hind_limb", "right_hind_limb", "left_ear", "right_ear",
})

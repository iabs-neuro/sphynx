"""Default acts library (rest/walk/locomotion/freezing/rear). Port of
sphynx.acts.actsLibraryDefaults."""

from __future__ import annotations

from sphynx.acts.schema import Act, build_simple_act
from sphynx.config import Config


def acts_library_defaults(config: Config | None = None) -> list[Act]:
    if config is None:
        config = Config.default()
    rest = config.acts.rest_threshold_cm_s
    loc = config.acts.loc_threshold_cm_s
    rear_tbc = config.acts.rear_threshold_tailbase_paws_cm
    rear_abp = config.acts.rear_threshold_all_body_parts_pxl

    return [
        build_simple_act(name="rest", body_part="bodycenter", speed_min=0, speed_max=rest),
        build_simple_act(name="walk", body_part="bodycenter", speed_min=rest, speed_max=loc),
        build_simple_act(name="locomotion", body_part="bodycenter", speed_min=loc,
                         speed_max=float("inf")),
        Act(name="freezing", type="special", special_kind="freezing",
            body_parts=["headcenter", "bodycenter"], speed_max=rest),
        Act(name="rear", type="special", special_kind="rears", rear_mode="TailbasePaws",
            threshold_cm=rear_tbc, threshold_pxl=rear_abp, rear_auto_threshold=True),
    ]

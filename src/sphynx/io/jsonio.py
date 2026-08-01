"""JSON helpers shared by the paradigm and act-library codecs.

Two properties matter for files a researcher may edit by hand: a typo must
raise rather than silently drop a section, and the file must be readable by
something other than Python -- so non-finite floats are encoded explicitly
instead of written as bare Infinity/NaN.
"""

from __future__ import annotations

import json
from dataclasses import fields
from pathlib import Path

from sphynx.exceptions import SphynxIOError, SphynxValueError

_INF, _NEG_INF, _NAN_TAG = "__inf__", "__-inf__", "__nan__"


def encode_specials(value):
    if isinstance(value, float):
        if value == float("inf"):
            return _INF
        if value == float("-inf"):
            return _NEG_INF
        if value != value:
            return _NAN_TAG
        return value
    if isinstance(value, dict):
        return {k: encode_specials(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [encode_specials(v) for v in value]
    return value


def decode_specials(value):
    if isinstance(value, str):
        if value == _INF:
            return float("inf")
        if value == _NEG_INF:
            return float("-inf")
        if value == _NAN_TAG:
            return float("nan")
        return value
    if isinstance(value, dict):
        return {k: decode_specials(v) for k, v in value.items()}
    if isinstance(value, list):
        return [decode_specials(v) for v in value]
    return value


def check_keys(data, known, what) -> None:
    if not isinstance(data, dict):
        raise SphynxValueError(f"{what} must be an object; got {type(data).__name__}")
    unknown = set(data) - set(known)
    if unknown:
        raise SphynxValueError(
            f"{what} has unknown field(s) {sorted(unknown)}; known: {sorted(known)}")


def from_fields(cls, data, what):
    """Build a dataclass from a dict, rejecting unknown keys loudly."""
    check_keys(data, {f.name for f in fields(cls)}, what)
    return cls(**data)


def write_json(payload, path) -> str:
    """Write through a temporary file so a failure cannot truncate a good one."""
    target = Path(path)
    tmp = target.with_name(target.name + ".tmp")
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(encode_specials(payload), handle, indent=2, sort_keys=False,
                      allow_nan=False)
        tmp.replace(target)
    except (OSError, TypeError, ValueError) as e:
        tmp.unlink(missing_ok=True)
        raise SphynxIOError(f"cannot write {target}: {e}") from e
    return str(target)


def read_json(path):
    source = Path(path)
    if not source.is_file():
        raise SphynxIOError(f"file not found: {source}")
    try:
        with open(source, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as e:
        raise SphynxIOError(f"malformed JSON in {source}: {e}") from e
    except OSError as e:
        raise SphynxIOError(f"cannot read {source}: {e}") from e
    return decode_specials(data)

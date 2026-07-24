"""Exception hierarchy. No silent fallbacks — engine raises these instead."""


class SphynxError(Exception):
    """Base class for all sphynx errors."""


class SphynxConfigError(SphynxError):
    """Invalid or unreadable configuration."""


class SphynxIOError(SphynxError):
    """Failure reading or writing sphynx data (DLC, preset, ...)."""


class SphynxGeometryError(SphynxError):
    """Invalid input to a geometric fit."""


class TooFewPointsError(SphynxGeometryError):
    """Not enough points to perform the requested fit."""


class DegenerateGeometryError(SphynxGeometryError):
    """Points are degenerate (e.g. collinear) for the requested fit."""


class SphynxValueError(SphynxError):
    """Invalid parameter value passed to a sphynx function."""

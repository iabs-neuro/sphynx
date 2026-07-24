import sphynx
from sphynx.exceptions import (
    SphynxError, SphynxConfigError, SphynxIOError,
    SphynxGeometryError, TooFewPointsError, DegenerateGeometryError,
)
from sphynx.logging_setup import get_logger


def test_package_imports_and_has_version():
    assert isinstance(sphynx.__version__, str)
    assert sphynx.__version__


def test_exception_hierarchy():
    assert issubclass(SphynxConfigError, SphynxError)
    assert issubclass(SphynxIOError, SphynxError)
    assert issubclass(SphynxGeometryError, SphynxError)
    assert issubclass(TooFewPointsError, SphynxGeometryError)
    assert issubclass(DegenerateGeometryError, SphynxGeometryError)


def test_logger_is_singleton_per_name():
    a = get_logger("sphynx.test")
    b = get_logger("sphynx.test")
    assert a is b
    assert len(a.handlers) == 1


def test_logger_does_not_propagate():
    logger = get_logger("sphynx.x")
    assert logger.propagate is False

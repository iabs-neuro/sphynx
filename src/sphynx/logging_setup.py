"""Central logging. Use get_logger() everywhere instead of print()."""

import logging

_FORMAT = "[%(levelname)s] %(name)s: %(message)s"


def get_logger(name: str = "sphynx") -> logging.Logger:
    """Return a logger with a single stream handler attached exactly once."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(_FORMAT))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger

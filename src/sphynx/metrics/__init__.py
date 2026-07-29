"""Named metrics: registry + built-ins (S2 layer 5)."""

from sphynx.metrics.registry import (
    REGISTRY,
    MetricContext,
    MetricResults,
    MetricSpec,
    compute_metric,
    compute_metrics,
    missing_requirements,
    register_metric,
)

__all__ = [
    "REGISTRY", "MetricContext", "MetricResults", "MetricSpec",
    "compute_metric", "compute_metrics", "missing_requirements",
    "register_metric", "builtins",
]

from sphynx.metrics import builtins as builtins  # noqa: F401  (registers built-ins)

"""Prometheus metrics for the Task Manager API.

A dedicated CollectorRegistry is used so the app can be instantiated more than
once (tests) without duplicate metric registration errors.
"""

from prometheus_client import CollectorRegistry, Counter, Gauge, Histogram

REGISTRY = CollectorRegistry()

# Counter of successfully created tasks -> exposed as tasks_created_total
tasks_created = Counter(
    "tasks_created",
    "Total number of tasks created",
    registry=REGISTRY,
)

# Histogram of HTTP request latency in seconds
request_latency = Histogram(
    "request_latency_seconds",
    "HTTP request latency in seconds",
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
    registry=REGISTRY,
)

# Counter of HTTP requests labelled by method, path template and status code
http_requests = Counter(
    "http_requests_total",
    "Total HTTP requests",
    labelnames=("method", "path", "status"),
    registry=REGISTRY,
)

# Counter of deleted tasks -> exposed as tasks_deleted_total
tasks_deleted = Counter(
    "tasks_deleted",
    "Total number of tasks deleted",
    registry=REGISTRY,
)

# Gauge holding the number of tasks currently stored in memory
tasks_current = Gauge(
    "tasks_current",
    "Number of tasks currently stored",
    registry=REGISTRY,
)

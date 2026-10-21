"""Application configuration (kept in one place so a merge-conflict demo can target it)."""

# Maximum allowed length of a task title.
MAX_TITLE_LENGTH = 100

# Minimum allowed length of a task title.
MIN_TITLE_LENGTH = 1

# TCP port the HTTP server listens on.
DEFAULT_PORT = 8000

# Service / application name used as the Kubernetes label and metrics prefix.
APP_NAME = "task-api"

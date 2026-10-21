# Task Manager API - small, pinned, reproducible image
FROM python:3.11-slim

# Small footprint + predictable behaviour
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_PORT=8000

WORKDIR /app

# 1) dependencies first -> layer cache is reused when only app code changes
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 2) application code
COPY app/ ./app/

# 3) run as a non-root user with a FIXED numeric uid.
#    Kubernetes refuses to start a container with runAsNonRoot=true when the
#    image user is a name (it cannot verify that it is not root), so the uid
#    must be numeric and stable: appuser = uid 10001.
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 --gid 10001 --home-dir /app --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appgroup /app
USER 10001

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health', timeout=2).status == 200 else 1)"

# NOTE: 1 worker + several threads on purpose. The store is in memory and the
# Prometheus counters are per-process, so a single worker keeps the data and the
# metrics consistent. That is all this demo needs.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", "--timeout", "30", "app.app:app"]

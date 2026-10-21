"""Task Manager REST API.

Endpoints
---------
GET    /health          -> {"status": "ok"}
GET    /tasks           -> list of tasks
POST   /tasks           -> create a task  ({"title": "..."})
DELETE /tasks/<id>      -> delete a task
GET    /metrics         -> Prometheus metrics
"""

import logging
import re
import time

from flask import Flask, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from .config import APP_NAME, DEFAULT_PORT, MAX_TITLE_LENGTH, MIN_TITLE_LENGTH
from .metrics import REGISTRY, http_requests, request_latency, tasks_created, tasks_current
from .store import TaskStore

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(APP_NAME)


def create_app(store: TaskStore = None) -> Flask:
    app = Flask(__name__)
    app.config["store"] = store if store is not None else TaskStore()
    app.config["JSON_SORT_KEYS"] = False

    @app.before_request
    def _start_timer():
        request.environ["_start_time"] = time.perf_counter()
        return None

    @app.after_request
    def _record_metrics(response):
        try:
            duration = time.perf_counter() - request.environ.get("_start_time", time.perf_counter())
            # Use the route template (/tasks/<id>) to keep label cardinality low.
            rule = request.url_rule.rule if request.url_rule else request.path
            path = re.sub(r"<[^:>]+:", "<", rule)
            request_latency.observe(duration)
            http_requests.labels(
                method=request.method,
                path=path,
                status=str(response.status_code),
            ).inc()
            tasks_current.set(app.config["store"].count())
        except Exception as exc:  # never break a response because of metrics
            log.warning("metric recording failed: %s", exc)
        return response

    @app.get("/health")
    def health():
        return jsonify({"status": "ok"}), 200

    @app.get("/health/details")
    def health_details():
        return jsonify(
            {
                "status": "ok",
                "service": APP_NAME,
                "version": "1.0.0",
                "tasks": app.config["store"].count(),
            }
        ), 200

    @app.get("/tasks")
    def list_tasks():
        tasks = app.config["store"].list()
        return jsonify({"tasks": tasks, "count": len(tasks)}), 200

    @app.post("/tasks")
    def create_task():
        payload = request.get_json(silent=True)
        if payload is None or not isinstance(payload, dict):
            return jsonify({"error": "request body must be a JSON object"}), 400
        if "title" not in payload:
            return jsonify({"error": "field 'title' is required"}), 400
        title = payload["title"]
        if not isinstance(title, str):
            return jsonify({"error": "field 'title' must be a string"}), 400
        if len(title) < MIN_TITLE_LENGTH:
            return jsonify({"error": "field 'title' must not be empty"}), 400
        if len(title) > MAX_TITLE_LENGTH:
            return jsonify(
                {"error": f"field 'title' must be at most {MAX_TITLE_LENGTH} characters"}
            ), 422
        task = app.config["store"].create(title)
        tasks_created.inc()
        tasks_current.set(app.config["store"].count())
        return jsonify(task), 201

    @app.delete("/tasks/<int:task_id>")
    def delete_task(task_id: int):
        if app.config["store"].delete(task_id):
            tasks_current.set(app.config["store"].count())
            return jsonify({"deleted": task_id}), 200
        return jsonify({"error": f"task {task_id} not found"}), 404

    @app.get("/metrics")
    def metrics():
        tasks_current.set(app.config["store"].count())
        return generate_latest(REGISTRY), 200, {"Content-Type": CONTENT_TYPE_LATEST}

    @app.errorhandler(404)
    def not_found(_):
        return jsonify({"error": "not found"}), 404

    @app.errorhandler(405)
    def method_not_allowed(_):
        return jsonify({"error": "method not allowed"}), 405

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=DEFAULT_PORT)

"""Pytest suite for the Task Manager API (10 tests)."""

from app.config import MAX_TITLE_LENGTH
from app.metrics import REGISTRY


# --------------------------------------------------------------------------- #
# health
# --------------------------------------------------------------------------- #
def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


# --------------------------------------------------------------------------- #
# create
# --------------------------------------------------------------------------- #
def test_create_task_returns_201_and_task(client):
    response = client.post("/tasks", json={"title": "buy milk"})
    assert response.status_code == 201
    body = response.get_json()
    assert body["id"] == 1
    assert body["title"] == "buy milk"


def test_create_task_without_title_returns_400(client):
    response = client.post("/tasks", json={"name": "no title here"})
    assert response.status_code == 400
    assert "title" in response.get_json()["error"]


def test_create_task_with_non_string_title_returns_400(client):
    response = client.post("/tasks", json={"title": 12345})
    assert response.status_code == 400


def test_create_task_with_too_long_title_returns_422(client):
    response = client.post("/tasks", json={"title": "x" * (MAX_TITLE_LENGTH + 1)})
    assert response.status_code == 422
    assert str(MAX_TITLE_LENGTH) in response.get_json()["error"]


# --------------------------------------------------------------------------- #
# list
# --------------------------------------------------------------------------- #
def test_list_tasks_returns_created_tasks(client):
    assert client.get("/tasks").get_json()["count"] == 0
    client.post("/tasks", json={"title": "task one"})
    client.post("/tasks", json={"title": "task two"})
    body = client.get("/tasks").get_json()
    assert body["count"] == 2
    assert [t["title"] for t in body["tasks"]] == ["task one", "task two"]


# --------------------------------------------------------------------------- #
# delete
# --------------------------------------------------------------------------- #
def test_delete_task_removes_it(client):
    created = client.post("/tasks", json={"title": "temporary"}).get_json()
    response = client.delete(f"/tasks/{created['id']}")
    assert response.status_code == 200
    assert client.get("/tasks").get_json()["count"] == 0


def test_delete_unknown_task_returns_404(client):
    response = client.delete("/tasks/9999")
    assert response.status_code == 404


# --------------------------------------------------------------------------- #
# metrics
# --------------------------------------------------------------------------- #
def test_metrics_endpoint_exposes_prometheus_metrics(client):
    client.post("/tasks", json={"title": "metric task"})
    response = client.get("/metrics")
    assert response.status_code == 200
    body = response.get_data(as_text=True)
    for metric in (
        "tasks_created_total",
        "request_latency_seconds_bucket",
        "http_requests_total",
        "tasks_current",
    ):
        assert metric in body, f"missing metric: {metric}"


def test_tasks_created_counter_increments(client):
    before = REGISTRY.get_sample_value("tasks_created_total") or 0.0
    client.post("/tasks", json={"title": "counter task"})
    after = REGISTRY.get_sample_value("tasks_created_total") or 0.0
    assert after == before + 1


def test_tasks_current_gauge_matches_store(client):
    client.post("/tasks", json={"title": "gauge task"})
    client.get("/metrics")
    assert REGISTRY.get_sample_value("tasks_current") == 1


<<<<<<< HEAD
def test_delete_task_increments_deleted_counter(client):
    created = client.post("/tasks", json={"title": "counted"}).get_json()
    before = REGISTRY.get_sample_value("tasks_deleted_total") or 0.0
    client.delete(f"/tasks/{created['id']}")
    after = REGISTRY.get_sample_value("tasks_deleted_total") or 0.0
    assert after == before + 1
=======
def test_health_details_returns_service_info(client):
    response = client.get("/health/details")
    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "ok"
    assert body["service"] == "task-api"
>>>>>>> origin/develop

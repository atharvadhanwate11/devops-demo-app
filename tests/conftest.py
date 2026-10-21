"""Shared pytest fixtures for the Task Manager API tests."""

import pytest

from app.app import create_app
from app.store import TaskStore


@pytest.fixture()
def client():
    """Fresh application (and fresh in-memory store) for every test."""
    app = create_app(store=TaskStore())
    app.config.update(TESTING=True)
    with app.test_client() as test_client:
        yield test_client

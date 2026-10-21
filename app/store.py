"""In-memory task store (no database - deliberately boring)."""

import threading
from typing import Dict


class TaskStore:
    """Thread-safe dictionary of tasks: {id: {"id": int, "title": str}}."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._tasks: Dict[int, dict] = {}
        self._next_id = 1

    def create(self, title: str) -> dict:
        with self._lock:
            task = {"id": self._next_id, "title": title}
            self._tasks[self._next_id] = task
            self._next_id += 1
            return dict(task)

    def list(self) -> list:
        with self._lock:
            return [dict(task) for task in self._tasks.values()]

    def get(self, task_id: int):
        with self._lock:
            task = self._tasks.get(task_id)
            return dict(task) if task else None

    def delete(self, task_id: int) -> bool:
        with self._lock:
            return self._tasks.pop(task_id, None) is not None

    def count(self) -> int:
        with self._lock:
            return len(self._tasks)

    def clear(self) -> None:
        with self._lock:
            self._tasks.clear()
            self._next_id = 1

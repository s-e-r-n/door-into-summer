from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from typing import Generic, Hashable, TypeVar

Key = TypeVar("Key", bound=Hashable)
Value = TypeVar("Value")


class Once(Generic[Key, Value]):
    def __init__(self, read: Callable[[Key], Value], on_read: Callable[[Key], None], workers: ThreadPoolExecutor):
        self.read = read
        self.on_read = on_read
        self.workers = workers
        self.values: dict[Key, Value] = {}
        self.reading: set[Key] = set()

    def value(self, key: Key) -> Value | None:
        if key in self.values:
            return self.values[key]
        if key not in self.reading:
            self.reading.add(key)
            self.workers.submit(self.read_one, key)
        return None

    def read_one(self, key: Key) -> None:
        self.values[key] = self.read(key)
        self.reading.discard(key)
        self.on_read(key)

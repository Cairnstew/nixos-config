from abc import ABC, abstractmethod
from collections.abc import Iterator


class BaseRepository(ABC):
    """Abstract interface for data access."""

    @abstractmethod
    def list(self) -> Iterator[object]: ...

    @abstractmethod
    def get(self, identifier: str) -> object | None: ...

    @abstractmethod
    def save(self, obj: object) -> None: ...

    @abstractmethod
    def delete(self, identifier: str) -> None: ...

from abc import ABC, abstractmethod


class BaseService(ABC):
    """Abstract interface for all business-logic services."""

    @abstractmethod
    def execute(self) -> None:
        ...

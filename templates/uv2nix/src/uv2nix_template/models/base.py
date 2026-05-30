from dataclasses import dataclass, field
from typing import Any


@dataclass
class BaseModel:
    """Base dataclass shared across all domain models.

    Swap for pydantic.BaseModel, SQLModel, or attrs when the project
    needs validation, serialization, or ORM integration.
    """

    extra: dict[str, Any] = field(default_factory=dict)

from typing import Any, Protocol, TypeAlias

JSON: TypeAlias = dict[str, Any] | list[Any] | str | int | float | bool | None


class HasName(Protocol):
    name: str

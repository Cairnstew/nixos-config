from __future__ import annotations

from typing import Any
import pydantic


class BaseResult(pydantic.BaseModel):
    ok: bool
    message: str = ""


class SuccessResult(BaseResult):
    ok: bool = True
    data: Any = None


class ErrorResult(BaseResult):
    ok: bool = False
    error_type: str = ""


class AppConfig(pydantic.BaseModel):
    log_level: str = "info"
    extra_args: list[str] = []

    def serialise(self) -> dict[str, object]:
        return self.model_dump()

from pathlib import Path
from typing import Any


class Settings:
    """Thin wrapper around env-based configuration.

    Replace with pydantic-settings, environs, or similar when the project
    outgrows a plain dataclass.
    """

    debug: bool = False
    log_level: str = "INFO"
    data_dir: Path = Path.cwd() / "data"

    def __init__(self, **kwargs: Any) -> None:
        for key, value in kwargs.items():
            setattr(self, key, value)


settings = Settings()

from __future__ import annotations

from dataclasses import dataclass, field

from uv2nix_template.models.config import AppConfig


@dataclass
class AppContext:
    verbose: bool = False
    config: AppConfig | None = None

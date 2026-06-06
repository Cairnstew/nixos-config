from __future__ import annotations

from uv2nix_template.models.config import AppConfig
from uv2nix_template.services.base import BaseService


class ConfigService(BaseService):
    def read(self) -> AppConfig:
        self.logger.debug("Reading config")
        return self.config

    def write(self, config: AppConfig) -> None:
        self.logger.debug("Writing config")
        self.config = config

from __future__ import annotations

import logging

from uv2nix_template.models.config import AppConfig


class BaseService:
    def __init__(self, config: AppConfig) -> None:
        self.config = config
        self.logger = logging.getLogger(self.__class__.__module__)

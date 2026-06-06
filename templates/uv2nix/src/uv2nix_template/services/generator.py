from __future__ import annotations

from uv2nix_template.models.config import AppConfig, BaseResult, SuccessResult
from uv2nix_template.services.base import BaseService


class GeneratorService(BaseService):
    def initialise(self) -> BaseResult:
        self.logger.info("Initialising uv2nix project")
        return SuccessResult(message="Initialised.")

    def generate(self) -> BaseResult:
        self.logger.info("Generating output")
        return SuccessResult(message="Generated.")

from __future__ import annotations

from uv2nix_template.models.config import AppConfig, BaseResult, SuccessResult, ErrorResult
from uv2nix_template.services.base import BaseService
from uv2nix_template.exceptions import ValidationError


class ValidatorService(BaseService):
    def validate(self, path: str) -> BaseResult:
        self.logger.info("Validating %s", path)
        if not path:
            return ErrorResult(message="Path is empty", error_type="empty_path")
        return SuccessResult(message="Validation passed.")

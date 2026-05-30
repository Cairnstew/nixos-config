class TemplateError(Exception):
    """Base exception for all application errors."""


class ConfigurationError(TemplateError):
    """Raised when required configuration is missing or invalid."""


class ServiceError(TemplateError):
    """Raised when a service-layer operation fails."""


class NotFoundError(TemplateError):
    """Raised when a requested resource does not exist."""

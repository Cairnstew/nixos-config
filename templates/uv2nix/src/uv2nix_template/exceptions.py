class Uv2nixError(Exception):
    """Root exception for all uv2nix_template errors."""

class ConfigError(Uv2nixError):
    """Raised when config is missing, malformed, or unwriteable."""

class GenerationError(Uv2nixError):
    """Raised when the generator cannot produce output."""

class ValidationError(Uv2nixError):
    """Raised when generated output fails validation."""

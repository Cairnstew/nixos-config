class TextualUIError(Exception):
    """Base exception for textual_ui errors."""


class ConfigurationError(TextualUIError):
    """Raised when UI configuration is invalid or missing."""


class WidgetError(TextualUIError):
    """Raised when a custom widget encounters an error."""


class ScreenError(TextualUIError):
    """Raised when a screen transition or lifecycle operation fails."""

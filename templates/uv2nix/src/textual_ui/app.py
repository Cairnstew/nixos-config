from textual.app import App as TextualAppBase
from textual.app import ComposeResult
from textual.screen import Screen
from textual.widgets import Footer, Header, Static


class TextualApp(TextualAppBase[Screen[None]]):
    """Base Textual application class.

    Subclass and override `compose()` or `on_mount()` to build your UI.
    All Textual CSS, actions, bindings, screens, and themes work as usual.

    Example:
        ```python
        from textual_ui import TextualApp

        class MyApp(TextualApp):
            def compose(self) -> ComposeResult:
                yield Static("Hello, World!")

        if __name__ == "__main__":
            MyApp().run()
        ```
    """

    CSS = """
    Screen {
        align: center middle;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Welcome to textual_ui")
        yield Footer()

    def on_mount(self) -> None:
        self.title = "textual_ui"

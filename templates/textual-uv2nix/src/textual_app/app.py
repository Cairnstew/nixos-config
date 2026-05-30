from __future__ import annotations

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Footer, Header, Label, ListItem, ListView


class HomeScreen(Screen):
    def compose(self) -> ComposeResult:
        yield Header()
        yield ListView(
            ListItem(Label("Hello, Textual!")),
            ListItem(Label("Nix + uv2nix")),
            ListItem(Label("Press q to quit")),
        )
        yield Footer()

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        item_text = event.item.query_one(Label).renderable
        if "Hello" in item_text:
            self.notify("Welcome!", title="Greeting")
        else:
            self.notify(f"Selected: {item_text}", title="Info")


class TextualApp(App):
    TITLE = "Textual App"
    SUB_TITLE = "uv2nix template"

    SCREENS = {"home": HomeScreen}

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("d", "toggle_dark", "Toggle dark mode"),
    ]

    CSS = """
    Screen {
        align: center middle;
    }
    ListView {
        width: 40;
        height: auto;
        margin: 1 2;
    }
    ListItem {
        padding: 1 2;
    }
    """

    def on_mount(self) -> None:
        self.push_screen("home")

    def action_toggle_dark(self) -> None:
        self.dark = not self.dark
        self.notify(
            f"{'Dark' if self.dark else 'Light'} mode",
            title="Theme",
        )


def main() -> int:
    app = TextualApp()
    return app.run()

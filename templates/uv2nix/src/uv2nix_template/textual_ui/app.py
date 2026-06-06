from textual.app import App
from textual.screen import Screen

from uv2nix_template.textual_ui.screens.main import MainScreen
from uv2nix_template.textual_ui.screens.search import SearchScreen
from uv2nix_template.textual_ui.screens.detail import ItemDetailScreen


class UvTemplateApp(App[Screen[None]]):
    SCREENS = {
        "main": MainScreen,
        "detail": ItemDetailScreen,
        "search": SearchScreen,
    }

    def on_mount(self) -> None:
        self.push_screen("main")

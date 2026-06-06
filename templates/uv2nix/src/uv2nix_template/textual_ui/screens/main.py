from __future__ import annotations

from uv2nix_template.textual_ui.base import ListScreen


class MainScreen(ListScreen):
    BINDINGS = ListScreen.BINDINGS + [("r", "refresh", "Refresh")]

    CSS_PATH = "../styles/main.tcss"

    def load_rows(self) -> list[tuple[str, ...]]:
        return [("example", "row")]

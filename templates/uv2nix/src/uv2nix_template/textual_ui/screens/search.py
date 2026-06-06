from __future__ import annotations

from uv2nix_template.textual_ui.base import ListScreen


class SearchScreen(ListScreen):
    BINDINGS = ListScreen.BINDINGS + [("r", "refresh", "Refresh")]

    def load_rows(self) -> list[tuple[str, ...]]:
        return []

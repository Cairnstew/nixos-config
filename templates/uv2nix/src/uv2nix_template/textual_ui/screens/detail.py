from __future__ import annotations

from uv2nix_template.textual_ui.base import DetailScreen


class ItemDetailScreen(DetailScreen):
    def load_detail(self, key: str) -> str:
        return f"Detail for: {key}"

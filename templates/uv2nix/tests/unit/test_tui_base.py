from __future__ import annotations

from uv2nix_template.textual_ui.base import BaseScreen, ListScreen, DetailScreen
from uv2nix_template.textual_ui.screens.main import MainScreen
from uv2nix_template.textual_ui.screens.detail import ItemDetailScreen
from uv2nix_template.textual_ui.actions import (
    RefreshMixin,
    SelectionMixin,
    NavigationMixin,
    LoggingMixin,
)


def test_inheritance_chain() -> None:
    assert issubclass(MainScreen, ListScreen)
    assert issubclass(ListScreen, BaseScreen)
    assert issubclass(ItemDetailScreen, DetailScreen)
    assert issubclass(DetailScreen, BaseScreen)


def test_list_screen_mixins() -> None:
    assert issubclass(ListScreen, RefreshMixin)
    assert issubclass(ListScreen, SelectionMixin)


def test_detail_screen_mixins() -> None:
    assert issubclass(DetailScreen, NavigationMixin)


def test_base_screen_mixin() -> None:
    assert issubclass(BaseScreen, LoggingMixin)


def test_load_rows_hook_overridable() -> None:
    class MyList(ListScreen):
        def load_rows(self) -> list[tuple[str, ...]]:
            return [("a", "b")]

    instance = MyList()
    assert instance.load_rows() == [("a", "b")]


def test_base_load_rows_returns_empty() -> None:
    assert ListScreen.load_rows(None) == []  # type: ignore[arg-type]


def test_logging_mixin_exists() -> None:
    assert hasattr(LoggingMixin, "log_event")


def test_refresh_mixin_action() -> None:
    assert hasattr(RefreshMixin, "action_refresh")


def test_selection_mixin_default_none() -> None:
    instance = SelectionMixin()
    assert instance.selected is None


def test_navigation_mixin_back() -> None:
    assert hasattr(NavigationMixin, "action_back")

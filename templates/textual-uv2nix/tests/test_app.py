from __future__ import annotations

import pytest
from textual.binding import Binding
from textual.widgets import Header, Footer

from textual_app.app import TextualApp


@pytest.fixture
def app():
    return TextualApp()


async def test_app_title(app):
    async with app.run_test() as pilot:
        assert app.TITLE == "Textual App"
        assert app.SUB_TITLE == "uv2nix template"


async def test_app_screens(app):
    async with app.run_test() as pilot:
        assert "home" in app.SCREENS
        assert pilot.app.screen is app.SCREENS["home"]


async def test_app_has_header_footer(app):
    async with app.run_test() as pilot:
        assert pilot.app.query(Header)
        assert pilot.app.query(Footer)


async def test_toggle_dark(app):
    async with app.run_test() as pilot:
        initial = app.dark
        await pilot.press("d")
        assert app.dark != initial


async def test_quit_binding(app):
    async with app.run_test() as pilot:
        assert Binding("q", "quit", "Quit") in app.BINDINGS

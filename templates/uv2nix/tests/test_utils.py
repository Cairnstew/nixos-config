"""Tests for my_project."""

import pytest

from my_project.utils import greet, sum_numbers


class TestGreet:
    """Tests for the greet function."""

    def test_greet_basic(self) -> None:
        """Test basic greeting."""
        result = greet("World")
        assert result == "Hello, World!"

    def test_greet_empty(self) -> None:
        """Test greeting with empty name."""
        result = greet("")
        assert result == "Hello, !"


class TestSumNumbers:
    """Tests for the sum_numbers function."""

    def test_sum_basic(self) -> None:
        """Test summing a list of numbers."""
        result = sum_numbers([1, 2, 3, 4, 5])
        assert result == 15

    def test_sum_empty(self) -> None:
        """Test summing an empty list."""
        result = sum_numbers([])
        assert result == 0

    def test_sum_single(self) -> None:
        """Test summing a single number."""
        result = sum_numbers([42])
        assert result == 42

"""Example module with some useful functionality."""

from typing import List


def greet(name: str) -> str:
    """Generate a greeting message.

    Args:
        name: The name to greet

    Returns:
        A greeting message
    """
    return f"Hello, {name}!"


def sum_numbers(numbers: List[int]) -> int:
    """Sum a list of numbers.

    Args:
        numbers: List of integers to sum

    Returns:
        The sum of all numbers
    """
    return sum(numbers)

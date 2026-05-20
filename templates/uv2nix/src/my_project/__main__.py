"""Main entry point for the application."""

import sys


def main() -> int:
    """Main entry point.

    Returns:
        Exit code (0 for success, non-zero for error)
    """
    print("Hello from my_project!")
    print(f"Arguments: {sys.argv[1:]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

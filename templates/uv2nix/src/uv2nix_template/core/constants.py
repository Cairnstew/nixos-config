from enum import Enum


class Environment(str, Enum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"


APP_NAME = "uv2nix-template"
VERSION = "0.1.0"

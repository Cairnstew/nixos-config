"""Windows autounattend.xml and apply-dsc.ps1 generation."""

from __future__ import annotations

from pathlib import Path

import yaml
from jinja2 import Environment, PackageLoader

from .models import DSCConfig, WindowsUnattendedConfig

env = Environment(loader=PackageLoader("ipxe_installer", "templates"))


def render_autounattend(
    config: WindowsUnattendedConfig,
    dsc_config: DSCConfig,
    dsc_download_url: str = "",
    image_index: int = 1,
) -> str:
    """Render autounattend.xml from template and config."""
    template = env.get_template("autounattend.xml.j2")
    return template.render(
        partition_index=config.partition_index,
        local_user=config.local_user,
        password=config.password,
        timezone=config.timezone,
        edition=config.edition,
        computer_name=config.computer_name,
        disable_recovery=config.disable_recovery,
        dsc_download_url=dsc_download_url,
        image_index=image_index,
    )


def render_apply_dsc_ps1(dsc_config: DSCConfig) -> str:
    """Render apply-dsc.ps1 from template and DSC config."""
    template = env.get_template("apply-dsc.ps1.j2")

    # Build DSC v3 YAML configuration
    dsc_yaml = _build_dsc_yaml(dsc_config)

    return template.render(dsc_config_yaml=dsc_yaml)


def _build_dsc_yaml(config: DSCConfig) -> str:
    """Build DSC v3 YAML configuration from structured config."""
    dsc: dict = {}

    if config.registry:
        dsc["registry"] = config.registry

    if config.features:
        dsc["windowsFeatures"] = {}
        for feature in config.features:
            dsc["windowsFeatures"][feature] = {"Ensure": "Present"}

    if config.packages:
        dsc["packages"] = {}
        for name, source in config.packages.items():
            dsc["packages"][name] = {"Source": source, "Ensure": "Present"}

    if config.ps_modules:
        dsc["psModules"] = {}
        for mod in config.ps_modules:
            dsc["psModules"][mod] = {"Ensure": "Present"}

    return yaml.dump(dsc, default_flow_style=False, indent=2)

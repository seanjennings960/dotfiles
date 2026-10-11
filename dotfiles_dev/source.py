"""Locate the personal configuration and repository checks, not a project."""

import os
from pathlib import Path


def source_root():
    return Path(os.environ.get("DOTFILES_SOURCE", Path(__file__).resolve().parents[1])).resolve()

"""Pytest configuration and shared fixtures."""

from pathlib import Path

import pytest


@pytest.fixture
def project_root() -> Path:
    """Return the project root directory."""
    return Path(__file__).parent.parent


@pytest.fixture
def sample_data_dir(project_root: Path) -> Path:
    """Return the path to sample test data directory."""
    return project_root / "tests" / "fixtures"


@pytest.fixture
def template_files_dir(project_root: Path) -> Path:
    """Return the path to SAS template files."""
    return project_root / "templatefiles"

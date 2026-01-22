"""Tests for CLI entry point."""

import pytest
from typer.testing import CliRunner

from qrp_report.cli import app


runner = CliRunner()


class TestCLI:
    """Test CLI commands."""

    def test_help_displays(self) -> None:
        """CLI shows help text."""
        result = runner.invoke(app, ["--help"])
        assert result.exit_code == 0
        assert "QRP Report" in result.stdout or "qrp" in result.stdout.lower()

    def test_version_flag(self) -> None:
        """CLI shows version."""
        result = runner.invoke(app, ["--version"])
        assert result.exit_code == 0

    def test_generate_requires_config(self) -> None:
        """Generate command requires config file."""
        result = runner.invoke(app, ["generate"])
        # Should fail without config
        assert result.exit_code != 0

    def test_list_plugins_command(self) -> None:
        """List-plugins command shows available plugins."""
        result = runner.invoke(app, ["list-plugins"])
        assert result.exit_code == 0
        # Should list registered plugins
        assert "T1" in result.stdout
        assert "T2L1" in result.stdout
        assert "T2L2" in result.stdout
        assert "T4L1" in result.stdout
        assert "T4L2" in result.stdout

    def test_validate_requires_config(self) -> None:
        """Validate command requires config file."""
        result = runner.invoke(app, ["validate"])
        # Should fail without config
        assert result.exit_code != 0

    def test_validate_nonexistent_file(self) -> None:
        """Validate command errors on nonexistent file."""
        result = runner.invoke(app, ["validate", "nonexistent.yaml"])
        assert result.exit_code != 0
        assert "not found" in result.stdout.lower() or "error" in result.stdout.lower()

    def test_generate_nonexistent_file(self) -> None:
        """Generate command errors on nonexistent file."""
        result = runner.invoke(app, ["generate", "nonexistent.yaml"])
        assert result.exit_code != 0
        assert "not found" in result.stdout.lower() or "error" in result.stdout.lower()

"""Command-line interface for QRP Report."""

from typing import Annotated, Optional
from pathlib import Path

import typer
from rich.console import Console

from qrp_report import __version__

app = typer.Typer(
    name="qrp-report",
    help="QRP Report - Quality Review Protocol Report Generation Tool",
    no_args_is_help=True,
)
console = Console()


def version_callback(value: bool) -> None:
    """Print version and exit."""
    if value:
        console.print(f"qrp-report version {__version__}")
        raise typer.Exit()


@app.callback()
def main(
    version: Annotated[
        Optional[bool],
        typer.Option(
            "--version",
            "-v",
            help="Show version and exit.",
            callback=version_callback,
            is_eager=True,
        ),
    ] = None,
) -> None:
    """QRP Report - Quality Review Protocol Report Generation Tool."""
    pass


@app.command()
def run(
    config: Annotated[
        Path,
        typer.Argument(help="Path to configuration file (YAML or SAS dataset)"),
    ],
    output_dir: Annotated[
        Optional[Path],
        typer.Option("--output", "-o", help="Output directory for reports"),
    ] = None,
) -> None:
    """Generate QRP reports from configuration."""
    console.print(f"[bold]QRP Report[/bold] v{__version__}")
    console.print(f"Config: {config}")
    console.print(f"Output: {output_dir or 'default'}")
    console.print("[yellow]Report generation not yet implemented[/yellow]")


@app.command()
def validate(
    config: Annotated[
        Path,
        typer.Argument(help="Path to configuration file to validate"),
    ],
) -> None:
    """Validate a configuration file without generating reports."""
    console.print(f"[bold]Validating[/bold]: {config}")
    console.print("[yellow]Validation not yet implemented[/yellow]")


@app.command()
def init(
    output_dir: Annotated[
        Path,
        typer.Argument(help="Directory to create sample configuration"),
    ] = Path("."),
) -> None:
    """Create a sample configuration file."""
    console.print(f"[bold]Creating sample config in[/bold]: {output_dir}")
    console.print("[yellow]Init not yet implemented[/yellow]")


@app.command()
def info() -> None:
    """Show information about available report types and configuration options."""
    console.print("[bold]QRP Report Types[/bold]")
    console.print("  T1   - Background rates")
    console.print("  T2L1 - Exposures and follow-up (Level 1)")
    console.print("  T2L2 - Effect estimates (Level 2)")
    console.print("  T4L1 - Pregnancy Level 1")
    console.print("  T4L2 - Pregnancy Level 2")
    console.print("\n[yellow]Detailed info not yet implemented[/yellow]")


if __name__ == "__main__":
    app()

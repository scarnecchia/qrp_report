"""Command-line interface for QRP Report.

Provides commands for report generation and plugin management.
"""

from __future__ import annotations

from pathlib import Path
from typing import Annotated, Optional

import typer
from rich.console import Console
from rich.table import Table

from qrp_report import __version__
from qrp_report.driver import ReportDriver
from qrp_report.config.loader import load_config


app = typer.Typer(
    name="qrp-report",
    help="QRP Report: Generate standardized regulatory reports from distributed data.",
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
            "-V",
            callback=version_callback,
            is_eager=True,
            help="Show version and exit.",
        ),
    ] = None,
) -> None:
    """QRP Report: Generate standardized regulatory reports."""
    pass


@app.command()
def generate(
    config_path: Annotated[
        Path,
        typer.Argument(
            help="Path to report configuration file (YAML or JSON).",
        ),
    ],
    data_path: Annotated[
        Path,
        typer.Option(
            "--data",
            "-d",
            help="Path to input data directory.",
        ),
    ] = Path("."),
    output_path: Annotated[
        Path,
        typer.Option(
            "--output",
            "-o",
            help="Path for output files.",
        ),
    ] = Path("output"),
    verbose: Annotated[
        bool,
        typer.Option(
            "--verbose",
            "-v",
            help="Enable verbose output.",
        ),
    ] = False,
) -> None:
    """Generate a report from configuration file."""
    # Validate paths
    if not config_path.exists():
        console.print(f"[red]Error:[/] Configuration file not found: {config_path}")
        raise typer.Exit(code=1)

    if not data_path.exists():
        console.print(f"[red]Error:[/] Data directory not found: {data_path}")
        raise typer.Exit(code=1)

    try:
        # Load configuration
        config, errors = load_config(config_path)

        if errors:
            for error in errors:
                console.print(f"[yellow]Warning:[/] {error.message}")

        if config is None:
            console.print("[red]Error:[/] Failed to load configuration")
            raise typer.Exit(code=1)

        if verbose:
            console.print(f"[blue]Loaded config:[/] {config_path}")
            console.print(f"[blue]Report type:[/] {config.reporttype}")
            console.print(f"[blue]Data partners:[/] {len(config.dpinfo)}")

        # Create output directory
        output_path.mkdir(parents=True, exist_ok=True)

        # Generate report
        driver = ReportDriver()

        if verbose:
            console.print("[blue]Generating report...[/]")

        result = driver.generate_report(
            config=config,
            data_path=data_path,
            output_path=output_path,
        )

        # Report results
        console.print(f"[green]Generated {len(result.tables)} tables[/]")
        console.print(f"[green]Generated {len(result.figures)} figures[/]")
        console.print(f"[green]Output written to:[/] {output_path}")

        if result.warnings:
            console.print("[yellow]Warnings:[/]")
            for warning in result.warnings:
                console.print(f"  - {warning}")

    except Exception as e:
        console.print(f"[red]Error:[/] {e}")
        raise typer.Exit(code=1)


@app.command("list-plugins")
def list_plugins_cmd() -> None:
    """List available report type plugins."""
    driver = ReportDriver()
    types = driver.available_report_types()

    table = Table(title="Available Report Types")
    table.add_column("Type", style="cyan")
    table.add_column("Description", style="green")

    descriptions = {
        "T1": "Background rates analysis",
        "T2L1": "Exposure and follow-up analysis",
        "T2L2": "Effect estimates with PS methods",
        "T4L1": "Pregnancy-specific background rates",
        "T4L2": "Pregnancy-specific effect estimates",
    }

    for report_type in sorted(types):
        desc = descriptions.get(report_type, "")
        table.add_row(report_type, desc)

    console.print(table)


@app.command("validate")
def validate_config_cmd(
    config_path: Annotated[
        Path,
        typer.Argument(
            help="Path to configuration file to validate.",
        ),
    ],
) -> None:
    """Validate a report configuration file."""
    if not config_path.exists():
        console.print(f"[red]Error:[/] Configuration file not found: {config_path}")
        raise typer.Exit(code=1)

    try:
        config, load_errors = load_config(config_path)

        if load_errors:
            console.print("[yellow]Loading warnings:[/]")
            for error in load_errors:
                console.print(f"  - {error.message}")

        if config is None:
            console.print("[red]Error:[/] Failed to load configuration")
            raise typer.Exit(code=1)

        driver = ReportDriver()
        validation_errors = driver.validate_config(config)

        if validation_errors:
            console.print("[red]Validation errors:[/]")
            for error in validation_errors:
                console.print(f"  - {error}")
            raise typer.Exit(code=1)

        console.print("[green]Configuration is valid.[/]")
        console.print(f"  Report ID: {config.reportid}")
        console.print(f"  Report Type: {config.reporttype}")
        console.print(f"  Data Partners: {len(config.dpinfo)}")
        console.print(f"  Groups: {len(config.groups)}")

    except typer.Exit:
        raise
    except Exception as e:
        console.print(f"[red]Error loading config:[/] {e}")
        raise typer.Exit(code=1)


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
    """Generate QRP reports from configuration (alias for generate)."""
    # Delegate to generate command
    generate(
        config_path=config,
        data_path=Path("."),
        output_path=output_dir or Path("output"),
        verbose=False,
    )


if __name__ == "__main__":
    app()

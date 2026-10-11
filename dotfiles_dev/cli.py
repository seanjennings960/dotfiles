"""Click command registration for local work and repository checks."""

import subprocess

import click

from . import activation, testing
from .languages import languages
from .local import Local, environment
from .process import replace
from .source import source_root
from .windows import windows
from .workspace import Workspace


@click.group(invoke_without_command=True)
@click.option("--workspace", type=click.Path(file_okay=False), help="Override workspace discovery.")
@click.pass_context
def cli(ctx, workspace):
    """Enter local work, inspect the environment, or run a command."""
    ctx.meta["environment"] = environment()
    ctx.obj = Workspace.discover(workspace)
    if ctx.invoked_subcommand is None:
        Local(ctx.meta["environment"]).enter(ctx.obj)


@cli.group(invoke_without_command=True)
@click.pass_context
def env(ctx):
    """Inspect or enter an environment."""
    if ctx.invoked_subcommand is None:
        click.echo(f"Environment: {ctx.meta['environment']}")
        click.echo(f"Workspace: {ctx.obj.root}")
        click.echo(f"Directory: {ctx.obj.cwd}")
        if not ctx.obj.git_metadata_available:
            click.echo("Git metadata: unavailable; workspace discovered from its .git file")


@env.command()
@click.argument("target", type=click.Choice(["host", "container"]))
@click.pass_context
def enter(ctx, target):
    """Enter or reconnect to an environment."""
    current = ctx.meta["environment"]
    if target != current:
        raise click.ClickException(f"Cannot enter {target} from {current}: cross-environment entry "
                                   "is not implemented. No command was run.")
    Local(current).enter(ctx.obj)


@env.command()
def rebuild():
    """Managed container recreation is not yet available."""
    raise click.ClickException("Rebuild is unsupported. No command was run.")


@cli.command("exec", context_settings={"ignore_unknown_options": True, "help_option_names": []})
@click.argument("command", nargs=-1, required=True, type=click.UNPROCESSED)
@click.pass_obj
def execute(workspace, command):
    """Run COMMAND directly, preserving arguments, streams, terminal and status."""
    replace(command, workspace.cwd)


@cli.command("test", context_settings={"ignore_unknown_options": True, "allow_extra_args": True,
                                      "help_option_names": []})
@click.argument("args", nargs=-1, type=click.UNPROCESSED)
def test(args):
    """Run this repository's pytest suite with forwarded ARGS."""
    testing.run(args)


@cli.command()
def activate():
    """Activate personal defaults offline, preserving existing configuration."""
    try:
        activation.activate(source_root())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise click.ClickException(f"Activation failed: {error}") from error
    click.echo("Dotfiles activated. Start a fresh shell to load the startup hooks.")


cli.add_command(windows)
cli.add_command(languages)


def main():
    cli()

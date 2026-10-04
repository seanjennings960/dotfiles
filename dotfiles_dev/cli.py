"""Click command registration for host work and repository checks."""

import click

from .host import Host, environment
from .process import replace
from .workspace import Workspace
from . import testing


@click.group(invoke_without_command=True)
@click.option("--workspace", type=click.Path(file_okay=False), help="Override workspace discovery.")
@click.pass_context
def cli(ctx, workspace):
    """Enter host work, inspect the environment, or run a command."""
    environment()
    ctx.obj = Workspace.discover(workspace)
    if ctx.invoked_subcommand is None:
        Host().enter(ctx.obj)


@cli.group(invoke_without_command=True)
@click.pass_context
def env(ctx):
    """Inspect or enter an environment."""
    if ctx.invoked_subcommand is None:
        click.echo("Environment: host")
        click.echo(f"Workspace: {ctx.obj.root}")
        click.echo(f"Directory: {ctx.obj.cwd}")
        if not ctx.obj.git_metadata_available:
            click.echo("Git metadata: unavailable; workspace discovered from its .git file")


@env.command()
@click.argument("target", type=click.Choice(["host", "container"]))
@click.pass_obj
def enter(workspace, target):
    """Enter or reconnect to an environment."""
    if target != "host":
        raise click.ClickException("Container entry is not implemented. No host command was run.")
    Host().enter(workspace)


@env.command()
def rebuild():
    """Container recreation is not available in the host launcher."""
    raise click.ClickException("Rebuild is unsupported on the host. No host command was run.")


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


def main():
    cli()

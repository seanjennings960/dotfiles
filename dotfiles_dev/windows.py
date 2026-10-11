"""Move existing tmux windows while retaining the launcher's primary workspace."""

import click

from .local import ENVIRONMENT_OPTION, WORKSPACE_OPTION, Local, environment


@click.group()
def windows():
    """Manage running tmux windows in the invoking environment."""


@windows.command("pop")
@click.option("--pane", required=True, help="Source pane ID, for example %0.")
@click.option("--client", default=None, help="Attached client to switch to the new session.")
@click.option("--select", default=None, help="Space-separated indexes from the tmux prompt.")
@click.argument("indexes", nargs=-1, type=click.IntRange(min=0))
def pop(pane, client, select, indexes):
    """Move INDEXES into a new session, preserving the running pane processes."""
    if select is not None:
        if indexes or not select.split() or any(not x.isdecimal() for x in select.split()):
            raise click.ClickException("Provide space-separated, nonnegative window indexes.")
        indexes = tuple(map(int, select.split()))
    if not indexes or len(set(indexes)) != len(indexes):
        raise click.ClickException("Provide distinct window indexes.")
    local = Local(environment())
    source = local.run("display-message", "-p", "-t", pane, "#{session_id}").stdout.strip()
    rows = local.run("list-windows", "-t", source, "-F", "#{window_index}:#{window_id}")
    available = dict(line.split(":", 1) for line in rows.stdout.splitlines())
    if any(str(index) not in available for index in indexes):
        raise click.ClickException("A requested window does not exist in the source session.")
    if client:
        clients = local.run("list-clients", "-t", source, "-F", "#{client_name}").stdout.splitlines()
        if client not in clients:
            raise click.ClickException("The selected client is not attached to the source session.")
    metadata = {key: local.metadata(source, key) for key in (WORKSPACE_OPTION, ENVIRONMENT_OPTION)}
    if metadata[ENVIRONMENT_OPTION] and metadata[ENVIRONMENT_OPTION] != local.environment:
        raise click.ClickException("The source session belongs to another environment.")
    destination = local.run("new-session", "-dP", "-F", "#{session_id}").stdout.strip()
    placeholder = local.run("display-message", "-p", "-t", destination, "#{window_id}").stdout.strip()
    moved = []
    try:
        if client:
            local.run("switch-client", "-c", client, "-t", destination)
        for index in indexes:
            window = available[str(index)]
            local.run("move-window", "-d", "-s", window, "-t", destination + ":")
            moved.append(window)
        # Partial moves leave the original primary discoverable. Moving every
        # window transfers its identity; never create two primary matches.
        if len(indexes) == len(available):
            for key, value in metadata.items():
                if value:
                    local.run("set-option", "-t", destination, key, value)
        local.run("kill-window", "-t", placeholder)
        local.run("select-window", "-t", moved[0])
    except click.ClickException:
        if not moved:
            if client:
                local.run("switch-client", "-c", client, "-t", source, check=False)
            local.run("kill-session", "-t", destination, check=False)
        else:
            click.echo(f"Partial move: windows {moved} remain alive in {destination}.", err=True)
        raise
    click.echo(f"Moved {len(moved)} window(s) to {destination}.")

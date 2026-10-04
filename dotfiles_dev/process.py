"""Replace the launcher so commands inherit descriptors, signals and the TTY."""

import os

import click


def replace(argv, cwd, environment=None):
    try:
        os.chdir(cwd)
        os.execvpe(str(argv[0]), [str(arg) for arg in argv], environment or dict(os.environ))
    except FileNotFoundError:
        click.echo(f"Missing executable: {argv[0]}. Install it explicitly.", err=True)
        raise SystemExit(127)
    except PermissionError as error:
        click.echo(str(error), err=True)
        raise SystemExit(126)
    except OSError as error:
        raise click.ClickException(str(error))

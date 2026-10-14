"""Local sessions are identified by workspace and environment in tmux metadata."""

import hashlib
import os
import shutil
import subprocess

import click

SERVER = "dotfiles-dev"
WORKSPACE_OPTION = "@dev_workspace"
ENVIRONMENT_OPTION = "@dev_environment"


class Local:
    def __init__(self, environment):
        self.environment = environment
        self.tmux = shutil.which("tmux")
        if self.tmux is None:
            raise click.ClickException("Missing tool: tmux. Install it explicitly during environment setup.")
        # Tests use an isolated socket through this explicit override.
        socket = os.environ.get("DOTFILES_TMUX_SOCKET")
        self.argv = [self.tmux, "-S", socket] if socket else [self.tmux, "-L", SERVER]

    def run(self, *args, check=True):
        result = subprocess.run([*self.argv, *args], capture_output=True, text=True, check=False)
        if check and result.returncode:
            raise click.ClickException(result.stderr.strip() or "tmux command failed")
        return result

    def sessions(self):
        result = self.run("list-sessions", "-F", "#{session_id}", check=False)
        if result.returncode:
            # tmux uses status 1 both for an absent server and for other errors.
            if "no server running" in result.stderr or "No such file or directory" in result.stderr:
                return []
            raise click.ClickException(result.stderr.strip() or "Cannot inspect tmux sessions")
        return result.stdout.splitlines()

    def metadata(self, session, option):
        return self.run("show-options", "-qv", "-t", session, option).stdout.rstrip("\n")

    def find(self, workspace):
        for session in self.sessions():
            if (self.metadata(session, WORKSPACE_OPTION) == str(workspace.root)
                    and self.metadata(session, ENVIRONMENT_OPTION) == self.environment):
                return session
        return None

    def ensure(self, workspace):
        existing = self.find(workspace)
        if existing:
            return existing
        name = f"dev-{self.environment}-" + hashlib.sha256(os.fsencode(workspace.root)).hexdigest()
        # Creation is atomic in tmux. A conflicting untagged session is not ours.
        created = self.run("new-session", "-dP", "-F", "#{session_id}", "-s", name,
                           "-c", str(workspace.cwd), check=False)
        if created.returncode:
            # Another launcher may have completed creation since our initial lookup.
            existing = self.find(workspace)
            if existing:
                return existing
            raise click.ClickException(created.stderr.strip() or "Cannot create host session")
        session = created.stdout.strip()
        for option, value in ((WORKSPACE_OPTION, str(workspace.root)), (ENVIRONMENT_OPTION, self.environment)):
            self.run("set-option", "-t", session, option, value)
        return session

    def enter(self, workspace):
        if not os.isatty(0) or not os.isatty(1):
            raise click.ClickException("Entry requires an interactive terminal. Use dev exec for commands.")
        session = self.ensure(workspace)
        # Switch an attached client on our server; never detach a client on another server.
        same_server = False
        if os.environ.get("TMUX"):
            current = os.environ["TMUX"].rsplit(",", 2)[0]
            target = self.run("display-message", "-p", "-t", session, "#{socket_path}").stdout.strip()
            same_server = current == target
        if same_server:
            self.run("switch-client", "-t", session)
        else:
            environment = dict(os.environ)
            environment.pop("TMUX", None)
            replace([*self.argv, "attach-session", "-t", session], workspace.cwd, environment)


def environment():
    """An explicitly unsupported context must never silently run on the host."""
    selected = os.environ.get("DEV_ENVIRONMENT", "host")
    if selected not in {"host", "container"}:
        raise click.ClickException(f"Unsupported environment: {selected}. No host command was run.")
    return selected


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

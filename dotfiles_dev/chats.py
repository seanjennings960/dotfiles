"""Browse OpenCode history through its database CLI, without a second store."""

from datetime import datetime, timezone
import json
import subprocess

import click


def sql_text(value):
    # OpenCode's CLI accepts SQL but exposes no parameter binding interface.
    return "'" + value.replace("'", "''") + "'"


def query(workspace, sql):
    """Run one SELECT via `opencode db [query]` and decode its JSON rows."""
    try:
        result = subprocess.run(
            ["opencode", "db", sql, "--format", "json"], cwd=workspace.cwd,
            capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
    except FileNotFoundError:
        raise click.ClickException("Missing tool: opencode. Install it explicitly to read chat history.")
    except subprocess.TimeoutExpired:
        raise click.ClickException("OpenCode history query timed out after 60 seconds.")
    except OSError as error:
        raise click.ClickException(f"Cannot run opencode: {error}")
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit status {result.returncode}"
        raise click.ClickException(f"OpenCode history query failed: {detail}")
    try:
        rows = json.loads(result.stdout)
    except ValueError:
        rows = None
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise click.ClickException(
            "Invalid JSON rows from opencode. Requires `opencode db '<SQL>' --format json`."
        )
    return rows


def sessions(workspace, *, here=False, limit=20, offset=0, term=None):
    conditions = []
    if here:
        conditions.append(f"s.directory = {sql_text(str(workspace.root))}")
    if term is not None:
        needle = f"lower({sql_text(term)})"
        # Search decoded text, not JSON serialization (which escapes newlines).
        # json_tree also finds strings nested in tool inputs and outputs.
        conditions.append(f"""(
            instr(lower(s.title), {needle}) > 0 OR EXISTS (
                SELECT 1 FROM part p, json_tree(p.data) content
                WHERE p.session_id = s.id AND content.type = 'text'
                  AND instr(lower(content.value), {needle}) > 0
            )
        )""")
    where = " AND ".join(conditions) or "1"
    return query(workspace, f"""
        SELECT s.*, (SELECT count(*) FROM message m WHERE m.session_id = s.id) AS message_count
        FROM session s WHERE {where}
        ORDER BY s.time_updated DESC, s.id DESC LIMIT {limit} OFFSET {offset}
    """)


def transcript(workspace, identifier):
    value = sql_text(identifier)
    rows = query(workspace, f"""
        SELECT * FROM session WHERE substr(id, 1, length({value})) = {value}
        ORDER BY (id = {value}) DESC, id LIMIT 2
    """)
    if not rows:
        raise click.ClickException(f"No OpenCode session matches {identifier!r}.")
    if len(rows) > 1 and rows[0]["id"] != identifier:
        examples = ", ".join(row["id"] for row in rows)
        raise click.ClickException(f"Ambiguous session prefix {identifier!r}: {examples}. Use a full ID.")
    session = rows[0]
    session_id = sql_text(session["id"])
    messages = query(workspace, f"""
        SELECT * FROM message WHERE session_id = {session_id} ORDER BY time_created, id
    """)
    parts = query(workspace, f"""
        SELECT * FROM part WHERE session_id = {session_id} ORDER BY message_id, id
    """)
    try:
        by_message = {}
        for message in messages:
            message["data"] = json.loads(message["data"])
            if not isinstance(message["data"], dict):
                raise ValueError("message data is not an object")
            message["parts"] = []
            by_message[message["id"]] = message
        for part in parts:
            part["data"] = json.loads(part["data"])
            if not isinstance(part["data"], dict):
                raise ValueError("part data is not an object")
            # A live session may gain a message between these reads.
            if part["message_id"] in by_message:
                by_message[part["message_id"]]["parts"].append(part)
    except (ValueError, TypeError) as error:
        raise click.ClickException(f"Invalid OpenCode transcript data: {error}")
    return {"session": session, "messages": messages}


def emit_json(value):
    click.echo(json.dumps(value, ensure_ascii=False, indent=2))


def timestamp(milliseconds):
    return datetime.fromtimestamp(milliseconds / 1000, timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def display_sessions(rows, as_json):
    if as_json:
        emit_json(rows)
        return
    if not rows:
        click.echo("No matching OpenCode sessions.")
    for row in rows:
        title = " ".join(row["title"].split())
        click.echo(f"{row['id']}  {title}")
        click.echo(f"  {timestamp(row['time_updated'])} | {row['message_count']} messages | {row['directory']}")
        if row.get("parent_id"):
            click.echo(f"  Parent: {row['parent_id']}")
        if row.get("time_archived") is not None:
            click.echo("  Archived")


def display_transcript(document, all_parts):
    session = document["session"]
    click.echo(f"# {session['title']}\n\nSession: {session['id']}\nDirectory: {session['directory']}")
    if session.get("parent_id"):
        click.echo(f"Parent: {session['parent_id']}")
    if not document["messages"]:
        click.echo("\nNo messages in this session.")
    for message in document["messages"]:
        data = message["data"]
        click.echo(f"\n## {data.get('role', 'unknown')} | {timestamp(message['time_created'])} | {message['id']}")
        if data.get("error"):
            click.echo("\nError: " + json.dumps(data["error"], ensure_ascii=False))
        for part in message["parts"]:
            content = part["data"]
            kind = content.get("type", "unknown")
            click.echo()
            if all_parts:
                emit_json(part)
            elif kind == "text":
                click.echo(content.get("text", ""))
            elif kind == "tool":
                state = content.get("state", {})
                click.echo(f"[Tool: {content.get('tool', 'unknown')} — {state.get('status', 'unknown')}]")
            elif kind == "file":
                click.echo(f"[File: {content.get('filename') or content.get('mime', 'attachment')}]")
            else:
                click.echo(f"[{kind}]")


def listing_options(command):
    for option in (
        click.option("--here", is_flag=True, help="Only the selected workspace (exact directory match)."),
        click.option("--limit", "-n", type=click.IntRange(min=1), default=20, show_default=True,
                     help="Maximum number of sessions."),
        click.option("--offset", type=click.IntRange(min=0), default=0, show_default=True,
                     help="Skip this many sessions."),
        click.option("--json", "as_json", is_flag=True, help="Print structured JSON."),
    ):
        command = option(command)
    return command


@click.group(invoke_without_command=True)
@click.pass_context
def chats(ctx):
    """List, search, and read local OpenCode sessions.

    With no subcommand, list the 20 most recently updated sessions across all
    projects. Use list --here to restrict results to the selected workspace.
    """
    if ctx.invoked_subcommand is None:
        ctx.invoke(list_sessions)


@chats.command("list")
@listing_options
@click.pass_obj
def list_sessions(workspace, here, limit, offset, as_json):
    """List sessions, newest activity first (including children and archived)."""
    display_sessions(sessions(workspace, here=here, limit=limit, offset=offset), as_json)


@chats.command()
@click.argument("text")
@listing_options
@click.pass_obj
def search(workspace, text, here, limit, offset, as_json):
    """Find TEXT in titles or message parts, including reasoning and tool data.

    TEXT is a literal substring, not SQL or a wildcard pattern. Case folding
    follows SQLite's lower() (ASCII). Each matching session appears once.
    """
    if not text.strip():
        raise click.BadParameter("Search text must not be empty.", param_hint="TEXT")
    display_sessions(sessions(workspace, here=here, limit=limit, offset=offset, term=text), as_json)


@chats.command()
@click.argument("session")
@click.option("--all-parts", is_flag=True, help="Render every part as JSON, including reasoning and tool data.")
@click.option("--json", "as_json", is_flag=True, help="Export all session, message, and part records as JSON.")
@click.pass_obj
def show(workspace, session, all_parts, as_json):
    """Read SESSION (full ID or unique prefix) in chronological message order.

    Text output includes message text and summaries of other parts. --json
    always includes all stored data, regardless of --all-parts.
    """
    document = transcript(workspace, session)
    if as_json:
        emit_json(document)
    else:
        display_transcript(document, all_parts)

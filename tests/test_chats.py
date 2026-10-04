"""Production CLI against a disposable SQLite-backed OpenCode stand-in."""

import json
from pathlib import Path
import sqlite3
import sys

import pytest


@pytest.fixture
def history(tmp_path, workspace, env):
    database = tmp_path / "history.db"
    connection = sqlite3.connect(database)
    connection.executescript("""
        CREATE TABLE session (id TEXT PRIMARY KEY, title TEXT, directory TEXT, project_id TEXT,
                              parent_id TEXT, time_created INTEGER, time_updated INTEGER,
                              time_archived INTEGER);
        CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER,
                              time_updated INTEGER, data TEXT);
        CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT,
                           time_created INTEGER, time_updated INTEGER, data TEXT);
    """)
    other = tmp_path / "someone's worktree"
    other.mkdir()
    connection.executemany("INSERT INTO session VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [
        ("ses_alpha", "O'Brien's 100%_ migration", str(workspace), "project", None, 1000, 4000, None),
        ("ses_alpine", "Other work", str(other), "project", None, 1000, 3000, None),
        ("ses_alpha_child", "Archived child", str(workspace), "project", "ses_alpha", 1000, 3000, 4000),
        ("ses_empty", "Empty session", str(other), "project", None, 1000, 2000, None),
    ])
    # Insert out of order, with IDs that do not sort chronologically.
    connection.executemany("INSERT INTO message VALUES (?, ?, ?, ?, ?)", [
        ("msg_a", "ses_alpha", 2000, 2000, json.dumps({"role": "assistant", "modelID": "test"})),
        ("msg_z", "ses_alpha", 1000, 1000, json.dumps({"role": "user"})),
    ])
    parts = [
        ("prt_z", "msg_a", {"type": "text", "text": "Answer: café"}),
        ("prt_d", "msg_a", {"type": "future-part", "extra": {"preserve": [1, 2]}}),
        ("prt_c", "msg_a", {"type": "file", "filename": "notes.pdf", "url": "data:application/pdf;base64,eA=="}),
        ("prt_b", "msg_a", {"type": "tool", "tool": "bash", "state": {
            "status": "completed", "input": {"command": "printf tool-input"}, "output": "tool-output\nnext line",
        }}),
        ("prt_a", "msg_a", {"type": "reasoning", "text": "private reasoning"}),
        ("prt_user", "msg_z", {"type": "text", "text": "Question\nsecond line café"}),
    ]
    for index, (identifier, message, data) in enumerate(parts):
        connection.execute("INSERT INTO part VALUES (?, ?, ?, ?, ?, ?)",
                           (identifier, message, "ses_alpha", 1000 + index, 2000, json.dumps(data)))
    connection.commit()
    connection.close()

    binary = tmp_path / "opencode"
    binary.write_text(f"#!{sys.executable}\n" + '''
import json
import os
from pathlib import Path
import sqlite3
import sys

assert sys.argv[1] == "db" and sys.argv[3:] == ["--format", "json"], sys.argv
with open(os.environ["CHAT_TEST_LOG"], "a") as log:
    log.write(json.dumps({"argv": sys.argv[1:], "cwd": os.getcwd()}) + "\\n")
if "CHAT_TEST_FAILURE" in os.environ:
    print(os.environ["CHAT_TEST_FAILURE"])
    sys.exit(int(os.environ.get("CHAT_TEST_STATUS", "0")))
sql = sys.argv[2]
assert sql.lstrip().startswith("SELECT "), sql
db = sqlite3.connect(Path(os.environ["CHAT_TEST_DB"]).as_uri() + "?mode=ro", uri=True)
db.row_factory = sqlite3.Row
print(json.dumps([dict(row) for row in db.execute(sql)]))
''')
    binary.chmod(0o755)
    env["PATH"] = f"{tmp_path}:{env['PATH']}"
    env["CHAT_TEST_DB"] = str(database)
    env["CHAT_TEST_LOG"] = str(tmp_path / "calls.jsonl")
    return other


def test_help_without_opencode(run, launcher, env):
    env["PATH"] = "/nonexistent"
    result = run([*launcher, "--workspace", ".", "chats", "--help"])
    assert all(command in result.stdout for command in ("list", "search", "show"))


def test_default_list_and_paging(run, launcher, history):
    result = run([*launcher, "chats"]).stdout
    assert result.index("ses_alpha ") < result.index("ses_alpine ") < result.index("ses_alpha_child ")
    assert "2 messages" in result
    assert "Parent: ses_alpha" in result and "Archived" in result
    rows = json.loads(run([*launcher, "chats", "list", "--limit", "2", "--offset", "1", "--json"]).stdout)
    assert [row["id"] for row in rows] == ["ses_alpine", "ses_alpha_child"]


def test_workspace_filter_and_query_cwd(run, launcher, history, workspace, env):
    nested = workspace / "nested"
    nested.mkdir()
    rows = json.loads(run([*launcher, "--workspace", workspace, "chats", "list", "--here", "--json"],
                          cwd=nested).stdout)
    assert [row["id"] for row in rows] == ["ses_alpha", "ses_alpha_child"]
    rows = json.loads(run([*launcher, "--workspace", history, "chats", "list", "--here", "--json"]).stdout)
    assert [row["id"] for row in rows] == ["ses_alpine", "ses_empty"]
    calls = [json.loads(line) for line in Path(env["CHAT_TEST_LOG"]).read_text().splitlines()]
    assert [call["cwd"] for call in calls] == [str(nested), str(history)]


@pytest.mark.parametrize("term", ["O'BRIEN", "100%_", "Question\nsecond line", "café", "private reasoning",
                                 "tool-input", "tool-output\nnext line", "notes.pdf"])
def test_search_decoded_content(run, launcher, history, term):
    rows = json.loads(run([*launcher, "chats", "search", term, "--json"]).stdout)
    assert [row["id"] for row in rows] == ["ses_alpha"]


@pytest.mark.parametrize("term", ["%' OR 1=1 --", "'; DROP TABLE session; --", "100__", "CAFÉ"])
def test_search_literal_input(run, launcher, history, term):
    assert json.loads(run([*launcher, "chats", "search", term, "--json"]).stdout) == []
    assert len(json.loads(run([*launcher, "chats", "list", "--json"]).stdout)) == 4


def test_search_workspace_and_paging(run, launcher, history):
    assert json.loads(run([*launcher, "--workspace", history, "chats", "search", "café", "--here", "--json"]).stdout) == []
    assert json.loads(run([*launcher, "chats", "search", "café", "--offset", "1", "--json"]).stdout) == []


def test_complete_transcript_and_order(run, launcher, history):
    # Exact ID wins over the longer ses_alpha_child match.
    result = run([*launcher, "chats", "show", "ses_alpha", "--json"])
    document = json.loads(result.stdout)
    assert document["session"]["id"] == "ses_alpha"
    messages = document["messages"]
    assert [message["id"] for message in messages] == ["msg_z", "msg_a"]
    assert messages[0]["data"] == {"role": "user"}
    assert messages[1]["data"]["modelID"] == "test"
    assert [part["id"] for part in messages[1]["parts"]] == ["prt_a", "prt_b", "prt_c", "prt_d", "prt_z"]
    assert messages[1]["parts"][1]["data"]["state"]["output"] == "tool-output\nnext line"
    assert messages[1]["parts"][3]["data"] == {"type": "future-part", "extra": {"preserve": [1, 2]}}
    assert not result.stderr


def test_readable_transcript_and_all_parts(run, launcher, history):
    text = run([*launcher, "chats", "show", "ses_alpha"]).stdout
    assert text.index("## user") < text.index("## assistant")
    assert "Question\nsecond line café" in text and "Answer: café" in text
    assert "[Tool: bash — completed]" in text and "[File: notes.pdf]" in text
    assert "[future-part]" in text and "[reasoning]" in text
    assert "private reasoning" not in text and "tool-output" not in text
    full = run([*launcher, "chats", "show", "ses_alpha", "--all-parts"]).stdout
    assert "private reasoning" in full and "tool-output" in full and "tool-input" in full


@pytest.mark.parametrize("identifier,error", [("ses_al", "Ambiguous session prefix"),
                                              ("missing", "No OpenCode session"),
                                              ("ses_%", "No OpenCode session"),
                                              ("' OR 1=1 --", "No OpenCode session")])
def test_invalid_session_id(run, launcher, history, identifier, error):
    result = run([*launcher, "chats", "show", identifier], check=False)
    assert result.returncode == 1 and error in result.stderr
    assert not result.stdout


def test_empty_history_and_unique_prefix(run, launcher, history):
    result = run([*launcher, "chats", "list", "--offset", "99"])
    assert result.stdout.strip() == "No matching OpenCode sessions."
    document = json.loads(run([*launcher, "chats", "show", "ses_e", "--json"]).stdout)
    assert document["session"]["id"] == "ses_empty" and document["messages"] == []
    assert "No messages" in run([*launcher, "chats", "show", "ses_e"]).stdout


@pytest.mark.parametrize("args", [["search", " "], ["list", "--limit", "0"], ["list", "--offset", "-1"]])
def test_invalid_options(run, launcher, args):
    result = run([*launcher, "chats", *args], check=False)
    assert result.returncode == 2 and "Invalid value" in result.stderr


@pytest.mark.parametrize("output,status,error", [("not json", "0", "Invalid JSON rows"),
                                                 ('{"error": true}', "0", "Invalid JSON rows"),
                                                 ("[1]", "0", "Invalid JSON rows"),
                                                 ("no such table: session", "1", "no such table: session")])
def test_opencode_errors(run, launcher, history, env, output, status, error):
    env["CHAT_TEST_FAILURE"] = output
    env["CHAT_TEST_STATUS"] = status
    result = run([*launcher, "chats"], check=False)
    assert result.returncode == 1 and error in result.stderr
    assert "Traceback" not in result.stderr and not result.stdout


def test_missing_opencode(run, launcher, env):
    env["PATH"] = "/nonexistent"
    result = run([*launcher, "--workspace", ".", "chats"], check=False)
    assert result.returncode == 1 and "Missing tool: opencode" in result.stderr

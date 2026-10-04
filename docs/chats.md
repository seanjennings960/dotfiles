# OpenCode chat history

`dev chats` reads the current user's OpenCode history through
`opencode db "<SQL>" --format json`. In OpenCode's help, `query` is the SQL
positional argument, not a literal subcommand. OpenCode must already be on PATH
and support this database command (verified with OpenCode 1.18.34).

## CLI

```sh
dev chats                              # 20 most recently updated sessions
dev chats list --limit 50 --offset 50   # next page, across all projects
dev chats list --here                  # this worktree only
dev --workspace ~/code/project chats list --here
dev chats search 'database migration'  # matching sessions, newest activity first
dev chats search 'migration' --here --json
dev chats show ses_abc                 # full ID or an unambiguous prefix
dev chats show ses_abc --all-parts      # reasoning, tool inputs/results, attachments, etc.
dev chats show ses_abc --json > session.json
```

Listing and search include archived and child/subagent sessions, identify their
parent when present, and order by last update with session ID as a tie-breaker.
`--limit` (also `-n`) defaults to 20; `--offset` defaults to zero. Paging reflects
the database at query time, so active sessions can move between pages.
`--here` matches the selected workspace's canonical directory exactly; it does
not merge distinct worktrees or include subdirectory sessions. Without `--here`,
listing and search cover all projects in the current user's database.

Search matches a literal substring in session titles and every string value in
message-part JSON, including text, reasoning, tool inputs/results, and attachment
metadata. Quotes, `%`, and `_` are literal characters. SQLite's `lower()` makes
ASCII searches case-insensitive; non-ASCII characters match case-sensitively.
Results contain each session once. Use `show` to read a matching transcript.

`show` sorts messages by creation time and ID, and parts by ID (OpenCode's part
ordering). It prints user/assistant text and labels other part types. Use
`--all-parts` for full part records or `--json` for a structured export. Redirect
output to save it, or pipe text to a pager such as `less`. A missing or ambiguous
ID is an error; an empty list/search is a successful result.

## JSON interface

- `list --json` and `search --json`: an array of session database rows, with an
  additional `message_count` field. No results produces `[]`.
- `show --json`: `{"session": {...}, "messages": [...]}`. Each message retains
  its database fields and has a `parts` array. Message and part `data` fields are
  decoded JSON objects. All metadata and part types are retained, including
  unknown types; timestamps remain Unix milliseconds.

This is a database-record export, not the `opencode import` format. For a portable
OpenCode import/export pair, use `opencode export <sessionID>` instead.

## Storage and environment

The command issues only generated SELECT queries against OpenCode's `session`,
`message`, and `part` tables. It invokes OpenCode directly without a shell and
quotes all search/ID/path values as SQL literals. There is no secondary database
or transcript cache. Missing OpenCode, failed queries (including incompatible
schemas), invalid JSON, and queries exceeding 60 seconds produce CLI errors.

OpenCode chooses its database using the caller's environment. The usual
macOS/Linux path is `~/.local/share/opencode/opencode.db`; inspect the actual
location with `opencode db path`. The CLI runs in `Workspace.cwd` and inherits
PATH, HOME, and XDG settings. Inside a container this is that container user's
OpenCode history. `--workspace` selects a directory for `--here`; it does not
select another database or connect to a host OpenCode instance.

Transcripts contain whatever OpenCode still stores, including compaction records;
pruned tool results cannot be recovered. A live transcript uses separate session,
message, and part queries and is not an atomic snapshot.

References: [OpenCode database CLI](https://opencode.ai/docs/cli/#db) and
[storage](https://opencode.ai/docs/troubleshooting/#storage).

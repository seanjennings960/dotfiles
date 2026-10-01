---
name: github-pr
description: Use for GitHub pull requests and PRs: inspect, create, review, comment on, update, check, approve, merge, close, or otherwise manage them with the GitHub CLI.
compatibility: Requires git and an authenticated GitHub CLI (`gh`).
---

# GitHub Pull Requests

Use `gh` as the GitHub capability layer and local `git` commands for working-tree and branch context.

## Safety

- Run `gh auth status` if authentication is uncertain. Never run `gh auth token`, print credentials, or put credentials in files or command arguments.
- Treat listing, viewing, diffing, and checking status as read-only. Do not create, edit, comment, review, ready, merge, close, reopen, or push unless the user requested that mutation.
- Never merge, close, reopen, approve, request changes, or submit review comments based only on an implied request. Confirm ambiguous intent.
- Preserve unrelated working-tree changes. Do not discard, overwrite, stage, or commit changes that are outside the requested work.
- Follow repository contribution instructions and pull request templates when present.

## Establish Context

Before a write operation, inspect the repository and the full branch delta:

```bash
git status --short
git branch --show-current
git remote -v
git diff
git diff --cached
git log --oneline -10
```

Use `gh repo view --json nameWithOwner,defaultBranchRef` to identify the repository and default base branch instead of assuming `main` or `master`. When operating outside the repository, pass `--repo OWNER/REPO` explicitly.

## Inspect Or Review A PR

1. Resolve the PR number or URL. If omitted, use the PR associated with the current branch when unambiguous.
2. Read metadata and discussion with `gh pr view`.
3. Read the complete patch with `gh pr diff` and inspect relevant surrounding source and tests locally.
4. Check CI with `gh pr checks`; inspect failed runs with `gh run view` when useful.
5. Evaluate correctness, regressions, security, edge cases, and missing tests. Do not focus primarily on style.
6. Report findings first, ordered by severity, with file and line references. State explicitly when no findings are discovered and mention residual testing risks.
7. Post a GitHub review only if requested. Re-read the intended review body before submitting it with `gh pr review`.

Useful metadata fields include:

```bash
gh pr view PR --json number,title,author,body,url,isDraft,baseRefName,headRefName,mergeable,reviewDecision,reviews,statusCheckRollup,files,commits
gh pr diff PR
gh pr checks PR
```

## Create A PR

1. Inspect status, unstaged and staged diffs, the current branch, its upstream, and all commits relative to the base branch.
2. If relevant changes are uncommitted, do not silently commit them. Ask whether they should be included unless the user explicitly requested a commit.
3. Run the repository's relevant tests and checks before pushing. Report anything that could not be run.
4. Push only the intended branch. Never force-push unless the user explicitly requests it and understands the impact.
5. Derive a concise title and body from the complete branch delta. Use the repository PR template when one exists. Include a summary and test results.
6. Create the PR with `gh pr create`, using `--draft` only when requested or when the work is knowingly incomplete.
7. Return the PR URL and summarize the submitted base, head, tests, and any remaining concerns.

Prefer a temporary body file over fragile multiline shell quoting:

```bash
gh pr create --base BASE --head BRANCH --title "TITLE" --body-file BODY_FILE
```

## Manage A PR

Use the narrowest `gh pr` command for the requested operation:

- `gh pr edit` for title, body, labels, reviewers, assignees, or milestone changes.
- `gh pr comment` for non-review discussion.
- `gh pr review` for approval, requested changes, or a formal review comment.
- `gh pr ready` to leave draft state.
- `gh pr update-branch` only after checking repository policy and conflicts.
- `gh pr merge` only after explicit approval, successful required checks, and confirmation of the requested merge strategy.
- `gh pr close` or `gh pr reopen` only when explicitly requested.

After any write operation, query the PR again and report its resulting state and URL.

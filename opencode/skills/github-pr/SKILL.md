---
name: github-pr
description: "Use for GitHub pull requests: inspect, create, review, update, check, merge, or close PRs with the GitHub CLI."
compatibility: Requires git and an authenticated GitHub CLI.
---

# GitHub pull requests

Use `gh` for GitHub operations and `git` for local history and changes.

## Establish context

- Identify the repository and default branch with
  `gh repo view --json nameWithOwner,defaultBranchRef`. Outside the checkout,
  pass `--repo OWNER/REPO` explicitly.
- Before a write, inspect `git status --short`, both staged and unstaged diffs,
  `git remote -v`, `git log --oneline -10`, and the complete branch diff from its base.
- Follow repository instructions and PR templates. Preserve unrelated local work.
- If authentication is uncertain, run `gh auth status`. Never print tokens or
  put credentials in files or command arguments. Setup guidance is in the README.

## Inspect and review

1. Resolve the PR number or URL. Read its metadata and discussion with `gh pr view`.
2. Read the full patch with `gh pr diff`, then relevant source and tests.
3. Inspect `gh pr checks`; investigate failures with `gh run view`.
4. Report correctness issues, regressions, and missing behavioral coverage first,
   with file and line references. State when no findings were found and distinguish
   completed verification from outstanding checks.

## Publish or change a PR

- Create, push, edit, comment, review, merge, or close only when requested. Clarify
  ambiguous write intent; inspection alone does not authorize a GitHub mutation.
- Before creating a PR, inspect all included commits and run relevant checks.
  Commit only when requested, stage intended files, and report checks not run.
- Use `gh pr create --base BASE --head BRANCH --title TITLE --body-file FILE`.
  Describe the complete delta and verification. Use a draft for known incomplete work.
- Use the narrowest `gh pr` operation: `edit`, `comment`, `review`, `ready`,
  `update-branch`, `merge`, `close`, or `reopen`. Re-read review text before posting.
- Merge only with explicit approval, successful required checks, and an agreed
  merge strategy. Never force-push without explicit authorization.
- Query the PR after a write and return its URL and resulting state.

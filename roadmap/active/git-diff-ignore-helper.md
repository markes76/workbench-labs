This is the long-lived integration PR for `git-diff-ignore-helper`.

## Summary
Use local git to inspect diffs and help build .gitignore patterns.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/git-diff-ignore-helper`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/git-diff-ignore-helper`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool can inspect a repository path and summarize changed files.
- [ ] Tool can test ignore patterns against paths.
- [ ] No destructive git commands are used.

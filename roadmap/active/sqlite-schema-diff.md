This is the long-lived integration PR for `sqlite-schema-diff`.

## Summary
Compare schemas across two SQLite database files.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/sqlite-schema-diff`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/sqlite-schema-diff`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool reports added, removed, and changed tables, columns, indexes, and triggers.
- [ ] Diff output is stable and copyable.
- [ ] Tests create fixture databases locally.

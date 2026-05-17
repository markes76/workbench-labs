This is the long-lived integration PR for `sqlite-browser`.

## Summary
Browse SQLite schema, preview tables, run queries, explain plans, and export CSV/JSON.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/sqlite-browser`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/sqlite-browser`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool opens local SQLite database files read-only by default.
- [ ] Schema, tables, columns, indexes, and preview rows are visible.
- [ ] Query results can be copied or exported.

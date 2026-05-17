This is the long-lived integration PR for `connection-string-parser`.

## Summary
Safely parse and redact PostgreSQL, MySQL, SQLite, and common service URLs.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/connection-string-parser`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/connection-string-parser`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Output separates protocol, user, password redaction, host, port, database, and parameters.
- [ ] Redacted output is the default.
- [ ] Invalid URLs produce actionable diagnostics.

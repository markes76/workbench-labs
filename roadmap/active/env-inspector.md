This is the long-lived integration PR for `env-inspector`.

## Summary
Parse, compare, redact, and report missing keys across .env-style files.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/env-inspector`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/env-inspector`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool parses .env content without leaking values in reports by default.
- [ ] Comparator reports added, removed, changed, and missing keys.
- [ ] Secret-looking values are redacted.

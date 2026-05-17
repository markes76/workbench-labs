This is the long-lived integration PR for `external-process-runner`.

## Summary
Extract a shared runner for ffmpeg, git, sqlite3, openssl, curl, and future local binaries.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/external-process-runner`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/external-process-runner`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Runner captures stdout, stderr, exit code, timeout, and executable lookup failures.
- [ ] VideoConverter uses the shared runner without behavior regressions.
- [ ] Tests cover success, failure, missing executable, and timeout cases.

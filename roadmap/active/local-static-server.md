This is the long-lived integration PR for `local-static-server`.

## Summary
Serve a local folder for quick previews with safe defaults.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/local-static-server`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/local-static-server`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool starts and stops a local server for a selected folder.
- [ ] Server binds to localhost by default.
- [ ] UI displays the local URL and server logs.

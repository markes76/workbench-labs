This is the long-lived integration PR for `curl-import-export`.

## Summary
Import cURL commands into structured requests and export structured requests back to cURL.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/curl-import-export`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/curl-import-export`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Common cURL flags are parsed into method, headers, URL, and body.
- [ ] Generated cURL output quotes values safely.
- [ ] Parser avoids executing user-provided shell content.

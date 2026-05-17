This is the long-lived integration PR for `http-request-builder`.

## Summary
Build local URLSession-based HTTP requests with headers, body, timing, and safe auth display.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/http-request-builder`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/http-request-builder`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool supports method, URL, headers, and body input.
- [ ] Response includes status, timing, headers, and body preview.
- [ ] Sensitive headers are redacted in saved output by default.

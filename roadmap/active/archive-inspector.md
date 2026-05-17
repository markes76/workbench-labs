This is the long-lived integration PR for `archive-inspector`.

## Summary
Inspect zip and tar archives locally without extracting everything by default.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/archive-inspector`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/archive-inspector`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool lists archive entries, sizes, modified dates, and compression info.
- [ ] Extraction is explicit and output defaults beside the source archive.
- [ ] Path traversal entries are detected and blocked.

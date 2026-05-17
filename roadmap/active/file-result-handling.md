This is the long-lived integration PR for `file-result-handling`.

## Summary
Improve generated-file UX with explicit file URLs, Finder reveal actions, and shared save/open panels.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/file-result-handling`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/file-result-handling`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] PDF, image, and video tools expose generated file URLs consistently.
- [ ] Views use shared reveal/copy/save controls where possible.
- [ ] Collision-safe output behavior is preserved.

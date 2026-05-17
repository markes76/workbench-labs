This is the long-lived integration PR for `lockfile-inspector`.

## Summary
Inspect package-lock, Package.resolved, Podfile.lock, and similar dependency lockfiles.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/lockfile-inspector`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/lockfile-inspector`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool summarizes dependencies, versions, sources, and duplicate packages.
- [ ] Known lockfile formats are detected automatically.
- [ ] Output is copyable as JSON or text.

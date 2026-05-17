This is the long-lived integration PR for `tool-categories`.

## Summary
Add Security, Databases, API & Network, and Developer categories so future tools are grouped cleanly.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/tool-categories`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/tool-categories`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] ToolCategory includes the new categories without breaking existing tools.
- [ ] Sidebar grouping remains stable and searchable.
- [ ] Registry tests verify all tools are categorized exactly once.

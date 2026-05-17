This is the long-lived integration PR for `cron-expression-explainer`.

## Summary
Explain cron expressions and show upcoming run times.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/cron-expression-explainer`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/cron-expression-explainer`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool validates common 5-field cron syntax.
- [ ] Output explains schedule in plain language.
- [ ] Output lists upcoming run times in local timezone.

This is the long-lived integration PR for `json-schema-validator`.

## Summary
Validate JSON input against JSON Schema using a bundled offline validator.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/json-schema-validator`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/json-schema-validator`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] User can enter JSON and schema side-by-side.
- [ ] Output lists validation errors with paths.
- [ ] Runtime works offline after npm dependencies are vendored.

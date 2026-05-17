This is the long-lived integration PR for `openapi-explorer`.

## Summary
Explore local OpenAPI JSON/YAML files and generate request templates.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/openapi-explorer`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/openapi-explorer`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool parses local OpenAPI 3 JSON and YAML documents.
- [ ] Endpoints are searchable by path, method, tag, and summary.
- [ ] Selected endpoint can populate HTTP Request Builder input.

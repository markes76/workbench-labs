This is the long-lived integration PR for `plist-converter`.

## Summary
Convert property lists to and from JSON/YAML using local serializers.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/plist-converter`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/plist-converter`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool reads XML and binary plist files.
- [ ] Tool converts plist to JSON and JSON to plist.
- [ ] Errors identify unsupported value types.

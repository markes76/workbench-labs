This is the long-lived integration PR for `file-hash-hmac`.

## Summary
Add streaming file hashes, HMAC, and checksum manifest verification.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/file-hash-hmac`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/file-hash-hmac`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Hash tool supports text and file path input.
- [ ] Large files are hashed without loading the entire file into memory.
- [ ] Manifest verification reports pass/fail per file.

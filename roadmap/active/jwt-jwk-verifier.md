This is the long-lived integration PR for `jwt-jwk-verifier`.

## Summary
Extend JWT verification to RS256/ES256 with JWK import and claims linting.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/jwt-jwk-verifier`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/jwt-jwk-verifier`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] JWT debugger supports HS256/384/512 and RS256/ES256 verification paths.
- [ ] JWK input supports key selection by kid.
- [ ] Claims linting flags expiry, not-before, issuer, audience, and algorithm concerns.

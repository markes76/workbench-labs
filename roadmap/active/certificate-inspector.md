This is the long-lived integration PR for `certificate-inspector`.

## Summary
Inspect PEM/DER certificates, expiry, SANs, issuer, subject, and fingerprints.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/certificate-inspector`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/certificate-inspector`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Tool accepts PEM text and certificate file paths.
- [ ] Output includes validity, SANs, issuer, subject, and SHA fingerprints.
- [ ] Expired and near-expiry certificates surface diagnostics.

This is the long-lived integration PR for `pdf-metadata-scrubber`.

## Summary
Remove title, author, subject, producer, and other metadata from PDFs.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/pdf-metadata-scrubber`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/pdf-metadata-scrubber`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Inspect mode shows metadata fields before scrubbing.
- [ ] Scrub mode writes a new PDF without selected metadata fields.
- [ ] Tests verify metadata removal and page preservation.

This is the long-lived integration PR for `image-metadata-inspector`.

## Summary
Inspect and optionally scrub EXIF, GPS, color profile, and common image metadata.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/image-metadata-inspector`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/image-metadata-inspector`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] Image Converter inspect output includes common metadata sections.
- [ ] Scrub mode writes a metadata-reduced copy where supported.
- [ ] Tests cover metadata-free and metadata-present images.

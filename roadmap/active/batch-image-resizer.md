This is the long-lived integration PR for `batch-image-resizer`.

## Summary
Resize, compress, strip metadata, and batch-convert images locally.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/batch-image-resizer`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/batch-image-resizer`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [x] Users can process multiple image paths.
- [x] Resize by width, height, max dimension, or scale.
- [x] Output defaults beside each source image and avoids overwrites.

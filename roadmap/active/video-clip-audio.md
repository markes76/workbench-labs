This is the long-lived integration PR for `video-clip-audio`.

## Summary
Trim video by start/end time, extract MP3/WAV/AAC, and generate thumbnails with ffmpeg.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/video-clip-audio`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/video-clip-audio`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [x] Video Converter supports trim start/end controls.
- [x] Audio extraction supports MP3, WAV, and AAC.
- [x] Generated outputs default to the source video folder.

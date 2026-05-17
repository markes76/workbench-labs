This is the long-lived integration PR for `pdf-ocr`.

## Summary
Use Vision and PDFKit page rendering to extract text from scanned PDFs locally.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/pdf-ocr`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/pdf-ocr`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [ ] OCR runs locally without network calls.
- [ ] User can choose page ranges.
- [ ] Output includes recognized text and confidence/diagnostic notes where available.

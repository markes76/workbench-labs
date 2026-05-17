This is the long-lived integration PR for `pdf-page-editor`.

## Summary
Add local PDF page editing: rotate, reorder, delete, extract ranges, and append pages with PDFKit.

## How Work Lands Here
1. Start Copilot/cloud-agent work with base branch `feature/pdf-page-editor`.
2. Review each agent implementation PR.
3. Merge accepted implementation PRs into `feature/pdf-page-editor`.
4. When this integration PR is complete, approve and promote it into `main`.

## Acceptance Criteria
- [x] User can choose PDF pages and apply rotate, reorder, delete, extract, and append operations.
- [x] Operations produce real PDF files beside the source file by default.
- [x] Tests validate page counts and operation results with generated fixture PDFs.

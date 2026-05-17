# Workbench Labs Feature Expansion Roadmap

## Current Baseline

Workbench Labs is a SwiftPM macOS 14 SwiftUI app with 32 registered tools across ten categories. The registry lives in `ToolModels` and `ToolRegistry`, execution routes through `ToolRunner`, Swift-native tools live under `Services`, and JS-backed formatters run through the bundled Node runtime.

Primary extension points:
- Tool IDs/categories: `Sources/WorkbenchLabsCore/Models/ToolModels.swift`
- Registry metadata/options: `Sources/WorkbenchLabsCore/Models/ToolRegistry.swift`
- Execution dispatch: `Sources/WorkbenchLabsCore/Engines/ToolRunner.swift`
- Swift services: `Sources/WorkbenchLabsCore/Services`
- JS runtime: `runtime-src/tool-runtime.js`
- Custom tool views: `Sources/WorkbenchLabs/Views/ContentView.swift`
- Tests: `Tests/WorkbenchLabsCoreTests`

## P0: Expansion Foundation

1. Add dedicated categories: Security, Databases, API & Network, Developer.
2. Extract a reusable `ExternalProcessRunner` for `ffmpeg`, `git`, `sqlite3`, `openssl`, `curl`, and other local binaries.
3. Improve file-result handling with explicit output file URLs, Finder reveal actions, and shared save/open panels.

## Recently Shipped

- PDF Page Editor: rotate, reorder, delete, extract ranges, and append pages with PDFKit.
- PDF OCR Text Extractor: OCR scanned PDFs locally with Apple Vision/Tesseract, English/Hebrew language selection, and page-range selection.
- PDF Metadata Scrubber: inspect metadata and write rebuilt PDFs with selected metadata fields blanked.
- Batch Image Resizer/Compressor: resize, compress, strip metadata, and batch-convert images locally.
- Image Metadata Inspector: inspect EXIF/GPS/color metadata and write GPS-scrubbed safe-sharing copies.
- Video Clip & Audio Extract: trim video by start/end, extract MP3/WAV/AAC, and generate thumbnails.

## P1: High-Value Tools

### Developer Utilities

1. JSON Schema Validator with bundled AJV.
2. `.env` Inspector & Comparator with redaction and missing-key detection.
3. Git Diff/Ignore Helper using local `git`.

### Security

1. Certificate Inspector for PEM/DER certs, expiry, SANs, issuer, and fingerprints.
2. JWT/JWK Verifier upgrade for RS256/ES256, JWK import, and claims linting.
3. File Hash/HMAC Tool with streaming file hashes and checksum manifest verification.

### Databases

1. SQLite Browser & Query Runner with schema list, table preview, query, EXPLAIN, CSV/JSON export.
2. Connection String Parser for safe parsing/redaction of PostgreSQL/MySQL/SQLite URLs.
3. SQLite Schema Diff across two database files.

### API & Network

1. HTTP Request Builder using `URLSession`, with headers/body/timing and safe auth display.
2. cURL Import/Export.
3. OpenAPI Explorer for local OpenAPI JSON/YAML files.

## P2: Useful Follow-Ups

- Plist/JSON/YAML converter using `PropertyListSerialization`.
- Archive inspector for zip/tar.
- Cron expression explainer.
- Local static file server for previewing folders.
- Dependency lockfile inspector for `package-lock`, `Package.resolved`, and `Podfile.lock`.

## Per-Tool Implementation Checklist

1. Add `ToolID` and category if needed.
2. Add `ToolDefinition`, sample input, options, and capabilities.
3. Route in `ToolRunner`.
4. Implement Swift service or JS runtime case.
5. Add `ClipboardInspector` detection when useful.
6. Add a custom SwiftUI view for multi-file or highly structured workflows.
7. Add focused `WorkbenchLabsCore` tests and update registry count tests.
8. Update README, feature guide, and CHANGELOG for user-facing changes.
